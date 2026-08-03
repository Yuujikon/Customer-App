import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

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
      appBar: AppBar(
          title: Text(widget.isRegister ? 'Create Account' : 'Sign In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 8),
          if (widget.isRegister)
            TextField(controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name')),
          if (widget.isRegister) const SizedBox(height: 12),
          TextField(controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: _password,
              decoration: InputDecoration(
                  labelText: widget.isRegister
                      ? 'Password (min 6 chars)' : 'Password'),
              obscureText: true),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : () async {
              setState(() { _loading = true; _error = ''; });
              try {
                if (widget.isRegister) {
                  await context.read<AppAuthProvider>().signUp(
                      _email.text.trim(), _password.text, _name.text.trim());
                } else {
                  await context.read<AppAuthProvider>().signIn(
                      _email.text.trim(), _password.text);
                }
                // _Root in main.dart listens to authStateChanges and navigates automatically
                if (mounted) Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                setState(() {
                  _error = e.message ?? 'Something went wrong';
                  _loading = false;
                });
              }
            },
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : Text(widget.isRegister ? 'Create Account' : 'Sign In'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => CustomerAuthScreen(
                      isRegister: !widget.isRegister)));
            },
            child: Text(widget.isRegister
                ? 'Already have an account? Sign In'
                : "Don't have an account? Register"),
          ),
        ]),
      ),
    );
  }
}