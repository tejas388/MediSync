import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medisync/features/auth/auth_provider.dart';
import 'package:medisync/core/constants/app_colors.dart';
import 'package:medisync/main.dart';
import 'package:medisync/features/auth/screens/login_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileSheet(BuildContext context, dynamic userProfile) {
    final nameCtrl = TextEditingController(text: userProfile.name);
    final phoneCtrl = TextEditingController(text: userProfile.phoneNumber);
    final emergencyNameCtrl = TextEditingController(text: userProfile.emergencyContactName);
    final emergencyPhoneCtrl = TextEditingController(text: userProfile.emergencyContactPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emergencyNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emergencyPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await context.read<AuthProvider>().updateProfile({
                      'name': nameCtrl.text,
                      'phoneNumber': phoneCtrl.text,
                      'emergencyContactName': emergencyNameCtrl.text,
                      'emergencyContactPhone': emergencyPhoneCtrl.text,
                    });
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, String currentTheme) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Appearance'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: RadioGroup<String>(
            groupValue: currentTheme,
            onChanged: (val) {
              if (val == null) return;
              final mode = val == 'light'
                  ? ThemeMode.light
                  : val == 'dark'
                      ? ThemeMode.dark
                      : ThemeMode.system;
              MediSyncApp.of(context).setThemeMode(mode);
              context.read<AuthProvider>().updateProfile({'themeMode': val});
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in [
                  ('system', 'System'),
                  ('light', 'Light'),
                  ('dark', 'Dark'),
                ])
                  ListTile(
                    title: Text(entry.$2),
                    leading: Radio<String>(
                      value: entry.$1,
                    ),
                    onTap: null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<AuthProvider>().deleteAccount();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Loading state ──────────────────────────────────────────────────────────
    if (user == null) {
      final isLoading = authProvider.isLoadingProfile;
      final error     = authProvider.syncError;

      if (isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      // Profile failed to load — show error with retry
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 72, color: AppColors.error),
                const SizedBox(height: 20),
                Text(
                  'Profile unavailable',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  error ?? 'Unable to load your profile. Please try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => authProvider.refreshProfile(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.initials,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          user.role,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => _showEditProfileSheet(context, user),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Offline / sync-error banner ─────────────────────────────
                  if (authProvider.syncError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2D1F1F)
                            : const Color(0xFFFFF3F3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authProvider.syncError!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => authProvider.refreshProfile(),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.refresh,
                                  color: AppColors.error, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildSectionTitle('Account'),
                    _buildCard(
                    isDark,
                    children: [
                      // ── Caregiver info ────────────────────────────────────
                      const ListTile(
                        leading: Icon(Icons.medical_services_rounded, color: AppColors.primary),
                        title: Text('Role'),
                        subtitle: Text('Caregiver',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.devices, color: AppColors.primary),
                        title: const Text('My Linked Device'),
                        subtitle: Text(user.deviceId ?? 'Not linked'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.emergency, color: AppColors.error),
                        title: const Text('Emergency Contact'),
                        subtitle: Text(user.emergencyContactName != null && user.emergencyContactName!.isNotEmpty
                            ? '${user.emergencyContactName} - ${user.emergencyContactPhone}'
                            : 'Not set'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Notifications'),
                  _buildCard(
                    isDark,
                    children: [
                      SwitchListTile(
                        activeThumbColor: AppColors.primary,
                        secondary: const Icon(Icons.notifications, color: AppColors.primary),
                        title: const Text('Push Notifications'),
                        value: user.notificationsEnabled,
                        onChanged: (val) => authProvider.updateProfile({'notificationsEnabled': val}),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeThumbColor: AppColors.primary,
                        secondary: const Icon(Icons.volume_up, color: AppColors.primary),
                        title: const Text('Sound'),
                        value: user.soundEnabled,
                        onChanged: (val) => authProvider.updateProfile({'soundEnabled': val}),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeThumbColor: AppColors.primary,
                        secondary: const Icon(Icons.vibration, color: AppColors.primary),
                        title: const Text('Vibration'),
                        value: user.vibrationEnabled,
                        onChanged: (val) => authProvider.updateProfile({'vibrationEnabled': val}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Appearance & Security'),
                  _buildCard(
                    isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dark_mode, color: AppColors.primary),
                        title: const Text('Theme'),
                        subtitle: Text(user.themeMode.substring(0, 1).toUpperCase() + user.themeMode.substring(1)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeDialog(context, user.themeMode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Danger Zone'),
                  _buildCard(
                    isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.error),
                        title: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                        onTap: () async {
                          await authProvider.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: AppColors.error),
                        title: const Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondaryLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.transparent : AppColors.borderLight),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}
