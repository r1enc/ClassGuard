import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classguard/utils/time_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  const AuthResult({
    required this.name,
    required this.email,
    required this.studentId,
  });

  final String name;
  final String email;
  final String studentId;
}

class ProfileData {
  const ProfileData({
    required this.name,
    required this.studentId,
    required this.email,
    this.profileImage,
  });

  final String name;
  final String studentId;
  final String email;
  final String? profileImage;
}

class SplashUserState {
  const SplashUserState({
    required this.isSetupDone,
    required this.isLoggedIn,
    required this.userName,
  });

  final bool isSetupDone;
  final bool isLoggedIn;
  final String userName;
}

class AuthService {
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String finalName = "Student";
    String finalEmail = email.trim();
    String finalId = "";

    UserCredential user = await FirebaseAuth.instance
        .signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.user!.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      finalName = data['name'] ?? user.user?.displayName ?? "Student";
      finalEmail = data['email'] ?? finalEmail;
      finalId =
          data['studentId'] ??
          (Random().nextInt(900000000) + 100000000).toString();
      String? cloudImage = data['profileImage'];
      if (cloudImage != null) {
        await prefs.setString('profileImage', cloudImage);
      }
    } else {
      finalName = user.user?.displayName ?? "Student";
      finalId = (Random().nextInt(900000000) + 100000000).toString();
    }

    await saveLoggedInUser(
      name: finalName,
      email: finalEmail,
      studentId: finalId,
      uid: FirebaseAuth.instance.currentUser!.uid,
    );

    return AuthResult(name: finalName, email: finalEmail, studentId: finalId);
  }

  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    String finalName = name.trim();
    String finalEmail = email.trim();
    String finalId = (Random().nextInt(900000000) + 100000000).toString();

    UserCredential user = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

    await user.user?.updateDisplayName(finalName);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.user!.uid)
        .set({
          'name': finalName,
          'email': finalEmail,
          'studentId': finalId,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await saveLoggedInUser(
      name: finalName,
      email: finalEmail,
      studentId: finalId,
      uid: FirebaseAuth.instance.currentUser!.uid,
    );

    return AuthResult(name: finalName, email: finalEmail, studentId: finalId);
  }
// Cache authenticated user data locally for fast session restoration.
  Future<void> saveLoggedInUser({
    required String name,
    required String email,
    required String studentId,
    required String uid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileName', name);
    await prefs.setString('profileEmail', email);
    await prefs.setString('profileId', studentId);
    await prefs.setString('userUid', uid);
    await prefs.setBool('isLoggedIn', true);
  }

  Future<String> loadProfileName({required String fallbackName}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profileName') ?? fallbackName;
  }

  Future<ProfileData> loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileData(
      name: prefs.getString('profileName') ?? 'Student',
      studentId: prefs.getString('profileId') ?? '',
      email: prefs.getString('profileEmail') ?? '',
      profileImage: prefs.getString('profileImage'),
    );
  }

  Future<String?> pickAndSaveProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    final bytes = await File(pickedFile.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImage', base64Image);
    return base64Image;
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    required String? profileImage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    await prefs.setString('profileName', name);
    await prefs.setString('profileEmail', email);
    if (profileImage != null) {
      await prefs.setString('profileImage', profileImage);
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': name,
      'email': email,
      'profileImage': profileImage,
    });
  }
// Prevent logout while focus session or app lock is currently active.
  Future<bool> canLogout() async {
    final prefs = await SharedPreferences.getInstance();
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    final now = DateTime.now();
    final dayStr = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun",
    ][now.weekday - 1];
    int currentMins = now.hour * 60 + now.minute;

    final snapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .where('joinedStudents', arrayContains: uid)
        .where('isActive', isEqualTo: true)
        .get();

    bool isClassRunning = false;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['day'] == dayStr) {
        int start = timeToMinutes(data['startTime'] ?? "00:00");
        int end = timeToMinutes(data['endTime'] ?? "00:00");

        if (currentMins >= start && currentMins < end) {
          if (data['role'] == 'Teacher' && data['userId'] == uid) {
            continue;
          }

          isClassRunning = true;
          break;
        }
      }
    }

    bool isLockedLocal = prefs.getBool('isAppLockActive') ?? false;
    return !isClassRunning && !isLockedLocal;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
  }
// Restore onboarding and login state during app startup.
  Future<SplashUserState> loadSplashUserState() async {
    final prefs = await SharedPreferences.getInstance();
    bool isSetupDone = prefs.getBool('isFirstTimeSetupDone') ?? false;

    User? currentUser = FirebaseAuth.instance.currentUser;
    bool isLoggedIn = currentUser != null;

    String userName = prefs.getString('profileName') ?? "Student";
    if (isLoggedIn &&
        currentUser.displayName != null &&
        currentUser.displayName!.isNotEmpty) {
      userName = currentUser.displayName!;
    }

    return SplashUserState(
      isSetupDone: isSetupDone,
      isLoggedIn: isLoggedIn,
      userName: userName,
    );
  }
}
