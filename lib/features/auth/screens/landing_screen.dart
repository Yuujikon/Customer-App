import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/store_hours.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common/brand_logo.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isOpen = StoreHours.isOpen();
    final isLargeScreen = Responsive.isLargeScreen(context);

    Widget buildSignInButton() {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CustomerAuthScreen(isRegister: false)),
        ),
        icon: const Icon(Icons.login_rounded, size: 20),
        label: const Text('Sign In to Order'),
        style: ElevatedButton.styleFrom(
          backgroundColor: GdcColors.orangeCTA,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
        ),
      );
    }

    Widget buildRegisterButton() {
      return OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CustomerAuthScreen(isRegister: true)),
        ),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Create New Account'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: GdcColors.terracotta,
          side: const BorderSide(color: GdcColors.terracotta, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 24 : 32,
                vertical: isLargeScreen ? 24 : 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const BrandLogo(size: 90, showText: true),
                  const SizedBox(height: 16),

                  // Store Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? GdcColors.peachLight
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: isOpen
                              ? GdcColors.terracotta
                                  .withValues(alpha: 0.2)
                              : const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? GdcColors.success
                                : GdcColors.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOpen
                              ? 'Store Open · Pickup Available'
                              : 'Store Currently Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isOpen
                                ? GdcColors.terracotta
                                : GdcColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Onboarding Hero Graphic Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFFE5EBDD)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF4F7EE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_rounded,
                              size: 64, color: GdcColors.terracotta),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Fresh Groceries Ready for Pickup',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: GdcColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Pre-order fresh produce, snacks, and daily essentials from GDC Store for quick in-store pickup.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GdcColors.textMuted,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (isLargeScreen)
                          Row(
                            children: [
                              Expanded(child: buildSignInButton()),
                              const SizedBox(width: 14),
                              Expanded(child: buildRegisterButton()),
                            ],
                          )
                        else ...[
                          buildSignInButton(),
                          const SizedBox(height: 12),
                          buildRegisterButton(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
