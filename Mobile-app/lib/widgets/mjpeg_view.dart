import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Lightweight MJPEG viewer.
///
/// MJPEG streams are typically served as a multipart/x-mixed-replace
/// HTTP response. The simplest cross-platform approach is to fetch
/// snapshots on a fast cadence and swap them in via `Image.network`.
/// This trades a bit of bandwidth for portability (no native plugin
/// needed) and works for Motion / mjpg-streamer / Frigate stills.
///
/// For low-latency, configure a compact JPEG endpoint and a 100–150ms
/// refresh interval.
class MjpegView extends StatefulWidget {
  final String url;
  final Duration refreshInterval;
  final BoxFit fit;

  const MjpegView({
    super.key,
    required this.url,
    this.refreshInterval = const Duration(milliseconds: 120),
    this.fit = BoxFit.cover,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Timer? _timer;
  int _bust = 0;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted) return;
      setState(() => _bust = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _liveUrl {
    final sep = widget.url.contains('?') ? '&' : '?';
    return '${widget.url}${sep}_t=$_bust';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_hadError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_connected_no_internet_4,
                size: 36, color: tokens.crimsonCore.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            const Text(
              'Live stream unreachable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Image.network(
      _liveUrl,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hadError = true);
        });
        return const SizedBox.shrink();
      },
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return child;
      },
    );
  }
}
