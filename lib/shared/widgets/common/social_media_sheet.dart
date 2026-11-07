import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/launcher.dart';

void showSocialMediaSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SocialMediaSheet(),
  );
}

class SocialMediaSheet extends StatelessWidget {
  const SocialMediaSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Store Social Media & Channels',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect with GDC Sari-Sari Store on your preferred platform.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Facebook Page
          _SocialTile(
            icon: Icons.facebook_rounded,
            title: 'Facebook Page',
            subtitle: 'facebook.com/yuujikon.hinampas',
            brandColor: const Color(0xFF1877F2),
            onTap: () {
              Navigator.pop(context);
              StoreLauncher.launchFacebook(context);
            },
          ),

          const SizedBox(height: 12),

          // 2. Messenger Direct Chat
          _SocialTile(
            icon: Icons.chat_rounded,
            title: 'Messenger Direct Chat',
            subtitle: 'm.me/yuujikon.hinampas',
            brandColor: const Color(0xFF0084FF),
            onTap: () {
              Navigator.pop(context);
              StoreLauncher.launchMessenger(context);
            },
          ),

          const SizedBox(height: 12),

          // 3. Store Direct Phone Call
          _SocialTile(
            icon: Icons.phone_in_talk_rounded,
            title: 'Store Hotline',
            subtitle: '+63 912 345 6789',
            brandColor: AppColors.forest,
            onTap: () {
              Navigator.pop(context);
              StoreLauncher.launchUrlString(context, 'tel:+639123456789');
            },
          ),

          const SizedBox(height: 12),

          // 4. Official Website
          _SocialTile(
            icon: Icons.language_rounded,
            title: 'Official Store Website',
            subtitle: 'gdc-sari-sari.web.app',
            brandColor: AppColors.orangeCTA,
            onTap: () {
              Navigator.pop(context);
              StoreLauncher.launchUrlString(
                  context, 'https://gdc-sari-sari.web.app');
            },
          ),

          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.creamDark,
              foregroundColor: AppColors.primaryText,
              elevation: 0,
            ),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color brandColor;
  final VoidCallback onTap;

  const _SocialTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.brandColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: brandColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: brandColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: brandColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: brandColor,
            ),
          ],
        ),
      ),
    );
  }
}
