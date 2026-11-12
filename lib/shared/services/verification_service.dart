import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class VerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // 1. BREVO EMAIL VERIFICATION
  // ==========================================
  // ⚠️ Important: Replace this with your actual Brevo API Key
  static const String _brevoApiKey = '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';
  static const String _emailEndpoint = 'https://api.brevo.com/v3/smtp/email';

  // ==========================================
  // 2. TRACCAR SMS GATEWAY (ANDROID)
  // ==========================================
  // ⚠️ Important: Replace this with the URL shown on the Traccar app screen 
  // (e.g., http://192.168.1.15:8082/ )
  static const String _traccarGatewayUrl = 'http://YOUR_PHONE_IP:8082/';
  // ⚠️ Important: Replace this with the token you set in the Traccar app settings
  static const String _traccarToken = 'YOUR_TRACCAR_TOKEN_HERE';

  /// Generates a random 6-digit OTP code
  static String _generateOtp() {
    final random = Random();
    int code = random.nextInt(900000) + 100000; // Generates 100000 to 999999
    return code.toString();
  }

  /// Initiates the OTP process (Generates, saves to Firestore, and sends)
  static Future<bool> sendOtp({
    required String contactMethod, // can be an email or a phone number
    required bool isEmail,
  }) async {
    try {
      final String otpCode = _generateOtp();

      // 1. Save OTP to Firestore (valid for 5 minutes)
      await _firestore.collection('otp_requests').doc(contactMethod).set({
        'code': otpCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        'attempts': 0, // Track incorrect attempts
      });

      // 2. Send the OTP
      if (isEmail) {
        return await _sendEmail(contactMethod, otpCode);
      } else {
        return await _sendSms(contactMethod, otpCode);
      }
    } catch (e) {
      debugPrint('Error initiating OTP: $e');
      return false;
    }
  }

  /// Verifies if the entered OTP matches the one in Firestore
  static Future<String?> verifyOtp({
    required String contactMethod,
    required String enteredCode,
  }) async {
    try {
      final docRef = _firestore.collection('otp_requests').doc(contactMethod);
      final doc = await docRef.get();

      if (!doc.exists) {
        return 'No OTP request found for this contact. Please request a new code.';
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final attempts = data['attempts'] as int? ?? 0;

      if (DateTime.now().isAfter(expiresAt)) {
        return 'OTP has expired. Please request a new code.';
      }

      if (attempts >= 5) {
        return 'Too many incorrect attempts. Please request a new code.';
      }

      if (enteredCode != storedCode) {
        // Increment attempts
        await docRef.update({'attempts': FieldValue.increment(1)});
        return 'Incorrect OTP code. Please try again.';
      }

      // Success! Clean up the document
      await docRef.delete();
      return null; // Null means success (no error string)
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return 'An error occurred during verification. Please try again.';
    }
  }

  /// Internal: Sends email via Brevo
  static Future<bool> _sendEmail(String toEmail, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse(_emailEndpoint),
        headers: {
          'accept': 'application/json',
          'api-key': _brevoApiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          "sender": {"name": "GDC Store", "email": "noreply@gdcstore.com"},
          "to": [{"email": toEmail}],
          "subject": "Your GDC Store Verification Code",
          "htmlContent": "<h2>GDC Store</h2><p>Your verification code is: <strong>$otpCode</strong></p><p>This code is valid for 5 minutes. Please do not share this with anyone.</p>"
        }),
      );
      
      // 201 Created is the success code for Brevo
      if (response.statusCode == 201) return true;
      
      debugPrint('Brevo Error: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error sending Email OTP: $e');
      return false;
    }
  }

  /// Internal: Sends SMS via Android Gateway
  /// Internal: Sends SMS via Traccar SMS Gateway (Android)
  static Future<bool> _sendSms(String phoneNumber, String otpCode) async {
    try {
      // Ensure phone number starts with +63 for PH numbers if needed, 
      // though Traccar usually handles local formats fine depending on your telco.
      final response = await http.post(
        Uri.parse(_traccarGatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _traccarToken, 
        },
        body: jsonEncode({
          "to": phoneNumber,
          "message": "GDC Store: Your verification code is $otpCode. Do not share this with anyone."
        }),
      );

      // Traccar returns 200 OK on success
      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Traccar Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending SMS via Traccar Gateway: $e');
      return false;
    }
  }
}
