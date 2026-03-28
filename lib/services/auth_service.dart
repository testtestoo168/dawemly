import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'device_info_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // ─── Generate a simple device fingerprint ───
  String _generateDeviceId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${currentUser?.uid ?? 'unknown'}';
  }

  // ─── Register active session with real device info ───
  Future<void> _registerSession(String uid, String userName) async {
    final deviceDetails = await DeviceInfoService.getDeviceDetails();
    final platform = deviceDetails['platform'] ?? (kIsWeb ? 'web' : 'mobile');
    final deviceModel = deviceDetails['deviceModel'] ?? 'غير معروف';
    final osVersion = deviceDetails['osVersion'] ?? '';
    final deviceBrand = deviceDetails['deviceBrand'] ?? '';

    await _db.collection('active_sessions').doc(uid).set({
      'uid': uid,
      'userName': userName,
      'platform': platform,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'deviceBrand': deviceBrand,
      'deviceId': _generateDeviceId(),
      'loginAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
    // Save last device info on user record
    await _db.collection('users').doc(uid).update({
      'lastPlatform': platform,
      'lastDeviceModel': deviceModel,
      'lastOsVersion': osVersion,
      'lastDeviceBrand': deviceBrand,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // ─── Check if single device mode blocks login ───
  Future<String?> _checkSingleDeviceBlock(String uid) async {
    // Check global setting
    final settingsDoc = await _db.collection('settings').doc('general').get();
    final singleDeviceMode = settingsDoc.data()?['singleDeviceMode'] ?? false;
    if (!singleDeviceMode) return null;

    // Check if user has multi-device exception
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.data()?['multiDeviceAllowed'] == true) return null;
    if (userDoc.data()?['role'] == 'admin') return null; // Admins bypass

    // Check if active session exists
    final sessionDoc = await _db.collection('active_sessions').doc(uid).get();
    if (sessionDoc.exists) {
      return 'حسابك مفتوح على جهاز آخر. يجب تسجيل الخروج من الجهاز الأول أولاً.';
    }
    return null;
  }

  // ─── Clear active session ───
  Future<void> clearSession(String uid) async {
    await _db.collection('active_sessions').doc(uid).delete();
  }

  // ─── Email Login ───
  Future<Map<String, dynamic>?> loginWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (cred.user == null) return null;
    final userData = await _getUserData(cred.user!.uid);
    if (userData == null) return null;

    // Check single device restriction
    final blockMsg = await _checkSingleDeviceBlock(cred.user!.uid);
    if (blockMsg != null) {
      await _auth.signOut();
      throw Exception(blockMsg);
    }

    await _registerSession(cred.user!.uid, userData['name'] ?? '');
    return userData;
  }

  // ─── Email Register (Admin creates users) ───
  Future<Map<String, dynamic>?> registerWithEmail(String email, String password, Map<String, dynamic> userData) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (cred.user == null) return null;
    final uid = cred.user!.uid;
    final data = {
      'uid': uid,
      'email': email,
      'name': userData['name'] ?? '',
      'dept': userData['dept'] ?? '',
      'role': userData['role'] ?? 'employee',
      'phone': userData['phone'] ?? '',
      'empId': userData['empId'] ?? 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).set(data);
    return data;
  }

  // ─── Phone Login ───
  Future<void> sendOtp(String phone, Function(String) onCodeSent, Function(String) onError) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: '+966${phone.startsWith("0") ? phone.substring(1) : phone}',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _auth.signInWithCredential(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'فشل في إرسال الرمز');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<Map<String, dynamic>?> verifyOtp(String verificationId, String otp) async {
    final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
    final result = await _auth.signInWithCredential(cred);
    if (result.user == null) return null;
    final userData = await _getUserData(result.user!.uid);
    if (userData == null) return null;

    final blockMsg = await _checkSingleDeviceBlock(result.user!.uid);
    if (blockMsg != null) {
      await _auth.signOut();
      throw Exception(blockMsg);
    }

    await _registerSession(result.user!.uid, userData['name'] ?? '');
    return userData;
  }

  // ─── Password Reset ───
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─── Logout ───
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await clearSession(uid);
    }
    await _auth.signOut();
  }

  // ─── Get user data from Firestore ───
  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return doc.data();
    // If user exists in Auth but not in Firestore, create basic record
    final user = _auth.currentUser!;
    final data = {
      'uid': uid,
      'email': user.email ?? '',
      'name': user.displayName ?? user.email?.split('@')[0] ?? 'مستخدم',
      'dept': '',
      'role': 'employee',
      'phone': user.phoneNumber ?? '',
      'empId': 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).set(data);
    return data;
  }
}
