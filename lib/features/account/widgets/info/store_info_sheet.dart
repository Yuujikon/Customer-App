import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/launcher.dart';
import '../../../shop/providers/inventory_provider.dart';

class StoreInfoSheet extends StatelessWidget {
  const StoreInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final websiteUrl = inventory.settings.websiteUrl.isNotEmpty
        ? inventory.settings.websiteUrl
        : 'https://gdc-sari-sari.web.app';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          Text('About GDC Sari-Sari',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Your friendly neighborhood store in General Douglas MacArthur.',
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 24),
          _buildInfoRow(
            context,
            icon: Icons.language_rounded,
            title: 'Official Website',
            subtitle: websiteUrl,
            onTap: () => _launchUrl(context, websiteUrl),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            icon: Icons.location_on_rounded,
            title: 'Location',
            subtitle: 'Main St, Brgy. Poblacion, GDC',
            onTap: () => _launchUrl(
                context, 'https://maps.google.com/?q=GDC+Sari-Sari+Store'),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            icon: Icons.access_time_filled_rounded,
            title: 'Store Hours',
            subtitle: 'Open Daily: 11:00 AM - 3:00 PM',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            icon: Icons.chat_rounded,
            title: 'Social Media & Channels',
            subtitle: 'Facebook, Messenger & Chat',
            onTap: () => StoreLauncher.showSocialMedia(context),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            icon: Icons.phone_rounded,
            title: 'Call Store',
            subtitle: '+63 912 345 6789',
            onTap: () => _launchUrl(context, 'tel:+639123456789'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56)),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch URL: $e')),
        );
      }
    }
  }
}
