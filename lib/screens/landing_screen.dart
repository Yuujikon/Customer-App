import 'package:flutter/material.dart';
import 'auth/customer_auth_screen.dart';
import '../utils/store_hours.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isOpen = StoreHours.isOpen();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 44,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.store, size: 44,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 20),
          Text('GDC Sari-Sari Store',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          // Store status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(50)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOpen
                      ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))),
              const SizedBox(width: 6),
              Text(isOpen ? 'Pickup Open · 11 AM–3 PM' : 'Pickup Closed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isOpen
                          ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
            ]),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const CustomerAuthScreen(isRegister: false))),
            icon:  const Icon(Icons.login),
            label: const Text('Sign In'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const CustomerAuthScreen(isRegister: true))),
            icon:  const Icon(Icons.person_add_outlined),
            label: const Text('Create Account'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
          ),
        ]),
      )),
    );
  }
}