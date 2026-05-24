import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:classguard/screens/auth/auth_screen.dart';
import 'package:classguard/theme/app_theme.dart';
import 'package:classguard/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/permission_handler.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  final bool isFromSettings;
  const PermissionOnboardingScreen({super.key, this.isFromSettings = false});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> with WidgetsBindingObserver {
  bool isDndGranted = false;
  bool isAccessibilityGranted = false;
  bool isOverlayGranted = false;
  bool isBatteryGranted = false;
  bool isUsageGranted = false;
  bool isAutoStartConfigured = false;

  final platform = const MethodChannel('com.classguard/applock');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }
// Recheck all critical Android permissions whenever onboarding screen resumes.
  Future<void> _checkAllPermissions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool autoStartMemory = prefs.getBool('isAutoStartConfigured') ?? false;

    bool? dndStatus = await PermissionHandler.permissionsGranted;
    bool accStatus = false;
    bool ovrStatus = false;
    bool batStatus = false;
    bool usageStatus = false;

    try {
      accStatus = await platform.invokeMethod('checkAccessibilityPermission') ?? false;
      ovrStatus = await platform.invokeMethod('checkOverlayPermission') ?? false;
      batStatus = await platform.invokeMethod('checkBatteryOptimization') ?? false;
      usageStatus = await platform.invokeMethod('checkUsagePermission') ?? false;
    } catch (e) {}

    setState(() {
      isAutoStartConfigured = autoStartMemory;
      isDndGranted = dndStatus ?? false;
      isAccessibilityGranted = accStatus;
      isOverlayGranted = ovrStatus;
      isBatteryGranted = batStatus;
      isUsageGranted = usageStatus;
    });
  }

  void _requestDND() async => await PermissionHandler.openDoNotDisturbSetting();
  void _requestUsage() async => await platform.invokeMethod('requestUsagePermission');
  void _requestAccessibility() async => await platform.invokeMethod('openAccessibilitySettings');
  void _requestOverlay() async => await platform.invokeMethod('requestOverlayPermission');
  void _requestBattery() async => await platform.invokeMethod('requestBatteryOptimization');

  void _requestAutoStart() async {
    try {
      await getAutoStartPermission();
    } catch (e) {
      await platform.invokeMethod('requestAutoStartPermission');
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAutoStartConfigured', true);
    setState(() {
      isAutoStartConfigured = true;
    });
    Fluttertoast.showToast(msg: "Auto Start configured.");
  }
// Block app access until all required, protection permissions are granted.
  void _proceedToAuth(BuildContext context) async {
    if (!isDndGranted ||
        !isAccessibilityGranted ||
        !isOverlayGranted ||
        !isBatteryGranted ||
        !isUsageGranted ||
        !isAutoStartConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all required permissions first.')),
      );
      return;
    }
    if (widget.isFromSettings) {
      if (context.mounted) Navigator.pop(context);
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTimeSetupDone', true);
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool allGranted =
        isDndGranted &&
            isAccessibilityGranted &&
            isOverlayGranted &&
            isBatteryGranted &&
            isUsageGranted &&
            isAutoStartConfigured;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: widget.isFromSettings
          ? AppBar(
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textDark,
        title: const Text(
          'System Permissions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isFromSettings) ...[
                const SizedBox(height: 24),
                const Icon(Icons.settings_suggest, size: 64, color: AppTheme.primaryColor),
                const SizedBox(height: 32),
                const Text(
                  'Setup Permissions',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 16),
                const Text(
                  'To make ClassGuard work seamlessly, we need access to a few core system settings.',
                  style: TextStyle(fontSize: 16, color: AppTheme.textLight, height: 1.5),
                ),
                const SizedBox(height: 48),
              ],

              _buildPermissionItem(
                icon: Icons.do_not_disturb_on,
                title: 'Do Not Disturb',
                description: 'Automatically mute your phone during classes.',
                isGranted: isDndGranted,
                onRequest: _requestDND,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.data_usage,
                title: 'Usage Access',
                description: 'Required to sort and find your most used apps.',
                isGranted: isUsageGranted,
                onRequest: _requestUsage,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.accessibility_new,
                title: 'Accessibility',
                description: 'Detect & block distracting apps while active.',
                isGranted: isAccessibilityGranted,
                onRequest: _requestAccessibility,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.layers,
                title: 'Display Over Apps',
                description: 'Show the Lock Screen when an app is blocked.',
                isGranted: isOverlayGranted,
                onRequest: _requestOverlay,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.battery_charging_full,
                title: 'Battery Optimization',
                description: 'Prevent system kill.',
                isGranted: isBatteryGranted,
                onRequest: _requestBattery,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                icon: Icons.rocket_launch,
                title: 'Auto Start',
                description: 'Required to keep the protection active.',
                isGranted: isAutoStartConfigured,
                onRequest: _requestAutoStart,
              ),

              const SizedBox(height: 48),
              PrimaryButton(
                text: widget.isFromSettings ? 'Done' : (allGranted ? 'Continue' : 'Permissions Required'),
                onPressed: allGranted ? () => _proceedToAuth(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isGranted ? Colors.green.shade200 : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isGranted ? Colors.green : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Icon(Icons.check_circle, color: Colors.green, size: 28)
          else
            ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Configure', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}