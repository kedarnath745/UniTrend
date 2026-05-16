import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkOpener {
  static Uri? normalize(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final decoded = trimmed.replaceAll('&amp;', '&');
    var uri = Uri.tryParse(decoded);

    if (uri == null) return null;

    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$decoded');
    }

    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  static Future<bool> open(
    BuildContext context,
    String rawUrl,
  ) async {
    final uri = normalize(rawUrl);
    if (uri == null) return false;

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        return true;
      }
    } catch (_) {}

    try {
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return true;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
    return false;
  }
}
