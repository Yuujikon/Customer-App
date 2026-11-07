import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/common/social_media_sheet.dart';

class StoreLauncher {
  static const String defaultFacebookUrl =
      'https://www.facebook.com/yuujikon.hinampas';
  static const String defaultMessengerUrl =
      'https://m.me/yuujikon.hinampas';

  static void showSocialMedia(BuildContext context) {
    showSocialMediaSheet(context);
  }

  static Future<void> launchUrlString(BuildContext context, String url) async {
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch link: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> launchFacebook(BuildContext context,
      [String? facebookUrl]) async {
    final targetUrl = (facebookUrl != null && facebookUrl.trim().isNotEmpty)
        ? facebookUrl.trim()
        : defaultFacebookUrl;
    await launchUrlString(context, targetUrl);
  }

  static Future<void> launchMessenger(BuildContext context) async {
    await launchUrlString(context, defaultMessengerUrl);
  }
}
