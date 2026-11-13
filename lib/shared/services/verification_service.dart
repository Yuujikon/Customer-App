import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class VerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // ENVIRONMENT VARIABLE READERS
  // ==========================================
  static String get _brevoApiKey =>
      dotenv.env['BREVO_API_KEY'] ??
      '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';

  static String get _senderEmail =>
      dotenv.env['BREVO_SENDER_EMAIL'] ?? 'gdcstore.ph@gmail.com';

  static const String _emailEndpoint = 'https://api.brevo.com/v3/smtp/email';

  static String get _traccarGatewayUrl =>
      dotenv.env['TRACCAR_GATEWAY_URL'] ??
      'https://repaint-ideally-whoopee.ngrok-free.dev/';

  static String get _traccarToken =>
      dotenv.env['TRACCAR_TOKEN'] ?? 'c776154d-e29b-458e-ab57-221c7ee7fda2';

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

  /// Internal: Sends email via Brevo SMTP (Bypasses IP Tracking & Restrictions)
  static Future<bool> _sendEmail(String toEmail, String otpCode) async {
    try {
      final smtpServer = SmtpServer(
        'smtp-relay.brevo.com',
        port: 587,
        username: _senderEmail, // gdcstore.ph@gmail.com
        password: _brevoApiKey, // SMTP Password is the same as the API key in Brevo
      );

      final message = Message()
        ..from = Address(_senderEmail, 'GDC Store')
        ..recipients.add(toEmail)
        ..subject = 'Your GDC Store Verification Code'
        ..html = "<h2>GDC Store</h2><p>Your verification code is: <strong>$otpCode</strong></p><p>This code is valid for 5 minutes. Please do not share this with anyone.</p>";

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('SMTP Error sending Email OTP: $e');
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
          'ngrok-skip-browser-warning': 'true', // Bypasses ngrok free tier browser splash page
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
