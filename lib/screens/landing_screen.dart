import 'package:flutter/material.dart';
import 'auth/customer_auth_screen.dart';
import '../utils/store_hours.dart';
import '../config/theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isOpen = StoreHours.isOpen();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: GdcColors.terracotta.withOpacity(0.1), blurRadius: 20)],
            ),
            child: Icon(Icons.storefront_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 32),
          const Text('GDC Sari-Sari Store',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: GdcColors.textPrimary, letterSpacing: -0.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          // Store status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: isOpen ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 8, color: isOpen ? GdcColors.success : GdcColors.error),
              const SizedBox(width: 8),
              Text(isOpen ? 'Pickup Open · 11 AM–3 PM' : 'Pickup Closed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: isOpen ? GdcColors.success : GdcColors.error)),
            ]),
          ),
          const SizedBox(height: 60),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const CustomerAuthScreen(isRegister: false))),
            icon:  const Icon(Icons.login_rounded),
            label: const Text('Sign In to Order'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const CustomerAuthScreen(isRegister: true))),
            icon:  const Icon(Icons.person_add_rounded),
            label: const Text('Create New Account'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                side: BorderSide(color: GdcColors.terracotta.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
          const SizedBox(height: 40),
          const Text('Fresh groceries and daily essentials,\npre-ordered for your convenience.', 
            textAlign: TextAlign.center,
            style: TextStyle(color: GdcColors.textMuted, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
        ]),
      )),
    );
  }
}
