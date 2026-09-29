import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class StoreInfoSheet extends StatelessWidget {
  const StoreInfoSheet({super.key});

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
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          const Text('About GDC Sari-Sari', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Your friendly neighborhood store in General Douglas MacArthur.', style: TextStyle(fontSize: 14, color: GdcColors.textSecondary)),
          const SizedBox(height: 24),
          
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            title: 'Location',
            subtitle: 'Main St, Brgy. Poblacion, GDC',
            onTap: () => _launchUrl('https://maps.google.com/?q=GDC+Sari-Sari+Store'),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.access_time_filled_rounded,
            title: 'Store Hours',
            subtitle: 'Open Daily: 11:00 AM - 3:00 PM',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.chat_rounded,
            title: 'Chat with Us',
            subtitle: 'Message us on Messenger',
            onTap: () => _launchUrl('https://m.me/gdcsarisari'),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.phone_rounded,
            title: 'Call Store',
            subtitle: '+63 912 345 6789',
            onTap: () => _launchUrl('tel:+639123456789'),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: GdcColors.terracotta.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: GdcColors.terracotta, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GdcColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: GdcColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black12),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
