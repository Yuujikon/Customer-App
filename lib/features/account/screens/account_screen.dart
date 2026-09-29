import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/info/store_info_sheet.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const AccountScreen({super.key, required this.onLogout});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _uploading = false;
  File? _localPhoto;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: _showLogoutConfirm,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), children: [
        Center(child: Column(children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: _localPhoto != null 
                    ? FileImage(_localPhoto!) 
                    : (auth.photoUrl != null ? MemoryImage(base64Decode(auth.photoUrl!)) : null) as ImageProvider?,
                child: (_localPhoto == null && auth.photoUrl == null)
                    ? Text(
                        auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary),
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
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
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
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(auth.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(auth.email,
              style: const TextStyle(color: GdcColors.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showEditDialog(context, auth),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Edit Profile'),
          ),
        ])),

        const SizedBox(height: 24),

        const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.phone_outlined, color: GdcColors.terracotta),
                title: const Text('Phone Number', style: TextStyle(fontSize: 11, color: GdcColors.textMuted, fontWeight: FontWeight.bold)),
                subtitle: Text(auth.phoneNumber ?? 'Not set', style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary))),
            const Divider(height: 1, indent: 56),
            ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: GdcColors.terracotta),
                title: const Text('Bio', style: TextStyle(fontSize: 11, color: GdcColors.textMuted, fontWeight: FontWeight.bold)),
                subtitle: Text(auth.bio.isEmpty ? 'No bio set' : auth.bio, style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary))),
          ])),

        const SizedBox(height: 24),
        const Text('Support & Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const StoreInfoSheet(),
            ),
            leading: const Icon(Icons.help_outline_rounded, color: GdcColors.terracotta),
            title: const Text('Help & Store Info', style: TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary)),
            subtitle: const Text('Store hours, location, and contact', style: TextStyle(fontSize: 12, color: GdcColors.textMuted)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black12),
          ),
        ),

        const SizedBox(height: 40),
      ]),
    );
  }

  void _showLogoutConfirm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again to place new orders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AppAuthProvider>().signOut();
      widget.onLogout();
    }
  }

  Future<void> _pickImage(AppAuthProvider auth) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (picked != null) {
      final file = File(picked.path);
      setState(() {
        _localPhoto = file;
        _uploading = true;
      });

      try {
        await auth.uploadProfilePicture(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red)
          );
          setState(() => _localPhoto = null);
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
  }

  void _showEditDialog(BuildContext context, AppAuthProvider auth) {
    final nameCtrl = TextEditingController(text: auth.displayName);
    final phoneCtrl = TextEditingController(text: auth.phoneNumber ?? '');
    final bioCtrl  = TextEditingController(text: auth.bio);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', hintText: '09123456789'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell us about yourself'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await auth.updateProfile(
                  name:  nameCtrl.text.trim(),
                  bio:   bioCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
