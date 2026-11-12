import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/verification_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String contactMethod; // The email or phone number
  final bool isEmail;
  final VoidCallback onSuccess; // Triggered when OTP is correctly verified

  const OtpVerificationScreen({
    super.key,
    required this.contactMethod,
    required this.isEmail,
    required this.onSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Resend Timer logic
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _sendInitialOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _sendInitialOtp() async {
    // Attempt to send OTP in the background. 
    // You could also show a loading spinner here if desired.
    await VerificationService.sendOtp(
      contactMethod: widget.contactMethod,
      isEmail: widget.isEmail,
    );
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await VerificationService.sendOtp(
      contactMethod: widget.contactMethod,
      isEmail: widget.isEmail,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code has been sent.')),
      );
      _startResendTimer();
    } else {
      setState(() {
        _errorMessage = 'Failed to resend code. Please try again.';
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await VerificationService.verifyOtp(
      contactMethod: widget.contactMethod,
      enteredCode: code,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      // Success
      widget.onSuccess();
    } else {
      // Error
      setState(() {
        _errorMessage = error;
        _otpController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pinput standard theme
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: AppColors.primaryText,
        fontWeight: FontWeight.w800,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.sageTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isEmail
                          ? Icons.mark_email_unread_rounded
                          : Icons.sms_rounded,
                      size: 42,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Verify your account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'We sent a 6-digit code to',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.contactMethod,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // OTP Input Field
                  Pinput(
                    length: 6,
                    controller: _otpController,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(color: AppColors.forest, width: 2),
                      ),
                    ),
                    errorPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(color: AppColors.error, width: 2),
                      ),
                    ),
                    onCompleted: _verifyCode,
                    enabled: !_isLoading,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (_isLoading)
                    const CircularProgressIndicator(color: AppColors.forest)
                  else
                    Column(
                      children: [
                        Text(
                          _canResend
                              ? "Didn't receive the code?"
                              : "You can resend the code in $_secondsRemaining seconds",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _canResend ? _resendOtp : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orangeCTA,
                            disabledForegroundColor: AppColors.mutedText,
                          ),
                          child: Text(
                            'Resend Code',
                            style: TextStyle(
                              fontWeight: _canResend ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
