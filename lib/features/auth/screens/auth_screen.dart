import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_setup_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/name_validator.dart';
import '../../../shared/services/verification_service.dart';
import 'otp_verification_screen.dart';

class CustomerAuthScreen extends StatefulWidget {
  final bool isRegister;
  const CustomerAuthScreen({super.key, required this.isRegister});
  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String p) {
    if (p.length < 8) return false;
    if (!p.contains(RegExp(r'[A-Z]'))) return false;
    if (!p.contains(RegExp(r'[a-z]'))) return false;
    if (!p.contains(RegExp(r'[0-9]'))) return false;
    if (!p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(email)) return false;

    final blockedDomains = [
      'yopmail.com',
      'mailinator.com',
      'guerrillamail.com',
      'temp-mail.org',
      '10minutemail.com',
      'dispostable.com',
      'trashmail.com',
      'sharklasers.com',
      'getnada.com'
    ];
    final domain = email.split('@').last.toLowerCase();
    return !blockedDomains.contains(domain);
  }

  Future<void> _processRegistration(String contactMethod, bool isEmail) async {
    Navigator.pop(context); // Close the choice bottom sheet
    
    setState(() {
      _loading = true;
      _error = '';
    });

    final otpSent = await VerificationService.sendOtp(
      contactMethod: contactMethod,
      isEmail: isEmail,
    );

    setState(() => _loading = false);

    if (otpSent) {
      if (!mounted) return;
      
      final email = _email.text.trim();
      final password = _password.text;
      final name = _name.text.trim();
      final phone = _phone.text.trim();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            contactMethod: contactMethod,
            isEmail: isEmail,
            onSuccess: () async {
              setState(() => _loading = true);
              Navigator.pop(context); // close OTP screen
              
              try {
                final authProvider = context.read<AppAuthProvider>();
                await authProvider.signUp(email, password, name, phone: phone);
                if (!mounted) return;
                Navigator.pop(context); // close Auth screen
              } on FirebaseAuthException catch (e) {
                setState(() {
                  _error = e.message ?? 'Authentication failed';
                  _loading = false;
                });
              }
            },
          ),
        ),
      );
    } else {
      setState(() => _error = 'Failed to send verification code. Try again later.');
    }
  }

  void _showVerificationChoice() {
    final email = _email.text.trim();
    final phone = _phone.text.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How would you like to verify?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose where we should send your 6-digit verification code.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _processRegistration(email, true),
              icon: const Icon(Icons.email_rounded, color: AppColors.forest),
              label: Text('Send to Email ($email)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _processRegistration(phone, false),
              icon: const Icon(Icons.sms_rounded, color: AppColors.forest),
              label: Text('Send to SMS ($phone)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isRegister ? 'Create Account' : 'Welcome Back',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.isRegister
                      ? 'Join GDC Sari-Sari Store and start pre-ordering your essentials.'
                      : 'Sign in to access your orders and fresh grocery basket.',
                  style: const TextStyle(
                    color: GdcColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                if (widget.isRegister) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name (First & Last Name)',
                      prefixIcon: Icon(Icons.person_rounded),
                      hintText: 'e.g. Juan Dela Cruz',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_rounded),
                      hintText: '09123456789',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    helperText: widget.isRegister
                        ? 'Min 8 chars, 1 uppercase, 1 number, 1 special char'
                        : null,
                    helperMaxLines: 2,
                    labelText: 'Password',
                  ),
                  obscureText: !_showPassword,
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GdcColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error,
                      style: const TextStyle(
                        color: GdcColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final email = _email.text.trim();
                          if (email.isEmpty ||
                              _password.text.isEmpty ||
                              (widget.isRegister &&
                                  (_name.text.isEmpty ||
                                      _phone.text.isEmpty))) {
                            setState(
                                () => _error = 'Please fill in all fields');
                            return;
                          }
                          if (widget.isRegister) {
                            if (!isValidRealName(_name.text.trim())) {
                              setState(() => _error =
                                  'Please enter a valid First and Last name (e.g. Juan Dela Cruz).');
                              return;
                            }
                            if (!_isValidEmail(email)) {
                              setState(() => _error =
                                  'Please enter a valid, non-disposable email address');
                              return;
                            }
                            if (!_isStrongPassword(_password.text)) {
                              setState(() => _error =
                                  'Password is not strong enough. Please follow the requirements.');
                              return;
                            }

                            // Open bottom sheet so user can choose Email or SMS
                            _showVerificationChoice();
                          } else {
                            // Standard Login Flow
                            final navigator = Navigator.of(context);
                            final authProvider = context.read<AppAuthProvider>();
                            setState(() {
                              _loading = true;
                              _error = '';
                            });
                            try {
                              await authProvider.signIn(email, _password.text);
                              if (!mounted) return;
                              navigator.pop();
                            } on FirebaseAuthException catch (e) {
                              if (!mounted) return;
                              setState(() {
                                _error = e.message ?? 'Authentication failed';
                                _loading = false;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              setState(() {
                                _error = e.toString();
                                _loading = false;
                              });
                            }
                          }
                        },
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isRegister ? 'REGISTER NOW' : 'SIGN IN'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final authProvider = context.read<AppAuthProvider>();
                          setState(() {
                            _loading = true;
                            _error = '';
                          });
                          try {
                            final requiresSetup =
                                await authProvider.signInWithGoogle();
                            if (!mounted) return;
                            if (requiresSetup) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileSetupScreen(),
                                ),
                              );
                            } else {
                              navigator.pop();
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() {
                              _error =
                                  'Google Sign-In failed. Please try again.';
                              _loading = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GdcColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerAuthScreen(isRegister: !widget.isRegister),
                      ),
                    );
                  },
                  child: Text(
                    widget.isRegister
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Register here",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GdcColors.terracotta,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
