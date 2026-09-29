import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class CustomerAuthScreen extends StatefulWidget {
  final bool isRegister;
  const CustomerAuthScreen({super.key, required this.isRegister});
  @override State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _phone    = TextEditingController();
  final _password = TextEditingController();
  bool   _showPassword = false;
  bool   _loading = false;
  String _error   = '';

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose(); _password.dispose();
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
    // Robust email regex
    final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(email)) return false;

    // Block common disposable email domains
    final blockedDomains = [
      'yopmail.com', 'mailinator.com', 'guerrillamail.com', 
      'temp-mail.org', '10minutemail.com', 'dispostable.com',
      'trashmail.com', 'sharklasers.com', 'getnada.com'
    ];
    final domain = email.split('@').last.toLowerCase();
    return !blockedDomains.contains(domain);
  }

  Future<void> _showPhonePrompt(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false, // Force them to enter it
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('One last thing!', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide your phone number for pre-order contact.', 
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09123456789',
                  errorText: error,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final p = phoneCtrl.text.trim();
                if (p.isEmpty || p.length < 10) {
                  setDialogState(() => error = 'Please enter a valid phone number');
                  return;
                }
                await context.read<AppAuthProvider>().updateProfile(phone: p);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('COMPLETE SIGNUP'),
            ),
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
          title: Text(widget.isRegister ? 'Create Account' : 'Welcome Back', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const SizedBox(height: 20),
          Text(widget.isRegister 
            ? 'Join GDC Sari-Sari Store and start pre-ordering your essentials.' 
            : 'Sign in to access your orders and fresh grocery basket.',
            style: const TextStyle(color: GdcColors.textSecondary, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 40),
          
          if (widget.isRegister) ...[
            TextField(controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 16),
            TextField(controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_rounded), hintText: '09123456789'),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
          ],
          
          TextField(controller: _email,
              decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_rounded)),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          
          TextField(controller: _password,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  helperText: widget.isRegister ? 'Min 8 chars, 1 uppercase, 1 number, 1 special char' : null,
                  helperMaxLines: 2,
                  labelText: 'Password'),
              obscureText: !_showPassword),
          
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GdcColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Text(_error, style: const TextStyle(color: GdcColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
          
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _loading ? null : () async {
              final email = _email.text.trim();
              if (email.isEmpty || _password.text.isEmpty || (widget.isRegister && (_name.text.isEmpty || _phone.text.isEmpty))) {
                setState(() => _error = 'Please fill in all fields');
                return;
              }
              if (widget.isRegister) {
                if (!_isValidEmail(email)) {
                  setState(() => _error = 'Please enter a valid, non-disposable email address');
                  return;
                }
                if (!_isStrongPassword(_password.text)) {
                  setState(() => _error = 'Password is not strong enough. Please follow the requirements.');
                  return;
                }
              }

              setState(() { _loading = true; _error = ''; });
              try {
                if (widget.isRegister) {
                  await context.read<AppAuthProvider>().signUp(
                      email, _password.text, _name.text.trim(), phone: _phone.text.trim());
                } else {
                  await context.read<AppAuthProvider>().signIn(
                      email, _password.text);
                }
                if (!mounted) return;
                Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                setState(() {
                  _error = e.message ?? 'Authentication failed';
                  _loading = false;
                });
              } catch (e) {
                setState(() {
                  _error = e.toString();
                  _loading = false;
                });
              }
            },
            child: _loading
                ? const SizedBox(height: 24, width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white))
                : Text(widget.isRegister ? 'REGISTER NOW' : 'SIGN IN'),
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : () async {
              setState(() { _loading = true; _error = ''; });
              try {
                final phoneMissing = await context.read<AppAuthProvider>().signInWithGoogle();
                if (phoneMissing && mounted) {
                  await _showPhonePrompt(context);
                }
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                setState(() {
                  _error = 'Google Sign-In failed. Please try again.';
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
              Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => CustomerAuthScreen(
                      isRegister: !widget.isRegister)));
            },
            child: Text(widget.isRegister
                ? 'Already have an account? Sign In'
                : "Don't have an account? Register here", style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.terracotta)),
          ),
        ]),
      ),
    );
  }
}
