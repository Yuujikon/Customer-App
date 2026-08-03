import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class CustomerAuthScreen extends StatefulWidget {
  final bool isRegister;
  const CustomerAuthScreen({super.key, required this.isRegister});
  @override State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool   _loading = false;
  String _error   = '';

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
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
          
          if (widget.isRegister)
            TextField(controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded))),
          if (widget.isRegister) const SizedBox(height: 16),
          
          TextField(controller: _email,
              decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_rounded)),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          
          TextField(controller: _password,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_rounded),
                  labelText: widget.isRegister
                      ? 'Password (min 6 chars)' : 'Password'),
              obscureText: true),
          
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GdcColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Text(_error, style: const TextStyle(color: GdcColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
          
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _loading ? null : () async {
              if (_email.text.isEmpty || _password.text.isEmpty || (widget.isRegister && _name.text.isEmpty)) {
                setState(() => _error = 'Please fill in all fields');
                return;
              }
              setState(() { _loading = true; _error = ''; });
              try {
                if (widget.isRegister) {
                  await context.read<AppAuthProvider>().signUp(
                      _email.text.trim(), _password.text, _name.text.trim());
                } else {
                  await context.read<AppAuthProvider>().signIn(
                      _email.text.trim(), _password.text);
                }
                if (mounted) Navigator.pop(context);
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
