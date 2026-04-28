import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';

class SecurityAlertScreen extends StatelessWidget {
  final String? snapshotPath;
  final String? timestamp;
  final String? classification;
  final String? residentName;

  const SecurityAlertScreen({
    super.key,
    this.snapshotPath,
    this.timestamp,
    this.classification,
    this.residentName,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;

    final isResident = classification?.toLowerCase() == 'resident';
    final displayName = isResident
        ? (residentName ?? 'Known Person')
        : 'Unknown Person Detected!';

    final imageUrl = (snapshotPath != null && snapshotPath!.isNotEmpty)
        ? SupabaseConfig.snapshotUrl(snapshotPath!)
        : null;

    final timeStr = timestamp != null
        ? _formatTimestamp(DateTime.tryParse(timestamp!))
        : null;

    final accent = isResident ? tokens.jadeCore : tokens.crimsonCore;

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.close, color: tokens.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isResident ? Icons.check_circle : Icons.directions_walk,
                color: accent,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isResident ? tokens.textPrimary : tokens.crimsonCore,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isResident
                ? 'A recognized resident was detected by the camera.'
                : 'Camera detected an unidentified person. Motion detected in your home.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
          if (timeStr != null) ...[
            const SizedBox(height: 8),
            Text(
              timeStr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: tokens.bgElevated,
              borderRadius: BorderRadius.circular(24),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported,
                            size: 48, color: tokens.textWhisper),
                        const SizedBox(height: 8),
                        Text('No snapshot available',
                            style: TextStyle(color: tokens.textMuted)),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          if (!isResident) ...[
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Authorities Contacted!')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.crimsonCore,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'CALL AUTHORITIES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        isResident ? 'Dismissed' : 'Marked as False Alarm')),
              );
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 20),
              side: BorderSide(color: tokens.borderMedium, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isResident ? 'DISMISS' : 'FALSE ALARM',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
