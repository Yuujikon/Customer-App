import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/name_validator.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/store_hours.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/otp_verification_screen.dart';
import '../../../shared/services/verification_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/models/customer_appeal.dart';
import '../widgets/info/store_info_sheet.dart';
import '../../../shared/widgets/common/logout_confirm_dialog.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              Text(
                'Account & store',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage your profile and find store information.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              if (isTablet)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileCard(
                                context, auth, displayName, email, isTablet),
                            const SizedBox(height: 16),
                            _buildAccountStandingCard(context, auth),
                            const SizedBox(height: 16),
                            _buildStoreCard(context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildStoreBioCard(context)),
                    ],
                  ),
                )
              else ...[
                _buildProfileCard(context, auth, displayName, email, isTablet),
                const SizedBox(height: 16),
                _buildAccountStandingCard(context, auth),
                const SizedBox(height: 16),
                _buildStoreBioCard(context),
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

  Widget _buildProfileCard(BuildContext context, AppAuthProvider auth,
      String name, String email, bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.2),
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
                border: Border.all(
                    color: AppColors.orangeCTA.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.orangeCTA, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (auth.phoneNumber != null &&
                              auth.phoneNumber!.trim().isNotEmpty)
                          ? auth.phoneNumber!
                          : 'No phone number provided',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),

          // Action Buttons
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, auth),
                    icon: const Icon(Icons.edit_note_rounded,
                        size: 18, color: AppColors.forest),
                    label: const Text('Edit Personal Information'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                          color: Theme.of(context).dividerColor, width: 1.2),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStandingCard(BuildContext context, AppAuthProvider auth) {
    final isRestricted = auth.isOrderRestricted;
    final isLocked = auth.isPermanentlyLocked;
    final offenseCount = auth.offenseCount;
    final remainingDuration = auth.remainingRestrictionDuration;

    final Color cardColor;
    final Color badgeColor;
    final IconData iconData;
    final String statusTitle;
    final String statusSubtitle;

    if (isLocked) {
      cardColor = const Color(0xFFFFEBEE);
      badgeColor = const Color(0xFFC62828);
      iconData = Icons.gavel_rounded;
      statusTitle = '4th Offense · Permanently Locked';
      statusSubtitle =
          'Your account is permanently locked from placing pre-orders due to repeated uncollected/ghosted orders. You can submit an appeal below.';
    } else if (isRestricted) {
      cardColor = const Color(0xFFFFF3E0);
      badgeColor = const Color(0xFFE65100);
      iconData = Icons.warning_amber_rounded;

      final remainingText = remainingDuration != null
          ? _formatRemainingDuration(remainingDuration)
          : 'Active restriction';

      if (offenseCount == 1) {
        statusTitle = '1st Offense · 2-Hour Order Restriction';
        statusSubtitle =
            'Restricted from ordering. Try again in $remainingText. Avoid ghosting pre-orders to keep your account in good standing.';
      } else if (offenseCount == 2) {
        statusTitle = '2nd Offense · 24-Hour Order Restriction';
        statusSubtitle =
            'Restricted from ordering. Try again in $remainingText. Repeated uncollected orders will result in longer penalties.';
      } else {
        statusTitle = '3rd Offense · 72-Hour (3-Day) Order Restriction';
        statusSubtitle =
            'Restricted from ordering. Try again in $remainingText. Note: Next offense results in permanent account lock.';
      }
    } else {
      cardColor = const Color(0xFFE8F5E9);
      badgeColor = const Color(0xFF2E7D32);
      iconData = Icons.verified_user_rounded;
      statusTitle = offenseCount == 0
          ? 'Good Standing (0 Offenses)'
          : 'Active Standing ($offenseCount Offense${offenseCount > 1 ? "s" : ""})';
      statusSubtitle = offenseCount == 0
          ? 'Your account has full pre-order privileges and no active restrictions.'
          : 'Your previous restriction period has expired. Please ensure you pick up all future pre-orders on time.';
    }

    final userId = auth.currentUser?.uid ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.05),
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
              Text(
                'ACCOUNT STANDING & PERMISSIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      isLocked
                          ? 'LOCKED'
                          : (isRestricted ? 'RESTRICTED' : 'NORMAL'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (userId.isNotEmpty)
            StreamBuilder<List<CustomerAppeal>>(
              stream: FirestoreService().appealsStreamForUser(userId),
              builder: (context, snapshot) {
                final appeals = snapshot.data ?? [];
                appeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final pendingAppeal = appeals
                    .where((a) => a.status == AppealStatus.pending)
                    .firstOrNull;
                final latestAppeal = appeals.firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    if (pendingAppeal != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Appeal Pending Admin Review',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    'Submitted on ${DateFormat('MMM d, h:mm a').format(pendingAppeal.createdAt)}. Store management will review your request.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (latestAppeal != null && pendingAppeal == null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: latestAppeal.status == AppealStatus.approved
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  latestAppeal.status == AppealStatus.approved
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                latestAppeal.status == AppealStatus.approved
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color:
                                    latestAppeal.status == AppealStatus.approved
                                        ? Colors.green
                                        : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  latestAppeal.status == AppealStatus.approved
                                      ? 'Latest Appeal: Approved by Store Admin'
                                      : 'Latest Appeal: Rejected${latestAppeal.adminNotes != null ? " (${latestAppeal.adminNotes})" : ""}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: latestAppeal.status ==
                                            AppealStatus.approved
                                        ? Colors.green[800]
                                        : Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isRestricted || isLocked || offenseCount > 0) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showOffensePolicyDialog(context),
                            icon: const Icon(Icons.info_outline_rounded,
                                size: 16),
                            label: const Text('View Offense Policy & Tiers'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey,
                              side: const BorderSide(
                                  color: Colors.blueGrey, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showAppealDialog(context, auth),
                            icon: const Icon(Icons.gavel_rounded, size: 16),
                            label: const Text('Submit Appeal to Store Admin'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: badgeColor,
                              side: BorderSide(color: badgeColor, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatRemainingDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final mins = d.inMinutes % 60;
      return '$hours hr${hours > 1 ? "s" : ""} ${mins} min${mins > 1 ? "s" : ""}';
    } else {
      final mins = d.inMinutes;
      return '$mins min${mins > 1 ? "s" : ""}';
    }
  }

  void _showOffensePolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.policy_rounded, color: Colors.blueGrey),
            SizedBox(width: 10),
            Expanded(
              child: Text('Offense Policy & Tiers',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our pre-order system uses a tier-based penalty system for uncollected (ghosted) orders to ensure fair service for everyone.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 16),
              _TierItem(
                tier: '1st Offense',
                penalty: '2-Hour Order Restriction',
                description:
                    'A temporary restriction giving you time to pick up future orders on time.',
                color: Colors.orange,
              ),
              _TierItem(
                tier: '2nd Offense',
                penalty: '24-Hour Order Restriction',
                description: 'A full day restriction for a repeated offense.',
                color: Colors.deepOrange,
              ),
              _TierItem(
                tier: '3rd Offense',
                penalty: '72-Hour (3-Day) Restriction',
                description:
                    'A strict 3-day restriction. Next offense leads to a permanent lock.',
                color: Colors.red,
              ),
              _TierItem(
                tier: '4th Offense',
                penalty: 'Permanent Account Lock',
                description:
                    'Your account is permanently locked from placing pre-orders.',
                color: Colors.redAccent,
              ),
              SizedBox(height: 16),
              Text(
                'Note: If your appeal is approved by the store admin, your offense tier will be Reduced by 1.',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppealDialog(BuildContext context, AppAuthProvider auth) {
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: AppColors.orangeCTA),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Submit Restriction Appeal',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explain why you missed or ghosted your pre-order pick up. Your appeal will be reviewed by store management.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Enter your explanation for missing the order (e.g. medical emergency, technical issue)...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.forest, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please enter an explanation for your appeal.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => submitting = true);

                        try {
                          final appeal = CustomerAppeal(
                            id: '',
                            userId: auth.currentUser?.uid ?? '',
                            customerEmail: auth.email,
                            customerName: auth.displayName,
                            offenseCount: auth.offenseCount,
                            reason: reason,
                            status: AppealStatus.pending,
                            createdAt: DateTime.now(),
                          );

                          await FirestoreService().submitAppeal(appeal);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '🎉 Your appeal has been submitted to store admins for review.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => submitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit appeal: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Appeal',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.2),
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
          Text(
            'GDC Store · Main',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 18),

          // Address
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            primary: 'Main St, Brgy. Poblacion',
            secondary: 'General Douglas MacArthur',
          ),

          const SizedBox(height: 14),

          // Operating Hours
          _buildInfoRow(
            icon: Icons.access_time_filled_rounded,
            primary: StoreHours.isOpen()
                ? 'Open today until 3:00 PM'
                : 'Closed · Opens at 11:00 AM',
            secondary: 'Open Daily, 11:00 AM–3:00 PM',
          ),

          const SizedBox(height: 14),

          // Contact / Social Media
          _buildInfoRow(
            icon: Icons.chat_rounded,
            primary: 'Social Media & Channels',
            secondary: 'Facebook, Messenger & Hotline',
            onTap: () => StoreLauncher.showSocialMedia(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String primary,
    required String secondary,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.forest.withValues(alpha: 0.25)
                    : AppColors.sageTint,
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
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    secondary,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.mutedText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) async {
    final auth = context.read<AppAuthProvider>();
    final confirm = await LogoutConfirmDialog.show(context);
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

  Future<void> _showEditDialog(
      BuildContext context, AppAuthProvider auth) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditPersonalInformationDialog(auth: auth),
    );

    if (result == null || !mounted) return;

    final String? updatedName = result['updatedName'];
    final String? newPhoneToVerify = result['newPhoneToVerify'];

    if (newPhoneToVerify != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            contactMethod: newPhoneToVerify,
            isEmail: false,
            onSuccess: () async {
              Navigator.pop(context); // Close OTP screen
              await auth.updateProfile(
                name: updatedName,
                phone: newPhoneToVerify,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Phone number verified and updated successfully!'),
                    backgroundColor: AppColors.forest,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Widget _buildStoreBioCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1.2,
        ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STORE BIO & MISSION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sage,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.forest.withValues(alpha: 0.25)
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Verified Store',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.forest.withValues(alpha: 0.25)
                          : AppColors.sageTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GDC Sari-Sari Store',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your friendly neighborhood store in General Douglas MacArthur. Providing daily fresh essentials, pantry goods, cold beverages, and fast local pre-orders.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBioTag(context,
                      icon: Icons.verified_rounded, label: 'Fresh Daily'),
                  _buildBioTag(context,
                      icon: Icons.favorite_rounded, label: 'Community First'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBioTag(BuildContext context,
      {required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.forest),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EditPersonalInformationDialog extends StatefulWidget {
  final AppAuthProvider auth;

  const _EditPersonalInformationDialog({required this.auth});

  @override
  State<_EditPersonalInformationDialog> createState() =>
      __EditPersonalInformationDialogState();
}

class __EditPersonalInformationDialogState
    extends State<_EditPersonalInformationDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  late final String _initialName;
  late final String _initialPhoneDigits;
  bool _isLoading = false;

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final auth = widget.auth;
    _initialName =
        (auth.displayName != 'Customer' && auth.displayName.isNotEmpty)
            ? auth.displayName
            : (auth.currentUser?.displayName ?? '');
    _initialPhoneDigits = _extractPhDigits(auth.phoneNumber ?? '');

    _nameCtrl = TextEditingController(text: _initialName);
    _phoneCtrl =
        TextEditingController(text: _formatPhDigits(_initialPhoneDigits));

    _nameCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
    _nameFocusNode.addListener(_onFieldChanged);
    _phoneFocusNode.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _nameFocusNode.removeListener(_onFieldChanged);
    _phoneFocusNode.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  static String _extractPhDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length >= 12) {
      return digits.substring(2, 12);
    }
    if (digits.startsWith('0') && digits.length >= 11) {
      return digits.substring(1, 11);
    }
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  static String _formatPhDigits(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    final truncated = clean.length > 10 ? clean.substring(0, 10) : clean;
    final buffer = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(truncated[i]);
    }
    return buffer.toString();
  }

  String get _currentNameTrimmed => _nameCtrl.text.trim();
  String get _currentPhoneDigits =>
      _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

  bool get _hasNameChanged => _currentNameTrimmed != _initialName;
  bool get _hasPhoneChanged => _currentPhoneDigits != _initialPhoneDigits;
  bool get _hasChanges => _hasNameChanged || _hasPhoneChanged;

  Future<void> _handleSave() async {
    if (!_hasChanges || _isLoading) return;

    String? updatedName;
    String? newPhoneToVerify;

    if (_hasNameChanged) {
      final formattedName = capitalizeName(_nameCtrl.text);
      if (formattedName.isEmpty ||
          formattedName == 'Customer' ||
          formattedName == 'Guest' ||
          !isValidRealName(formattedName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid full name.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      updatedName = formattedName;
    }

    if (_hasPhoneChanged) {
      final phoneDigits = _currentPhoneDigits;
      if (phoneDigits.isNotEmpty && phoneDigits.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 10-digit phone number.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (phoneDigits.isNotEmpty) {
        newPhoneToVerify = '+63$phoneDigits';
      }
    }

    setState(() => _isLoading = true);

    try {
      if (newPhoneToVerify != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sending SMS verification code to your new phone number...'),
            duration: Duration(seconds: 2),
          ),
        );

        final otpSent = await VerificationService.sendOtp(
          contactMethod: newPhoneToVerify,
          isEmail: false,
        );

        if (!mounted) return;

        if (!otpSent) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to send SMS verification code. Please check the number and try again.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        // Close edit dialog and return details payload to _AccountScreenState
        Navigator.pop(context, {
          'updatedName': updatedName,
          'newPhoneToVerify': newPhoneToVerify,
        });
      } else {
        // Name-only change
        await widget.auth.updateProfile(
          name: updatedName,
          phone: null,
        );
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile name updated successfully!'),
              backgroundColor: AppColors.forest,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = Theme.of(context).cardColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.mutedText;
    final inputBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Colors.white;
    final borderColor = Theme.of(context).dividerColor;

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Top-Right Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Edit Personal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(100),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form Content Area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Full Name
                    Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _nameFocusNode.hasFocus
                              ? const Color(0xFF326234)
                              : (isDark
                                  ? borderColor
                                  : const Color(0xFFCBD2C6)),
                          width: _nameFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: _nameFocusNode.hasFocus
                            ? [
                                const BoxShadow(
                                  color: Color(0x26326234),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: _nameFocusNode.hasFocus
                                ? const Color(0xFF326234)
                                : textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              focusNode: _nameFocusNode,
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: 'Enter full name...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: textMuted.withValues(alpha: 0.7),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                suffixIcon: _nameCtrl.text.isNotEmpty
                                    ? InkWell(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        onTap: () => _nameCtrl.clear(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: textMuted,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Field 2: Phone Number
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _phoneFocusNode.hasFocus
                              ? const Color(0xFF326234)
                              : (isDark
                                  ? borderColor
                                  : const Color(0xFFCBD2C6)),
                          width: _phoneFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: _phoneFocusNode.hasFocus
                            ? [
                                const BoxShadow(
                                  color: Color(0x26326234),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.call_outlined,
                            size: 20,
                            color: _phoneFocusNode.hasFocus
                                ? const Color(0xFF326234)
                                : textMuted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            height: 16,
                            width: 1,
                            color:
                                isDark ? borderColor : const Color(0xFFCBD2C6),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                PhPhoneTextInputFormatter(),
                              ],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: '9XX XXX XXXX',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: textMuted.withValues(alpha: 0.7),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                suffixIcon: _phoneCtrl.text.isNotEmpty
                                    ? InkWell(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        onTap: () => _phoneCtrl.clear(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: textMuted,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons Row: Cancel & Save Changes
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: isDark
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : const Color(0xFFF3F4F6),
                      foregroundColor:
                          isDark ? textPrimary : const Color(0xFF374151),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasChanges && !_isLoading ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orangeCTA,
                      disabledBackgroundColor:
                          AppColors.orangeCTA.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.7),
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierItem extends StatelessWidget {
  final String tier;
  final String penalty;
  final String description;
  final Color color;

  const _TierItem({
    required this.tier,
    required this.penalty,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tier: $penalty',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PhPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated =
        digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;
    final buffer = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(truncated[i]);
    }
    final formatted = buffer.toString();

    int selectionIndex = formatted.length;
    if (newValue.selection.end < newValue.text.length) {
      final digitsBeforeCursor = newValue.text
          .substring(0, newValue.selection.end)
          .replaceAll(RegExp(r'\D'), '')
          .length;
      int digitCount = 0;
      int newOffset = 0;
      for (int i = 0; i < formatted.length; i++) {
        if (formatted[i] != ' ') {
          digitCount++;
        }
        if (digitCount == digitsBeforeCursor) {
          newOffset = i + 1;
          break;
        }
      }
      selectionIndex = newOffset.clamp(0, formatted.length);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
