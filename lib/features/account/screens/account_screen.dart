import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/info/store_info_sheet.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AccountScreen({super.key, required this.onLogout});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _uploading = false;
  Uint8List? _localPhotoBytes;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final bool isNameSet = auth.isFullNameSet;
    final displayName = isNameSet ? auth.displayName : 'Full Name Not Set';
    final email = auth.email.isNotEmpty ? auth.email : 'No email provided';

    final bool isTablet =
        Responsive.isTablet(context) || Responsive.isLargeScreen(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'YOUR GDC',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sage,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Account & store',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Manage your profile and find store information.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildProfileCard(
                            context, auth, displayName, email)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildStoreCard(context)),
                  ],
                )
              else ...[
                _buildProfileCard(context, auth, displayName, email),
                const SizedBox(height: 16),
                _buildStoreCard(context),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context, AppAuthProvider auth, String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!auth.isFullNameSet) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.orangeCTA.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.orangeCTA, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Full Name Required for Store Orders',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cashiers require your full name to verify your identity when picking up orders. Please tap Edit below.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedText,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.forest,
                    backgroundImage: _localPhotoBytes != null
                        ? MemoryImage(_localPhotoBytes!)
                        : (auth.photoUrl != null
                            ? MemoryImage(base64Decode(auth.photoUrl!))
                            : null) as ImageProvider?,
                    child: (_localPhotoBytes == null && auth.photoUrl == null)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(auth),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.orangeCTA,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.sage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Action Buttons
          OutlinedButton.icon(
            onPressed: () => _showEditDialog(context, auth),
            icon: const Icon(Icons.edit_note_rounded,
                size: 18, color: AppColors.forest),
            label: const Text('Edit Personal Information'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: () => _showLogoutConfirm(context),
            icon: const Icon(Icons.logout_rounded,
                size: 18, color: AppColors.error),
            label: const Text('Sign out of account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR PICKUP STORE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sage,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const StoreInfoSheet(),
                  );
                },
                child: const Text(
                  'Help & Hours →',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.forest),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'GDC Store · Main',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 18),

          // Address
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            primary: '128 Mabini Street',
            secondary: 'Barangay San Roque, Quezon City',
          ),

          const SizedBox(height: 14),

          // Operating Hours
          _buildInfoRow(
            icon: Icons.access_time_filled_rounded,
            primary: 'Open today until 8:00 PM',
            secondary: 'Mon–Sat, 7:00 AM–8:00 PM',
          ),

          const SizedBox(height: 14),

          // Contact
          _buildInfoRow(
            icon: Icons.phone_rounded,
            primary: '+63 912 345 6789',
            secondary: 'Call or message the store',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String primary,
    required String secondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: const BoxDecoration(
            color: AppColors.sageTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.forest,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                secondary,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirm(BuildContext context) async {
    final auth = context.read<AppAuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content:
            const Text('You will need to sign in again to place new orders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await auth.signOut();
      widget.onLogout();
    }
  }

  Future<void> _pickImage(AppAuthProvider auth) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 50,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _localPhotoBytes = bytes;
        _uploading = true;
      });

      try {
        await auth.uploadProfilePicture(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profile picture updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red),
          );
          setState(() => _localPhotoBytes = null);
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
  }

  void _showEditDialog(BuildContext context, AppAuthProvider auth) {
    final initialName = auth.isFullNameSet ? auth.displayName : '';
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: auth.phoneNumber ?? '');
    final bioCtrl = TextEditingController(text: auth.bio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Personal Information',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: !auth.isFullNameSet,
                decoration: const InputDecoration(
                  labelText: 'Full Name (First & Last Name)',
                  hintText: 'e.g., Juan Dela Cruz',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone Number', hintText: '09123456789'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(
                    labelText: 'Bio', hintText: 'Tell us about yourself'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final trimmedName = nameCtrl.text.trim();
              if (trimmedName.isEmpty || trimmedName == 'Customer' || trimmedName == 'Guest') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid full name.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              await auth.updateProfile(
                name: trimmedName,
                bio: bioCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeCTA,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Full Name'),
          ),
        ],
      ),
    );
  }
}
