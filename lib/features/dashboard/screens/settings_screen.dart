import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:classguard/core/routes/app_routes.dart';
import 'package:classguard/core/theme/app_theme.dart';
import 'package:classguard/features/auth/screens/auth_screen.dart';
import 'package:classguard/features/auth/services/auth_service.dart';
import 'package:classguard/features/onboarding/screens/permission_onboarding_screen.dart';

// ADDED: Import background service to normalize device upon logout
import 'package:classguard/core/background/classguard_background.dart';

import 'package:classguard/shared/widgets/primary_button.dart';
import 'package:classguard/shared/widgets/setting_card.dart';
import 'package:classguard/shared/widgets/section_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _buildHowToCard(String title, String content) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(content, style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionHeader(
              title: 'Account',
              padding: EdgeInsets.only(bottom: 12)
          ),

          SettingCard(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Name, Student ID, Email, Photo',
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
            onTap: () => Navigator.push(context, createRoute(const EditProfileScreen())),
          ),
          const SizedBox(height: 32),

          const SectionHeader(
              title: 'System',
              padding: EdgeInsets.only(bottom: 12)
          ),
          SettingCard(
            icon: Icons.security_outlined,
            title: 'System Permissions',
            subtitle: 'Accessibility, DND, Overlay',
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
            onTap: () => Navigator.push(context, createRoute(const PermissionOnboardingScreen(isFromSettings: true))),
          ),
          const SizedBox(height: 12),
          SettingCard(
            icon: Icons.help_outline,
            title: 'How to Use ClassGuard',
            subtitle: 'Learn how to setup focus schedules',
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.backgroundColor,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (context) {
                    int currentIndex = 0;
                    final PageController pageController = PageController(viewportFraction: 0.9);
                    return StatefulBuilder(
                      builder: (context, setModalState) => SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text('How to Use ClassGuard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 220,
                                child: PageView(
                                  controller: pageController,
                                  onPageChanged: (index) => setModalState(() => currentIndex = index),
                                  children: [
                                    _buildHowToCard('Personal Schedule', '1. Go to Home and tap the + button.\n2. Select "Add Schedule".\n3. Set your day, time, and choose apps to block.\n4. Save, and your phone will auto-lock those apps on schedule.'),
                                    _buildHowToCard('Classroom', 'As a Teacher:\nTap + and select "Create Classroom". Share the generated code with your students.\n\nAs a Student:\nTap + and select "Join Classroom". Enter the code to sync your device with the teacher\'s rules.'),
                                    _buildHowToCard('Exam Mode', 'As a Host:\nCreate a highly secure exam session. Monitor student presence and submissions in real-time.\n\nAs a Student:\nJoining this mode will strictly lock your device into the exam view until submission.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: currentIndex == index ? 24 : 8, height: 8, decoration: BoxDecoration(color: currentIndex == index ? Colors.black : Colors.black26, borderRadius: BorderRadius.circular(4)))),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
              );
            },
          ),
          const SizedBox(height: 12),
          SettingCard(
            icon: Icons.info_outline,
            title: 'About ClassGuard',
            subtitle: 'Version 1.0.0',
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
          ),
          const SizedBox(height: 24),

          ListTile(
            onTap: () async {
              final authService = AuthService();
              final canLogout = await authService.canLogout();

              if (!canLogout) {
                Fluttertoast.showToast(msg: "Cannot logout while a session is actively running.", backgroundColor: Colors.red);
                return;
              }

              // ADDED: Force terminate background protection and restore device volume
              // This ensures the device returns to normal state if logged out during a Personal Schedule.
              stopClassGuard();

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
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
        setState(() => base64Image = pickedImage);
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
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                        image: base64Image != null
                            ? DecorationImage(image: MemoryImage(base64Decode(base64Image!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: base64Image == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: nameController, decoration: AppTheme.baseInputDecoration("Enter your full name")),
            const SizedBox(height: 24),
            const Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: idController, keyboardType: TextInputType.text, decoration: AppTheme.baseInputDecoration("Enter your student ID")),
            const SizedBox(height: 24),
            const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: AppTheme.baseInputDecoration("Enter your email address")),
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

