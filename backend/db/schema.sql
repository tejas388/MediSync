-- backend/db/schema.sql
-- MediSync - PostgreSQL schema (Caregiver-Only App)
-- Run once: psql -U postgres -d medisync -f backend/db/schema.sql

-- ─── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── USERS ────────────────────────────────────────────────────────────────────
-- Every account that logs into the app is a caregiver.
-- firebase_uid is required for caregivers (Firebase Auth); NULL for patient rows.
CREATE TABLE IF NOT EXISTS users (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Caregivers: firebase_uid is set on registration.
  -- Patients: created directly by caregivers — firebase_uid is NULL (no app login).
  firebase_uid              TEXT UNIQUE,

  name                      TEXT NOT NULL,
  email                     TEXT NOT NULL,

  -- role: 'caregiver' for app users, 'patient' for caregiver-managed records.
  -- Default is 'caregiver' since all app registrations are caregivers.
  role                      TEXT NOT NULL DEFAULT 'caregiver' CHECK (role IN ('caregiver', 'patient')),

  photo_url                 TEXT,
  phone_number              TEXT,
  device_id                 TEXT,
  emergency_contact_name    TEXT,
  emergency_contact_phone   TEXT,
  fcm_token                 TEXT,
  notifications_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  biometric_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
  theme_mode                TEXT NOT NULL DEFAULT 'system' CHECK (theme_mode IN ('light', 'dark', 'system')),
  sound_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  vibration_enabled         BOOLEAN NOT NULL DEFAULT TRUE,
  is_active                 BOOLEAN NOT NULL DEFAULT TRUE,

  -- patient_code: unique shareable ID (format MED-XXXXXX).
  -- Only set for role = 'patient' rows. NULL for caregivers.
  patient_code              TEXT UNIQUE,

  -- created_by: the caregiver UUID who created this patient record.
  -- NULL for caregivers (they create themselves via Firebase Auth).
  -- NOT NULL for patient rows created via POST /caregiver/patients/create.
  created_by                UUID REFERENCES users (id) ON DELETE SET NULL,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid  ON users (firebase_uid) WHERE firebase_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_role          ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_patient_code  ON users (patient_code) WHERE patient_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_created_by    ON users (created_by) WHERE created_by IS NOT NULL;

-- ─── CAREGIVER ↔ PATIENT LINKS ────────────────────────────────────────────────
-- Tracks which caregiver manages which patient.
-- A patient can have multiple caregivers; a caregiver can manage many patients.
CREATE TABLE IF NOT EXISTS caregiver_patient_links (
  caregiver_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  patient_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (caregiver_id, patient_id)
);

CREATE INDEX IF NOT EXISTS idx_cpl_caregiver ON caregiver_patient_links (caregiver_id);
CREATE INDEX IF NOT EXISTS idx_cpl_patient   ON caregiver_patient_links (patient_id);

-- ─── MEDICINES ────────────────────────────────────────────────────────────────
-- Medicines belong to a patient (user_id = patient UUID).
-- Caregivers manage these on behalf of their patients.
CREATE TABLE IF NOT EXISTS medicines (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  dosage              TEXT NOT NULL,
  quantity            INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reminder_times      TEXT[]   NOT NULL DEFAULT '{}',
  start_date          DATE     NOT NULL,
  end_date            DATE,
  expiry_date         DATE,
  compartment_number  INTEGER  NOT NULL CHECK (compartment_number BETWEEN 1 AND 7),
  food_instruction    TEXT     NOT NULL DEFAULT 'No restriction'
                        CHECK (food_instruction IN (
                          'Before meals','After meals','With meals',
                          'Empty stomach','No restriction'
                        )),
  notes               TEXT,
  is_active           BOOLEAN  NOT NULL DEFAULT TRUE,
  color               TEXT     NOT NULL DEFAULT '#0A7EA4',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_medicines_user_id          ON medicines (user_id);
CREATE INDEX IF NOT EXISTS idx_medicines_user_active      ON medicines (user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_medicines_user_compartment ON medicines (user_id, compartment_number);

-- ─── DOSE RECORDS ─────────────────────────────────────────────────────────────
-- Each row = one scheduled dose for a patient.
-- user_id = patient UUID (doses are tracked per patient, not per caregiver).
CREATE TABLE IF NOT EXISTS dose_records (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  medicine_id           UUID NOT NULL REFERENCES medicines (id) ON DELETE CASCADE,
  medicine_name         TEXT NOT NULL,
  dosage                TEXT NOT NULL,
  scheduled_time        TIMESTAMPTZ NOT NULL,
  taken_time            TIMESTAMPTZ,
  status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','taken','missed','snoozed')),
  dispensed_by_device   BOOLEAN NOT NULL DEFAULT FALSE,
  dispenser_compartment INTEGER,
  snoozed_count         INTEGER NOT NULL DEFAULT 0,
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dose_user_id        ON dose_records (user_id);
CREATE INDEX IF NOT EXISTS idx_dose_scheduled_time ON dose_records (scheduled_time);
CREATE INDEX IF NOT EXISTS idx_dose_status         ON dose_records (status);
CREATE INDEX IF NOT EXISTS idx_dose_user_scheduled ON dose_records (user_id, scheduled_time DESC);
CREATE INDEX IF NOT EXISTS idx_dose_user_status    ON dose_records (user_id, status);
CREATE INDEX IF NOT EXISTS idx_dose_medicine_sched ON dose_records (medicine_id, scheduled_time DESC);

-- ─── DISPENSERS ───────────────────────────────────────────────────────────────
-- An ESP32 smart dispenser linked to a patient's account.
-- user_id = patient UUID (the dispenser serves one patient).
CREATE TABLE IF NOT EXISTS dispensers (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id            TEXT NOT NULL UNIQUE,
  user_id              UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  is_online            BOOLEAN NOT NULL DEFAULT FALSE,
  battery_level        INTEGER NOT NULL DEFAULT 0 CHECK (battery_level BETWEEN 0 AND 100),
  wifi_signal_strength INTEGER NOT NULL DEFAULT -100,
  firmware_version     TEXT    NOT NULL DEFAULT '1.0.0',
  total_dispenses      INTEGER NOT NULL DEFAULT 0,
  is_emergency_mode    BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen            TIMESTAMPTZ,
  -- JSONB array: [{"number":1,"stock":10,"medicine_id":"uuid-or-null"}, ...]
  compartments         JSONB   NOT NULL DEFAULT '[]',
  -- JSONB object or null: {"compartment_number":1,"triggered_at":"...","triggered_by":"...","is_acknowledged":false}
  pending_dispense     JSONB,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dispensers_device_id ON dispensers (device_id);
CREATE INDEX IF NOT EXISTS idx_dispensers_user_id   ON dispensers (user_id);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
-- Notifications sent to caregivers about their patients.
-- user_id = caregiver UUID (the one who receives the alert).
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN (
                  'doseReminder','doseMissed','lowStock','expiryAlert',
                  'caregiverAlert','deviceOffline','emergencySOS','scheduleUpdate'
                )),
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  medicine_id   UUID REFERENCES medicines (id) ON DELETE SET NULL,
  medicine_name TEXT,
  extra         JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_user_id    ON notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notif_is_read    ON notifications (user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notif_created_at ON notifications (user_id, created_at DESC);

-- ─── Auto-update updated_at via trigger ───────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['users','medicines','dose_records','dispensers','notifications']
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_updated_at ON %s;
       CREATE TRIGGER trg_%s_updated_at
         BEFORE UPDATE ON %s
         FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();',
      t, t, t, t
    );
  END LOOP;
END;
$$;
