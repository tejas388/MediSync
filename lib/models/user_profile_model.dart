// lib/models/user_profile_model.dart
// MediSync - User profile model

class UserProfileModel {
  final String  id;
  final String  firebaseUid;
  final String  name;
  final String  email;
  final String  role;           // patient | caregiver
  final String? photoUrl;
  final String? phoneNumber;
  final String? deviceId;       // linked ESP32 device ID
  final String? fcmToken;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool    notificationsEnabled;
  final bool    soundEnabled;
  final bool    vibrationEnabled;
  final bool    biometricEnabled;
  final String  themeMode;      // 'light' | 'dark' | 'system'
  final DateTime createdAt;
  /// Public shareable Patient ID (format: MED-XXXXXX).
  /// Only set for users with role == 'patient'. Null for caregivers.
  final String? patientCode;

  const UserProfileModel({
    required this.id,
    required this.firebaseUid,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.phoneNumber,
    this.deviceId,
    this.fcmToken,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.notificationsEnabled = true,
    this.soundEnabled         = true,
    this.vibrationEnabled     = true,
    this.biometricEnabled     = false,
    this.themeMode            = 'system',
    required this.createdAt,
    this.patientCode,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> j) => UserProfileModel(
    id:                    j['_id']                  as String? ?? j['id'] as String? ?? '',
    firebaseUid:           j['firebaseUid']           as String? ?? '',
    name:                  j['name']                  as String? ?? '',
    email:                 j['email']                 as String? ?? '',
    role:                  j['role']                  as String? ?? 'caregiver',
    photoUrl:              j['photoUrl']              as String?,
    phoneNumber:           j['phoneNumber']           as String?,
    deviceId:              j['deviceId']              as String?,
    fcmToken:              j['fcmToken']              as String?,
    emergencyContactName:  j['emergencyContactName']  as String?,
    emergencyContactPhone: j['emergencyContactPhone'] as String?,
    notificationsEnabled:  j['notificationsEnabled']  as bool? ?? true,
    soundEnabled:          j['soundEnabled']          as bool? ?? true,
    vibrationEnabled:      j['vibrationEnabled']      as bool? ?? true,
    biometricEnabled:      j['biometricEnabled']      as bool? ?? false,
    themeMode:             j['themeMode']             as String? ?? 'system',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    patientCode:           j['patientCode']           as String?,
  );

  bool get isPatient   => role == 'patient';
  bool get isCaregiver => role == 'caregiver';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  UserProfileModel copyWith({
    String? name, String? phoneNumber, String? emergencyContactName,
    String? emergencyContactPhone, bool? notificationsEnabled,
    bool? soundEnabled, bool? vibrationEnabled, bool? biometricEnabled,
    String? themeMode,
  }) => UserProfileModel(
    id: id, firebaseUid: firebaseUid,
    name: name ?? this.name, email: email, role: role,
    photoUrl: photoUrl,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    deviceId: deviceId, fcmToken: fcmToken,
    emergencyContactName:  emergencyContactName  ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    notificationsEnabled:  notificationsEnabled  ?? this.notificationsEnabled,
    soundEnabled:          soundEnabled          ?? this.soundEnabled,
    vibrationEnabled:      vibrationEnabled      ?? this.vibrationEnabled,
    biometricEnabled:      biometricEnabled      ?? this.biometricEnabled,
    themeMode:             themeMode             ?? this.themeMode,
    createdAt: createdAt,
    patientCode: patientCode,
  );
}
