import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/name_validator.dart';
import '../providers/auth_provider.dart';
import '../../home/customer_app.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone if available in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AppAuthProvider>();
      if (auth.phoneNumber != null && auth.phoneNumber!.isNotEmpty) {
        _phoneController.text = auth.phoneNumber!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (!isValidRealName(name)) {
      setState(() {
        _errorMessage =
            'Please enter a valid First and Last name (e.g., Juan Dela Cruz) with proper capitalization and no emojis or numbers.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AppAuthProvider>();
      await authProvider.completeProfileSetup(
        fullName: name,
        phone: phone.isNotEmpty ? phone : null,
      );

      if (!mounted) return;

      // Navigate straight to Customer Dashboard / Customer App
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerApp()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save profile. ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GdcColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: GdcColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: GdcColors.mutedText),
            tooltip: '',
            onPressed: () => context.read<AppAuthProvider>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Avatar Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: GdcColors.sageTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_ind_rounded,
                          size: 42,
                          color: GdcColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Welcome to GDC Store!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: GdcColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Material 3 Friendly Alert Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GdcColors.sageTint.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: GdcColors.forest.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: GdcColors.forest,
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "It looks like your Google name doesn't match our store format. Please enter your real name for order pickups.",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GdcColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Name Input Card
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: GdcColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR REAL NAME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: GdcColors.mutedText,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full Name (First & Last)',
                                hintText: 'e.g. Juan Dela Cruz',
                                prefixIcon: Icon(Icons.person_rounded,
                                    color: GdcColors.forest),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                if (!isValidRealName(val)) {
                                  return 'Enter first and last name with standard capitalization (e.g. Maria Clara)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PHONE NUMBER (FOR ORDER PICKUPS)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: GdcColors.mutedText,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '09123456789',
                                prefixIcon: Icon(Icons.phone_rounded,
                                    color: GdcColors.forest),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (val.trim().length < 10) {
                                    return 'Please enter a valid phone number';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GdcColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: GdcColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: GdcColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GdcColors.orangeCTA,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SAVE & CONTINUE TO STORE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
