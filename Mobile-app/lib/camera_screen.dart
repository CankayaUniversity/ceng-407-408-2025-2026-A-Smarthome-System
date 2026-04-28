import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'config/supabase_config.dart';
import 'models/face_capture.dart';
import 'providers/supabase_data_provider.dart';
import 'security_alert_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/mjpeg_view.dart';
import 'widgets/hls_player.dart';

enum FeedMode { live, snapshot }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  FeedMode _mode = FeedMode.snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final data = context.watch<SupabaseDataProvider>();
    final cameraEvents = data.cameraEvents;
    final latestEvent = data.latestCameraEvent;

    final latestCapture =
        latestEvent != null ? FaceCapture.fromCameraEvent(latestEvent) : null;
    final hasLiveStream = SupabaseConfig.cameraStreamUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.fetchCameraEvents(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Surveillance',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${cameraEvents.length} events captured',
                                style: TextStyle(
                                    fontSize: 13, color: tokens.textMuted)),
                          ],
                        ),
                      ),
                      _FeedModeSwitch(
                        mode: _mode,
                        liveEnabled: true,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _FeedCard(
                    mode: _mode,
                    capture: latestCapture,
                    hasLiveStream: hasLiveStream,
                    onTapSnapshot: latestCapture != null
                        ? () => _showDetail(context, latestCapture)
                        : null,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('RECENT DETECTIONS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textSecondary,
                          letterSpacing: 1.2)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (data.loading && cameraEvents.isEmpty)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (cameraEvents.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off,
                            size: 56, color: tokens.textWhisper),
                        const SizedBox(height: 12),
                        Text('No camera events yet',
                            style: TextStyle(color: tokens.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final capture =
                            FaceCapture.fromCameraEvent(cameraEvents[i]);
                        return _EventCard(
                          capture: capture,
                          onTap: () => _showDetail(context, capture),
                          onLongPress: () =>
                              _showHoverPreview(context, capture),
                        );
                      },
                      childCount: cameraEvents.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, FaceCapture capture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecurityAlertScreen(
        snapshotPath: capture.snapshotPath ?? capture.imagePath,
        classification: capture.classification,
        residentName: capture.residentName,
        timestamp: capture.capturedAt.toIso8601String(),
      ),
    );
  }

  void _showHoverPreview(BuildContext context, FaceCapture capture) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _HoverPreviewSheet(capture: capture),
    );
  }
}

// ─── Feed Mode Switch (Live | Snapshot) ──────────────────────

class _FeedModeSwitch extends StatelessWidget {
  final FeedMode mode;
  final bool liveEnabled;
  final ValueChanged<FeedMode> onChanged;

  const _FeedModeSwitch({
    required this.mode,
    required this.liveEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgBase,
        border: Border.all(color: tokens.borderSoft),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, FeedMode.live, Icons.podcasts, 'Live'),
          Container(
            width: 1,
            height: 18,
            color: tokens.borderSoft,
          ),
          _segment(context, FeedMode.snapshot, Icons.photo_camera, 'Snap'),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, FeedMode m, IconData icon, String label) {
    final tokens = context.tokens;
    final active = mode == m;
    return InkWell(
      onTap: () => onChanged(m),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.emberCore : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active ? Colors.white : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : tokens.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feed Card (snapshot or live) ────────────────────────────

class _FeedCard extends StatelessWidget {
  final FeedMode mode;
  final FaceCapture? capture;
  final bool hasLiveStream;
  final VoidCallback? onTapSnapshot;

  const _FeedCard({
    required this.mode,
    required this.capture,
    required this.hasLiveStream,
    required this.onTapSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = capture?.imageUrl;

    return GestureDetector(
      onTap: mode == FeedMode.snapshot ? onTapSnapshot : null,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C10),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (mode == FeedMode.live)
                _liveContent(tokens)
              else
                _snapshotContent(tokens, imageUrl),

              // Top-left mode pill
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: mode == FeedMode.live
                        ? tokens.crimsonCore.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        mode == FeedMode.live ? 'LIVE' : 'SNAPSHOT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (mode == FeedMode.snapshot && capture != null) ...[
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: capture!.isResident
                          ? tokens.jadeCore.withValues(alpha: 0.9)
                          : tokens.crimsonCore.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      capture!.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(14, 32, 14, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      'LATEST · ${DateFormat('MMM dd, HH:mm').format(capture!.capturedAt)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapshotContent(AppTokens tokens, String? imageUrl) {
    if (imageUrl == null) {
      return _empty(tokens, Icons.videocam_off_outlined,
          'No Recent Capture', 'Snapshots will appear once camera fires');
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _empty(tokens, Icons.broken_image,
          'Snapshot unavailable', 'Could not load the image'),
    );
  }

  Widget _liveContent(AppTokens tokens) {
    if (!hasLiveStream) {
      return _empty(
        tokens,
        Icons.signal_wifi_off,
        'No live stream configured',
        'Build with --dart-define=CAMERA_STREAM_URL=...',
      );
    }
    if (SupabaseConfig.cameraStreamType.toLowerCase() == 'hls') {
      return HlsPlayer(url: SupabaseConfig.cameraStreamUrl);
    }
    return MjpegView(url: SupabaseConfig.cameraStreamUrl);
  }

  Widget _empty(
      AppTokens tokens, IconData icon, String title, String desc) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.bgElevated, tokens.bgBase],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 32, color: Colors.white.withValues(alpha: 0.55)),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Event card (recent detection row) ───────────────────────

class _EventCard extends StatelessWidget {
  final FaceCapture capture;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EventCard({
    required this.capture,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = capture.imageUrl;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: tokens.bgRaised,
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null
                  ? Icon(Icons.person, color: tokens.textWhisper, size: 26)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capture.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM dd, yyyy · HH:mm')
                        .format(capture.capturedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: capture.isResident
                    ? tokens.jadeCore.withValues(alpha: 0.12)
                    : tokens.crimsonCore.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                capture.isResident ? 'Resident' : 'Unknown',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: capture.isResident
                      ? tokens.jadeCore
                      : tokens.crimsonCore,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hover Preview Bottom Sheet ──────────────────────────────

class _HoverPreviewSheet extends StatelessWidget {
  final FaceCapture capture;
  const _HoverPreviewSheet({required this.capture});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = capture.imageUrl;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 240,
            height: 180,
            decoration: BoxDecoration(
              color: tokens.bgRaised,
              borderRadius: BorderRadius.circular(14),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl == null
                ? Center(
                    child: Icon(Icons.image_not_supported,
                        color: tokens.textWhisper, size: 36),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capture.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM dd, yyyy · HH:mm')
                          .format(capture.capturedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: capture.isResident
                      ? tokens.jadeCore.withValues(alpha: 0.15)
                      : tokens.crimsonCore.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  capture.isResident ? 'RESIDENT' : 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: capture.isResident
                        ? tokens.jadeCore
                        : tokens.crimsonCore,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
