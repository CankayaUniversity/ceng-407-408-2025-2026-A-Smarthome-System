import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/face_capture.dart';
import 'providers/supabase_data_provider.dart';
import 'security_alert_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<SupabaseDataProvider>();
    final cameraEvents = data.cameraEvents;
    final latestEvent = data.latestCameraEvent;

    final latestCapture =
        latestEvent != null ? FaceCapture.fromCameraEvent(latestEvent) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.fetchCameraEvents(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Camera Events',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a1a2e))),
                      const SizedBox(height: 4),
                      Text('${cameraEvents.length} events captured',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Latest event card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildLatestCard(context, latestCapture),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('EVENT HISTORY',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
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
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No camera events yet',
                            style: TextStyle(color: Colors.grey.shade500)),
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
                        return _buildEventCard(context, capture);
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

  Widget _buildLatestCard(BuildContext context, FaceCapture? capture) {
    final imageUrl = capture?.imageUrl;
    final hasImage = imageUrl != null;

    return GestureDetector(
      onTap: capture != null
          ? () => _showDetail(context, capture)
          : null,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF111418),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
          image: hasImage
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3), BlendMode.darken),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (!hasImage)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E1C21),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.videocam_off_outlined,
                          color: Color(0xFFFF4757), size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text('No Recent Capture',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (capture != null)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: capture.isResident
                        ? const Color(0xFF00E5A0).withOpacity(0.9)
                        : const Color(0xFFFF4757).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    capture.displayName.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            if (capture != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    'LATEST  ·  ${DateFormat('MMM dd, HH:mm').format(capture.capturedAt)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, FaceCapture capture) {
    final imageUrl = capture.imageUrl;

    return GestureDetector(
      onTap: () => _showDetail(context, capture),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade200,
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null
                  ? const Icon(Icons.person, color: Colors.grey, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(capture.displayName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy  HH:mm')
                        .format(capture.capturedAt),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: capture.isResident
                    ? const Color(0xFF00E5A0).withOpacity(0.12)
                    : const Color(0xFFFF4757).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                capture.isResident ? 'Resident' : 'Unknown',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: capture.isResident
                      ? const Color(0xFF00E5A0)
                      : const Color(0xFFFF4757),
                ),
              ),
            ),
          ],
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
}
