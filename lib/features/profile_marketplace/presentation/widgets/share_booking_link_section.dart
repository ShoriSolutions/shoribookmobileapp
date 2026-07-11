import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// "Share Booking Link" section — one card per platform with a
/// ready-to-paste caption and a source-tagged booking link, mirroring the
/// web dashboard. Instagram/TikTok have no share URL, so those are
/// copy-and-paste only.
class ShareBookingLinkSection extends StatelessWidget {
  const ShareBookingLinkSection({
    super.key,
    required this.businessName,
    required this.slug,
  });

  final String businessName;
  final String slug;

  String _link(String source) =>
      'https://betterbooking.app/book/$slug?source=$source';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Share booking link', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Drive bookings from social media with ready-made links and captions.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        _PlatformCard(
          name: 'WhatsApp',
          emoji: '💬',
          color: const Color(0xFF25D366),
          link: _link('whatsapp'),
          captionLabel: 'Message',
          caption: 'Book your next appointment with $businessName here:\n'
              '${_link('whatsapp')}',
          actionLabel: 'Open WhatsApp',
          actionUrlBuilder: (caption) =>
              'https://wa.me/?text=${Uri.encodeComponent(caption)}',
        ),
        _PlatformCard(
          name: 'Instagram',
          emoji: '📷',
          color: const Color(0xFFE1306C),
          link: _link('instagram'),
          captionLabel: 'Bio text',
          caption: 'Book appointments here 👇\n${_link('instagram')}',
          actionLabel: 'Open Instagram',
          actionUrlBuilder: (_) => 'https://www.instagram.com',
          hint: 'Instagram has no pre-filled links — copy the bio text, then '
              'paste it in Edit Profile → Website or Bio.',
        ),
        _PlatformCard(
          name: 'Facebook',
          emoji: '📘',
          color: const Color(0xFF1877F2),
          link: _link('facebook'),
          captionLabel: 'Post text',
          caption: 'Book your next appointment with $businessName 📅\n'
              '${_link('facebook')}',
          actionLabel: 'Share on Facebook',
          actionUrlBuilder: (_) =>
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_link('facebook'))}',
        ),
        _PlatformCard(
          name: 'TikTok',
          emoji: '🎵',
          color: const Color(0xFF111111),
          link: _link('tiktok'),
          captionLabel: 'Bio text',
          caption: 'Book here 👇\n${_link('tiktok')}',
          actionLabel: 'Open TikTok',
          actionUrlBuilder: (_) => 'https://www.tiktok.com',
          hint: 'TikTok has no pre-filled links — copy the bio text, then '
              'paste it in Edit Profile → Website.',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.sageLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Pro tip: the ?source= tag on each link lets you see where your '
            'bookings come from in the Appointments dashboard.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.sageDark),
          ),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.name,
    required this.emoji,
    required this.color,
    required this.link,
    required this.captionLabel,
    required this.caption,
    this.actionLabel,
    this.actionUrlBuilder,
    this.hint,
  });

  final String name;
  final String emoji;
  final Color color;
  final String link;
  final String captionLabel;
  final String caption;
  final String? actionLabel;
  final String Function(String caption)? actionUrlBuilder;
  final String? hint;

  Future<void> _copy(BuildContext context, String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showAppSnackBar(context, message: '$what copied');
  }

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      showAppSnackBar(context, message: "Couldn't open the app", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.parchment),
                        ),
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _copy(context, link, 'Link'),
                      child: const Text('Copy'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  captionLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.muted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.parchment),
                  ),
                  child: Text(caption, style: const TextStyle(fontSize: 13)),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    hint!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (actionLabel != null && actionUrlBuilder != null) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _open(context, actionUrlBuilder!(caption)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copy(context, caption, captionLabel),
                        child: Text('Copy ${captionLabel.toLowerCase()}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
