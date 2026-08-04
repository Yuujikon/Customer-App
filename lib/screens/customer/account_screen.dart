import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../utils/format.dart';
import '../../config/theme.dart';

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
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'edit') _showEditDialog(context, auth);
              if (v == 'photo') _pickImage(auth);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Text('Edit Profile'),
              ])),
              const PopupMenuItem(value: 'photo', child: Row(children: [
                Icon(Icons.camera_alt_outlined, size: 20),
                SizedBox(width: 12),
                Text('Change Photo'),
              ])),
            ],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), children: [
        // Avatar + name
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
        ])),

        const SizedBox(height: 32),

        // Info card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.email_outlined, color: GdcColors.terracotta),
                title: const Text('Email', style: TextStyle(fontSize: 12, color: GdcColors.textMuted, fontWeight: FontWeight.bold)),
                subtitle: Text(auth.email, style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary))),
            const Divider(height: 1, indent: 56),
            ListTile(
                leading: const Icon(Icons.phone_outlined, color: GdcColors.terracotta),
                title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: GdcColors.textMuted, fontWeight: FontWeight.bold)),
                subtitle: Text(auth.phoneNumber ?? 'Not set', style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary))),
            const Divider(height: 1, indent: 56),
            ListTile(
                leading: const Icon(Icons.wc_outlined, color: GdcColors.terracotta),
                title: const Text('Gender', style: TextStyle(fontSize: 12, color: GdcColors.textMuted, fontWeight: FontWeight.bold)),
                subtitle: Text(auth.gender ?? 'Not specified', style: const TextStyle(fontWeight: FontWeight.w700, color: GdcColors.textPrimary))),
          ])),

        const SizedBox(height: 16),

        // About card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
          child: Column(children: [
            const ListTile(
                leading: Icon(Icons.store_outlined, color: GdcColors.terracotta),
                title: Text('GDC Sari-Sari Store', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Pickup hours: 9:00 AM – 10:00 PM')),
            const Divider(height: 1, indent: 56),
            ListTile(
                leading: const Icon(Icons.info_outline, color: GdcColors.terracotta),
                title: const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Earn 1 point for every ${formatPeso(100)} spent! Points can be used for future rewards.', style: const TextStyle(fontSize: 12))),
          ])),

        const SizedBox(height: 32),

        // Sign out
        OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Sign Out?'),
                  content: const Text('You will need to sign in again to place new orders.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          minimumSize: const Size(100, 40),
                          elevation: 0,
                        ),
                        child: const Text('Sign Out')),
                  ],
                ),
              );
              if (confirm == true) {
                await auth.signOut();
                widget.onLogout();
              }
            },
            icon:  const Icon(Icons.logout, color: Colors.red),
            label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      ]),
    );
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
    String? tempGender = auth.gender;

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
                DropdownButtonFormField<String>(
                  value: tempGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => tempGender = v),
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
                  gender: tempGender,
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
