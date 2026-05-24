import 'dart:convert';
import 'package:classguard/routes/app_routes.dart';
import 'package:classguard/screens/auth/auth_screen.dart';
import 'package:classguard/screens/onboarding/permission_onboarding_screen.dart';
import 'package:classguard/services/auth_service.dart';
import 'package:classguard/theme/app_theme.dart';
import 'package:classguard/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            Icons.person_outline,
            'Edit Profile',
            'Name, Student ID, Email, Photo',
            onTap: () => Navigator.push(context, createRoute(const EditProfileScreen())),
          ),
          const SizedBox(height: 32),
          const Text(
            'System',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            Icons.security_outlined,
            'System Permissions',
            'Accessibility, DND, Overlay',
            onTap: () => Navigator.push(
              context,
              createRoute(const PermissionOnboardingScreen(isFromSettings: true)),
            ),
          ),
          _buildSettingItem(
            Icons.help_outline,
            'How to Use ClassGuard',
            'Learn how to setup focus schedules',
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppTheme.backgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'How to Use ClassGuard',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const ExpansionTile(
                        title: Text('Personal Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              '1. Go to Home and tap the + button.\n2. Select "Add Schedule".\n3. Set your day, time, and choose apps to block.\n4. Save, and your phone will auto-lock those apps on schedule.',
                              style: TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                      const ExpansionTile(
                        title: Text('Classroom', style: TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'As a Teacher:\nTap + and select "Create Classroom". Share the generated code with your students.\n\nAs a Student:\nTap + and select "Join Classroom". Enter the code to sync your device with the teacher\'s rules.',
                              style: TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildSettingItem(
            Icons.info_outline,
            'About ClassGuard',
            'Version 1.0.0',
          ),
          const SizedBox(height: 8),
          ListTile(
            onTap: () async {
              final authService = AuthService();
              final canLogout = await authService.canLogout();
// Prevent logout while active, focus protection is running.
              if (!canLogout) {
                Fluttertoast.showToast(msg: "Cannot logout while a session is actively running.", backgroundColor: Colors.red);
                return;
              }

              await authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                );
              }
            },
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout, color: Colors.redAccent),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.iconBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.textDark),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final emailController = TextEditingController();
  final AuthService _authService = AuthService();
  String? base64Image;
  bool isLoading = false; 

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final profile = await _authService.loadProfileData();
    setState(() {
      nameController.text = profile.name;
      idController.text = profile.studentId;
      emailController.text = profile.email;
      base64Image = profile.profileImage;
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedImage = await _authService.pickAndSaveProfileImage();
      if (pickedImage != null) {
        setState(() {
          base64Image = pickedImage;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick image. Make sure permission is granted.");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: base64Image != null
                            ? DecorationImage(
                          image: MemoryImage(base64Decode(base64Image!)),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: base64Image == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: AppTheme.baseInputDecoration("Enter your full name"),
            ),
            const SizedBox(height: 24),

            const Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: idController,
              keyboardType: TextInputType.text,
              decoration: AppTheme.baseInputDecoration("Enter your student ID"),
            ),
            const SizedBox(height: 24),

            const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.baseInputDecoration("Enter your email address"),
            ),
            const SizedBox(height: 48),

            PrimaryButton(
              text: 'Save Changes',
              isLoading: isLoading,
              onPressed: () async {
                setState(() => isLoading = true);
                await _authService.saveProfile(
                  name: nameController.text,
                  email: emailController.text,
                  profileImage: base64Image,
                );
                if (context.mounted) {
                  FocusScope.of(context).unfocus();
                  Fluttertoast.showToast(msg: "Profile updated and synced!");
                  setState(() => isLoading = false);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}