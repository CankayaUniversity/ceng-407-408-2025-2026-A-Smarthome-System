import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../providers/auth_provider.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';

/// Mobile parity for `website/client/src/pages/IdentityPage.jsx`.
///
/// Admin-only review surface for unknown face clusters. Sections:
///   - Recent manual corrections (`face_label_actions`) + Revert.
///   - Resident linked detections + "Not this person" (unlink RPC).
///   - Review queue (`event_faces` with `match_score` in (0.45, 0.65)).
///   - Tabbed: Unknown visitors (profiles) / Recent unknown detections.
///   - Assign modal (resident picker + replace-enrollment checkbox).
class IdentityReviewScreen extends StatefulWidget {
  const IdentityReviewScreen({super.key});

  @override
  State<IdentityReviewScreen> createState() => _IdentityReviewScreenState();
}

class _AssignSheetResult {
  final String residentId;
  final bool useEnrollment;
  const _AssignSheetResult({
    required this.residentId,
    required this.useEnrollment,
  });
}

class _IdentityReviewScreenState extends State<IdentityReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  bool _refreshing = false;
  String? _loadError;

  List<Map<String, dynamic>> _profiles = const [];
  List<Map<String, dynamic>> _recentUnknowns = const [];
  List<Map<String, dynamic>> _residents = const [];
  List<Map<String, dynamic>> _recentActions = const [];

  String? _selectedProfileId;
  List<Map<String, dynamic>> _sightings = const [];
  bool _sightingsLoading = false;

  String? _galleryResidentId;
  List<Map<String, dynamic>> _residentDetections = const [];
  bool _galleryLoading = false;

  String? _busyActionId;
  String? _busyUnlinkId;
  String? _busyProfileAction;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _loadAll();
    } catch (e) {
      _loadError = _friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      IdentityService.fetchUnknownProfiles(),
      IdentityService.fetchRecentUnknownFaces(),
      IdentityService.fetchResidentPickerList(),
      IdentityService.fetchRecentActions(),
    ]);
    if (!mounted) return;
    setState(() {
      _profiles = results[0];
      _recentUnknowns = results[1];
      _residents = results[2];
      _recentActions = results[3];
      _loadError = null;
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await _loadAll();
      if (_selectedProfileId != null) {
        await _loadSightings(_selectedProfileId!);
      }
      if (_galleryResidentId != null) {
        await _loadResidentDetections(_galleryResidentId!);
      }
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadSightings(String profileId) async {
    setState(() => _sightingsLoading = true);
    try {
      final data = await IdentityService.fetchProfileSightings(profileId);
      if (!mounted) return;
      setState(() {
        _sightings = data;
      });
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _sightingsLoading = false);
    }
  }

  Future<void> _loadResidentDetections(String residentId) async {
    setState(() => _galleryLoading = true);
    try {
      final data = await IdentityService.fetchResidentDetections(residentId);
      if (!mounted) return;
      setState(() {
        _residentDetections = data;
      });
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('row-level security') ||
        lower.contains('rls') ||
        lower.contains('permission denied') ||
        lower.contains('only admins')) {
      return 'Admin-only action: your account cannot perform this change.';
    }
    return msg.replaceFirst('Exception: ', '');
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    final tokens = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? tokens.crimsonCore : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _residentName(String? residentId) {
    if (residentId == null) return 'resident';
    for (final r in _residents) {
      if (r['id']?.toString() == residentId) {
        final n = r['name']?.toString();
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return 'resident';
  }

  /// Snapshot path from an action row; prefers metadata then nested join.
  String? _actionSnapshotPath(Map<String, dynamic> action) {
    final meta = action['metadata'];
    if (meta is Map) {
      final v = meta['snapshot_path']?.toString();
      if (v != null && v.isNotEmpty) return v;
      final targetProfileId = meta['target_profile_id']?.toString();
      if (targetProfileId != null && targetProfileId.isNotEmpty) {
        final p = _profiles.firstWhere(
          (p) => p['id']?.toString() == targetProfileId,
          orElse: () => const <String, dynamic>{},
        );
        final snap = p['representative_snapshot_path']?.toString();
        if (snap != null && snap.isNotEmpty) return snap;
      }
    }
    final fromProfile = action['from_profile'];
    if (fromProfile is Map) {
      final v = fromProfile['representative_snapshot_path']?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    final toResident = action['to_resident'];
    if (toResident is Map) {
      final v = toResident['photo_path']?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    final ef = action['event_faces'];
    if (ef is Map) {
      final ce = ef['camera_events'];
      if (ce is Map) {
        return ce['snapshot_path']?.toString();
      }
    }
    return null;
  }

  String _actionLabel(Map<String, dynamic> action) {
    final type = action['action']?.toString();
    if (type == 'assign_resident') {
      return 'Assigned -> ${_residentName(action['to_resident_id']?.toString())}';
    }
    if (type == 'revert_assign') return 'Reverted assign';
    if (type == 'unlink_from_resident') {
      return 'Unlinked from ${_residentName(action['to_resident_id']?.toString())}';
    }
    if (type == 'merge_profiles') return 'Merged visitor profiles';
    if (type == 'rename_profile') return 'Renamed visitor';
    if (type == 'move_sighting') return 'Moved / ungrouped photo';
    if (type == 'dismiss_profile') return 'Dismissed visitor profile';
    return type ?? '';
  }

  // ── RPC handlers ─────────────────────────────────────────────────────

  /// Reload lists after assign. Call only after assign sheet is fully closed.
  /// parent [setState] does not run while the sheet route is still mounted.
  Future<void> _afterAssignSuccess({
    required String residentId,
    required bool useEnrollment,
  }) async {
    if (!mounted) return;
    final name = _residentName(residentId);
    _toast(
      useEnrollment
          ? 'Linked to $name and updated enrollment photo.'
          : 'Linked to $name. Enrollment photo unchanged.',
    );
    await _loadAll();
    if (!mounted) return;
    if (_selectedProfileId != null) {
      await _loadSightings(_selectedProfileId!);
    }
    if (!mounted) return;
    if (_galleryResidentId == residentId) {
      await _loadResidentDetections(residentId);
    }
  }

  Future<void> _handleRenameProfile(Map<String, dynamic> profile) async {
    final tokens = context.tokens;
    final id = profile['id']?.toString();
    if (id == null || id.isEmpty) return;
    final ctrl = TextEditingController(
      text: profile['display_label']?.toString() ?? '',
    );
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.bgSurface,
        title: const Text('Rename visitor'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (label == null || label.isEmpty) return;

    setState(() => _busyProfileAction = 'rename:$id');
    try {
      final res = await IdentityService.renameUnknownFaceProfile(
        profileId: id,
        displayLabel: label,
      );
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Rename failed');
      }
      _toast('Visitor nickname updated.');
      await _refresh();
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyProfileAction = null);
    }
  }

  Future<void> _handleMergeProfile(Map<String, dynamic> profile) async {
    final id = profile['id']?.toString();
    if (id == null || id.isEmpty) return;
    final targetId = await _pickUnknownProfile(
      title: 'Merge into visitor',
      excludeProfileId: id,
    );
    if (targetId == null) return;

    setState(() => _busyProfileAction = 'merge:$id');
    try {
      final res = await IdentityService.mergeUnknownFaceProfiles(
        sourceProfileId: id,
        targetProfileId: targetId,
      );
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Merge failed');
      }
      _toast('Profiles merged.');
      setState(() => _selectedProfileId = targetId);
      await _refresh();
      await _loadSightings(targetId);
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyProfileAction = null);
    }
  }

  Future<void> _handleDismissProfile(Map<String, dynamic> profile) async {
    final id = profile['id']?.toString();
    if (id == null || id.isEmpty) return;
    final label = profile['display_label']?.toString() ?? 'this visitor';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss visitor?'),
        content: Text('Dismiss "$label"? Sightings will be ungrouped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busyProfileAction = 'dismiss:$id');
    try {
      final res = await IdentityService.dismissUnknownFaceProfile(id);
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Dismiss failed');
      }
      _toast('Profile dismissed.');
      setState(() {
        _selectedProfileId = null;
        _sightings = const [];
      });
      await _refresh();
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyProfileAction = null);
    }
  }

  Future<void> _handleMoveSighting(String eventFaceId, String profileId) async {
    final targetId = await _pickUnknownProfile(
      title: 'Move photo to visitor',
      excludeProfileId: profileId,
    );
    if (targetId == null) return;
    setState(() => _busyProfileAction = 'move:$eventFaceId');
    try {
      final res = await IdentityService.moveEventFaceToUnknownProfile(
        eventFaceId: eventFaceId,
        targetProfileId: targetId,
      );
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Move failed');
      }
      _toast('Photo moved to selected visitor.');
      await _refresh();
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyProfileAction = null);
    }
  }

  Future<void> _handleUngroupSighting(
    String eventFaceId,
    String profileId,
  ) async {
    if (profileId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = ctx.tokens;
        return AlertDialog(
          backgroundColor: tokens.bgSurface,
          title: const Text('Ungroup photo?'),
          content: const Text(
            'This photo will be removed from the current visitor group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Ungroup',
                style: TextStyle(color: tokens.crimsonCore),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _busyProfileAction = 'ungroup:$eventFaceId');
    try {
      final res = await IdentityService.ungroupEventFace(eventFaceId);
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Ungroup failed');
      }
      _toast('Removed from this visitor group.');
      await _refresh();
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyProfileAction = null);
    }
  }

  Future<String?> _pickUnknownProfile({
    required String title,
    required String excludeProfileId,
  }) async {
    final candidates = _profiles
        .where((p) => p['id']?.toString() != excludeProfileId)
        .toList();
    if (candidates.isEmpty) {
      _toast('No other visitor profiles available.', isError: true);
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tokens = ctx.tokens;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.bgSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final p in candidates)
                ListTile(
                  leading: _SnapshotThumb(
                    path: p['representative_snapshot_path']?.toString(),
                    size: 44,
                  ),
                  title: Text(
                    p['display_label']?.toString() ?? 'Visitor',
                    style: TextStyle(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    '${p['sighting_count'] ?? 0} sighting(s)',
                    style: TextStyle(color: tokens.textMuted),
                  ),
                  onTap: () => Navigator.pop(ctx, p['id']?.toString()),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAssignModalFromSighting(
    Map<String, dynamic> sighting,
  ) async {
    final eventFace = sighting['event_faces'] is Map
        ? sighting['event_faces'] as Map
        : null;
    final eventFaceId = eventFace?['id']?.toString();
    if (eventFaceId == null || eventFaceId.isEmpty) return;
    await _openAssignModal({
      'id': eventFaceId,
      'camera_events': sighting['camera_events'],
      'match_score': eventFace?['match_score'],
      'classification': eventFace?['classification'] ?? 'unknown',
    });
  }

  Future<void> _handleRevert(String actionId) async {
    setState(() => _busyActionId = actionId);
    try {
      final res = await IdentityService.revertFaceLabelAction(actionId);
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Revert failed');
      }
      _toast('Assignment reverted. Detection is unknown again.');
      await _loadAll();
      if (_galleryResidentId != null) {
        await _loadResidentDetections(_galleryResidentId!);
      }
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyActionId = null);
    }
  }

  Future<void> _handleUnlink(String eventFaceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = ctx.tokens;
        return AlertDialog(
          backgroundColor: tokens.bgSurface,
          title: const Text('Mark detection as unknown?'),
          content: const Text(
            'The resident enrollment photo will not change. The detection will reappear in the unknown queue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Unlink',
                style: TextStyle(color: tokens.crimsonCore),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _busyUnlinkId = eventFaceId);
    try {
      final res = await IdentityService.unlinkEventFaceFromResident(
        eventFaceId,
      );
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Unlink failed');
      }
      _toast('Detection unlinked from resident.');
      await _loadAll();
      if (_galleryResidentId != null) {
        await _loadResidentDetections(_galleryResidentId!);
      }
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busyUnlinkId = null);
    }
  }

  // ── Assign modal ─────────────────────────────────────────────────────

  Future<void> _openAssignModal(Map<String, dynamic> face) async {
    if (_residents.isEmpty) {
      _toast('No residents available to assign.', isError: true);
      return;
    }

    final result = await showModalBottomSheet<_AssignSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignResidentSheet(
        face: face,
        residents: _residents,
        friendlyError: _friendlyError,
      ),
    );

    if (!mounted || result == null) return;
    await _afterAssignSuccess(
      residentId: result.residentId,
      useEnrollment: result.useEnrollment,
    );
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.bgVoid,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final revertedActionIds = IdentityService.deriveRevertedActionIds(
      _recentActions,
    );
    final reviewQueue = _recentUnknowns.where((f) {
      final v = f['match_score'];
      final score = v is num ? v.toDouble() : null;
      return score != null && score > 0.45 && score < 0.65;
    }).toList();

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      body: SafeArea(
        child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Identity Review',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Resolve unknown visitors, revert mistakes, manage labels.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refreshing ? null : _refresh,
                            icon: _refreshing
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: tokens.emberCore,
                                    ),
                                  )
                                : Icon(Icons.refresh, color: tokens.emberCore),
                          ),
                        ],
                      ),
                      if (!isAdmin) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: tokens.amberCore,
                          icon: Icons.visibility,
                          title: 'Read-only mode',
                          subtitle:
                              'You can inspect identity activity, but only admins can edit labels or run actions.',
                        ),
                      ],
                      if (_loadError != null) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: tokens.crimsonCore,
                          icon: Icons.error_outline,
                          title: 'Could not load identity data',
                          subtitle: _loadError!,
                          trailing: TextButton(
                            onPressed: _bootstrap,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),



                      _RecentCorrectionsCard(
                        actions: _recentActions,
                        residents: _residents,
                        revertedActionIds: revertedActionIds,
                        busyActionId: _busyActionId,
                        isAdmin: isAdmin,
                        snapshotOf: _actionSnapshotPath,
                        labelOf: _actionLabel,
                        onRevert: _handleRevert,
                      ),
                      const SizedBox(height: 16),

                      _ResidentGalleryCard(
                        residents: _residents,
                        selectedResidentId: _galleryResidentId,
                        detections: _residentDetections,
                        loading: _galleryLoading,
                        busyUnlinkId: _busyUnlinkId,
                        isAdmin: isAdmin,
                        onResidentSelected: (id) async {
                          setState(() {
                            _galleryResidentId = id;
                            _residentDetections = const [];
                          });
                          if (id != null) {
                            await _loadResidentDetections(id);
                          }
                        },
                        onUnlink: _handleUnlink,
                      ),
                      const SizedBox(height: 16),

                      if (reviewQueue.isNotEmpty)
                        _ReviewQueueStrip(
                          faces: reviewQueue,
                          isAdmin: isAdmin,
                          onAssign: _openAssignModal,
                        ),
                      if (reviewQueue.isNotEmpty) const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabsDelegate(
                  child: Container(
                    color: tokens.bgVoid,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: tokens.emberCore,
                      unselectedLabelColor: tokens.textMuted,
                      indicatorColor: tokens.emberCore,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: [
                        Tab(text: 'Visitors (${_profiles.length})'),
                        Tab(text: 'Recent (${_recentUnknowns.length})'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _ProfilesTab(
                  profiles: _profiles,
                  selectedProfileId: _selectedProfileId,
                  isAdmin: isAdmin,
                  sightings: _sightings,
                  sightingsLoading: _sightingsLoading,
                  busyProfileAction: _busyProfileAction,
                  onRename: _handleRenameProfile,
                  onMerge: _handleMergeProfile,
                  onDismiss: _handleDismissProfile,
                  onMoveSighting: _handleMoveSighting,
                  onUngroupSighting: _handleUngroupSighting,
                  onAssignSighting: _openAssignModalFromSighting,
                  onSelect: (id) async {
                    setState(() {
                      _selectedProfileId = id;
                      _sightings = const [];
                    });
                    if (id != null) await _loadSightings(id);
                  },
                ),
                _RecentUnknownsTab(
                  faces: _recentUnknowns,
                  isAdmin: isAdmin,
                  onAssign: _openAssignModal,
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Assign bottom sheet (isolated from parent setState during RPC)
// ─────────────────────────────────────────────────────────────────────

class _AssignResidentSheet extends StatefulWidget {
  final Map<String, dynamic> face;
  final List<Map<String, dynamic>> residents;
  final String Function(Object error) friendlyError;

  const _AssignResidentSheet({
    required this.face,
    required this.residents,
    required this.friendlyError,
  });

  @override
  State<_AssignResidentSheet> createState() => _AssignResidentSheetState();
}

class _AssignResidentSheetState extends State<_AssignResidentSheet> {
  String? _residentId;
  bool _useEnrollment = false;
  bool _saving = false;
  String? _error;
  String _search = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final pickedId = _residentId;
    if (pickedId == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final eventFaceId = widget.face['id']?.toString();
      if (eventFaceId == null || eventFaceId.isEmpty) {
        throw Exception('Missing detection id');
      }
      final res = await IdentityService.assignEventFaceToResident(
        eventFaceId: eventFaceId,
        residentId: pickedId,
        useSnapshotForEnrollment: _useEnrollment,
      );
      if (res['success'] == false) {
        throw Exception(res['error']?.toString() ?? 'Assignment failed');
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _AssignSheetResult(
          residentId: pickedId,
          useEnrollment: _useEnrollment,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final filtered = _search.trim().isEmpty
        ? widget.residents
        : widget.residents
              .where(
                (r) => (r['name']?.toString() ?? '')
                    .toLowerCase()
                    .contains(_search.toLowerCase()),
              )
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: tokens.emberCore, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assign to resident',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _AssignTargetPreview(face: widget.face),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                enabled: !_saving,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search residents',
                  hintStyle: TextStyle(color: tokens.textWhisper, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.bgRaised,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.emberCore, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No residents match "$_search"',
                          style: TextStyle(color: tokens.textMuted, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final id = r['id']?.toString();
                          final selected = id == _residentId;
                          return InkWell(
                            onTap: _saving
                                ? null
                                : () => setState(() => _residentId = id),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? tokens.emberCore.withValues(alpha: 0.13)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? tokens.emberCore.withValues(alpha: 0.5)
                                      : tokens.borderSoft,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _ResidentAvatar(resident: r),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r['name']?.toString() ?? 'Resident',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle,
                                      color: tokens.emberCore,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _useEnrollment,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _useEnrollment = v ?? false),
                    activeColor: tokens.emberCore,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(() => _useEnrollment = !_useEnrollment),
                      child: Text(
                        'Replace enrollment photo with this snapshot',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.crimsonCore.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.crimsonCore.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: tokens.crimsonCore, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving || _residentId == null ? null : _confirm,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.emberCore,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _CardShell({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.emberCore.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tokens.emberCore, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SnapshotThumb extends StatelessWidget {
  final String? path;
  final double size;
  /// When true, fills the parent (e.g. [Expanded] in a grid cell).
  final bool fill;
  const _SnapshotThumb({
    required this.path,
    this.size = 56,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final url = (path != null && path!.isNotEmpty)
        ? SupabaseConfig.snapshotUrl(path!)
        : null;
    final decoration = BoxDecoration(
      color: tokens.bgRaised,
      borderRadius: BorderRadius.circular(10),
      image: url != null
          ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
          : null,
      border: Border.all(color: tokens.borderSoft),
    );
    if (fill) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: decoration,
          child: url == null
              ? Icon(
                  Icons.image_not_supported,
                  color: tokens.textWhisper,
                  size: 28,
                )
              : null,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: url == null
          ? Icon(
              Icons.image_not_supported,
              color: tokens.textWhisper,
              size: size * 0.4,
            )
          : null,
    );
  }
}

class _ResidentAvatar extends StatelessWidget {
  final Map<String, dynamic> resident;
  const _ResidentAvatar({required this.resident});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final path = resident['photo_path']?.toString();
    final url = (path != null && path.isNotEmpty)
        ? SupabaseConfig.snapshotUrl(path)
        : null;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: tokens.emberCore.withValues(alpha: 0.1),
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null
          ? Center(
              child: Text(
                ((resident['name']?.toString() ?? '?').isNotEmpty
                        ? resident['name'].toString()[0]
                        : '?')
                    .toUpperCase(),
                style: TextStyle(
                  color: tokens.emberCore,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            )
          : null,
    );
  }
}

class _AssignTargetPreview extends StatelessWidget {
  final Map<String, dynamic> face;
  const _AssignTargetPreview({required this.face});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cameraEvent = face['camera_events'] is Map
        ? face['camera_events']
        : null;
    final snapshotPath = cameraEvent != null
        ? cameraEvent['snapshot_path']?.toString()
        : null;
    final createdRaw = cameraEvent != null
        ? cameraEvent['created_at']?.toString()
        : null;
    final created = DateTime.tryParse(createdRaw ?? '');
    final score = face['match_score'];
    final scoreStr = score is num ? score.toStringAsFixed(2) : '—';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.bgRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Row(
        children: [
          _SnapshotThumb(path: snapshotPath, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unknown detection',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MetaPill(
                      icon: Icons.score,
                      label: 'score $scoreStr',
                      color: tokens.amberCore,
                    ),
                    if (created != null)
                      _MetaPill(
                        icon: Icons.access_time,
                        label: DateFormat('MMM d HH:mm').format(created),
                        color: tokens.cyanCore,
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

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section cards
// ─────────────────────────────────────────────────────────────────────



class _RecentCorrectionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> residents;
  final Set<String> revertedActionIds;
  final String? busyActionId;
  final bool isAdmin;
  final String? Function(Map<String, dynamic>) snapshotOf;
  final String Function(Map<String, dynamic>) labelOf;
  final Future<void> Function(String) onRevert;

  const _RecentCorrectionsCard({
    required this.actions,
    required this.residents,
    required this.revertedActionIds,
    required this.busyActionId,
    required this.isAdmin,
    required this.snapshotOf,
    required this.labelOf,
    required this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final visible = actions.take(8).toList();
    return _CardShell(
      icon: Icons.history,
      title: 'Recent corrections',
      subtitle: 'Assign / revert / unlink / labels - newest first',
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No manual corrections yet.',
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            )
          : Column(
              children: [
                for (final a in visible)
                  _RecentCorrectionRow(
                    action: a,
                    revertedActionIds: revertedActionIds,
                    busy: busyActionId == a['id']?.toString(),
                    isAdmin: isAdmin,
                    snapshotPath: snapshotOf(a),
                    label: labelOf(a),
                    onRevert: onRevert,
                  ),
              ],
            ),
    );
  }
}

class _RecentCorrectionRow extends StatelessWidget {
  final Map<String, dynamic> action;
  final Set<String> revertedActionIds;
  final bool busy;
  final bool isAdmin;
  final String? snapshotPath;
  final String label;
  final Future<void> Function(String) onRevert;

  const _RecentCorrectionRow({
    required this.action,
    required this.revertedActionIds,
    required this.busy,
    required this.isAdmin,
    required this.snapshotPath,
    required this.label,
    required this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final id = action['id']?.toString() ?? '';
    final type = action['action']?.toString();
    final created = DateTime.tryParse(action['created_at']?.toString() ?? '');
    final reverted = revertedActionIds.contains(id);
    final meta = action['metadata'];
    final enrollmentUpdated = meta is Map && meta['enrollment_updated'] == true;

    final canRevert = type == 'assign_resident' && !reverted && isAdmin;

    return Opacity(
      opacity: reverted ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SnapshotThumb(path: snapshotPath, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (created != null)
                    Text(
                      DateFormat('MMM d, HH:mm').format(created),
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  if (enrollmentUpdated)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Enrollment photo updated',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.amberCore,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (reverted)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Reverted',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canRevert)
              TextButton.icon(
                onPressed: busy ? null : () => onRevert(id),
                icon: busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.undo, size: 14, color: tokens.crimsonCore),
                label: Text(
                  'Revert',
                  style: TextStyle(
                    color: tokens.crimsonCore,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResidentGalleryCard extends StatelessWidget {
  final List<Map<String, dynamic>> residents;
  final String? selectedResidentId;
  final List<Map<String, dynamic>> detections;
  final bool loading;
  final String? busyUnlinkId;
  final bool isAdmin;
  final void Function(String?) onResidentSelected;
  final Future<void> Function(String) onUnlink;

  const _ResidentGalleryCard({
    required this.residents,
    required this.selectedResidentId,
    required this.detections,
    required this.loading,
    required this.busyUnlinkId,
    required this.isAdmin,
    required this.onResidentSelected,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _CardShell(
      icon: Icons.group,
      title: 'Resident linked detections',
      subtitle:
          'Inspect what is currently classified as each resident — unlink false positives.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tokens.bgRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSoft),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                hint: Text(
                  'Select a resident',
                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
                ),
                value: selectedResidentId,
                dropdownColor: tokens.bgSurface,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      '— Select resident —',
                      style: TextStyle(color: tokens.textMuted),
                    ),
                  ),
                  for (final r in residents)
                    DropdownMenuItem<String?>(
                      value: r['id']?.toString(),
                      child: Text(
                        r['name']?.toString() ?? 'Resident',
                        style: TextStyle(color: tokens.textPrimary),
                      ),
                    ),
                ],
                onChanged: onResidentSelected,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (selectedResidentId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Pick a resident to view their linked detections.',
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            )
          else if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (detections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No detections currently linked to this resident.',
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                // Room for thumbnail + timestamp + outlined unlink button.
                childAspectRatio: 0.62,
              ),
              itemCount: detections.length,
              itemBuilder: (_, i) {
                final face = detections[i];
                final id = face['id']?.toString() ?? '';
                final ce = face['camera_events'];
                final snapshotPath = ce is Map
                    ? ce['snapshot_path']?.toString()
                    : null;
                final createdRaw = ce is Map
                    ? ce['created_at']?.toString()
                    : null;
                final created = DateTime.tryParse(createdRaw ?? '');
                final busy = busyUnlinkId == id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SnapshotThumb(
                        path: snapshotPath,
                        fill: true,
                      ),
                    ),
                    if (created != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d HH:mm').format(created),
                        style: TextStyle(
                          fontSize: 10,
                          color: tokens.textMuted,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: busy ? null : () => onUnlink(id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.crimsonCore,
                            backgroundColor:
                                tokens.crimsonCore.withValues(alpha: 0.1),
                            side: BorderSide(
                              color: tokens.crimsonCore.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          child: busy
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: tokens.crimsonCore,
                                  ),
                                )
                              : const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Not this person'),
                                ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReviewQueueStrip extends StatelessWidget {
  final List<Map<String, dynamic>> faces;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onAssign;

  const _ReviewQueueStrip({
    required this.faces,
    required this.isAdmin,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _CardShell(
      icon: Icons.warning_amber_rounded,
      title: 'Review queue · ${faces.length}',
      subtitle: 'Borderline detections (score 0.45–0.65).',
      child: SizedBox(
        height: 130,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: faces.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final face = faces[i];
            final ce = face['camera_events'];
            final snapshotPath = ce is Map
                ? ce['snapshot_path']?.toString()
                : null;
            final score = face['match_score'];
            final scoreStr = score is num ? score.toStringAsFixed(2) : '—';
            return SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SnapshotThumb(path: snapshotPath, size: 110),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'score $scoreStr',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tokens.amberCore,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isAdmin)
                    SizedBox(
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () => onAssign(face),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.emberCore,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Assign',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────

class _ProfilesTab extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;
  final String? selectedProfileId;
  final bool isAdmin;
  final List<Map<String, dynamic>> sightings;
  final bool sightingsLoading;
  final String? busyProfileAction;
  final Future<void> Function(Map<String, dynamic>) onRename;
  final Future<void> Function(Map<String, dynamic>) onMerge;
  final Future<void> Function(Map<String, dynamic>) onDismiss;
  final Future<void> Function(String eventFaceId, String profileId)
  onMoveSighting;
  final Future<void> Function(String eventFaceId, String profileId)
  onUngroupSighting;
  final Future<void> Function(Map<String, dynamic>) onAssignSighting;
  final void Function(String?) onSelect;

  const _ProfilesTab({
    required this.profiles,
    required this.selectedProfileId,
    required this.isAdmin,
    required this.sightings,
    required this.sightingsLoading,
    required this.busyProfileAction,
    required this.onRename,
    required this.onMerge,
    required this.onDismiss,
    required this.onMoveSighting,
    required this.onUngroupSighting,
    required this.onAssignSighting,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.face_retouching_off,
                size: 48,
                color: tokens.textWhisper,
              ),
              const SizedBox(height: 10),
              Text(
                'No active unknown visitors yet.',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = profiles[i];
        final id = p['id']?.toString();
        final selected = id != null && id == selectedProfileId;
        final label = p['display_label']?.toString() ?? 'Unknown';
        final count = p['sighting_count'];
        final lastSeenRaw = p['last_seen_at']?.toString();
        final lastSeen = DateTime.tryParse(lastSeenRaw ?? '');
        final rep = p['representative_snapshot_path']?.toString();
        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(selected ? null : id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? tokens.emberCore.withValues(alpha: 0.5)
                        : tokens.borderSoft,
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _SnapshotThumb(path: rep, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _MetaPill(
                                icon: Icons.tag,
                                label: '${count ?? 0}x seen',
                                color: tokens.violetCore,
                              ),
                              if (lastSeen != null)
                                _MetaPill(
                                  icon: Icons.schedule,
                                  label: DateFormat(
                                    'MMM d HH:mm',
                                  ).format(lastSeen),
                                  color: tokens.cyanCore,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.expand_less : Icons.expand_more,
                      color: tokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              if (isAdmin) ...[
                _ProfileActionBar(
                  profile: p,
                  hasMergeTarget: profiles.any(
                    (candidate) => candidate['id']?.toString() != id,
                  ),
                  busyAction: busyProfileAction,
                  onRename: onRename,
                  onMerge: onMerge,
                  onDismiss: onDismiss,
                ),
                const SizedBox(height: 6),
              ],
              _SightingsPanel(
                sightings: sightings,
                loading: sightingsLoading,
                isAdmin: isAdmin,
                profileId: id,
                hasMoveTarget: profiles.any(
                  (candidate) => candidate['id']?.toString() != id,
                ),
                busyAction: busyProfileAction,
                onMove: onMoveSighting,
                onUngroup: onUngroupSighting,
                onAssign: onAssignSighting,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileActionBar extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool hasMergeTarget;
  final String? busyAction;
  final Future<void> Function(Map<String, dynamic>) onRename;
  final Future<void> Function(Map<String, dynamic>) onMerge;
  final Future<void> Function(Map<String, dynamic>) onDismiss;

  const _ProfileActionBar({
    required this.profile,
    required this.hasMergeTarget,
    required this.busyAction,
    required this.onRename,
    required this.onMerge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final id = profile['id']?.toString() ?? '';
    final renameBusy = busyAction == 'rename:$id';
    final mergeBusy = busyAction == 'merge:$id';
    final dismissBusy = busyAction == 'dismiss:$id';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.bgRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: renameBusy ? null : () => onRename(profile),
            icon: renameBusy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.emberCore,
                    ),
                  )
                : Icon(Icons.edit, size: 15, color: tokens.emberCore),
            label: const Text('Nickname'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.emberCore,
              side: BorderSide(color: tokens.emberCore.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          OutlinedButton.icon(
            onPressed: hasMergeTarget && !mergeBusy
                ? () => onMerge(profile)
                : null,
            icon: mergeBusy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.emberCore,
                    ),
                  )
                : Icon(Icons.call_merge, size: 15, color: tokens.emberCore),
            label: const Text('Merge'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.emberCore,
              side: BorderSide(color: tokens.emberCore.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          TextButton.icon(
            onPressed: dismissBusy ? null : () => onDismiss(profile),
            icon: dismissBusy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.crimsonCore,
                    ),
                  )
                : Icon(
                    Icons.visibility_off_outlined,
                    size: 15,
                    color: tokens.crimsonCore,
                  ),
            label: Text(
              'Dismiss',
              style: TextStyle(
                color: tokens.crimsonCore,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SightingsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> sightings;
  final bool loading;
  final bool isAdmin;
  final String profileId;
  final bool hasMoveTarget;
  final String? busyAction;
  final Future<void> Function(String eventFaceId, String profileId) onMove;
  final Future<void> Function(String eventFaceId, String profileId) onUngroup;
  final Future<void> Function(Map<String, dynamic>) onAssign;

  const _SightingsPanel({
    required this.sightings,
    required this.loading,
    required this.isAdmin,
    required this.profileId,
    required this.hasMoveTarget,
    required this.busyAction,
    required this.onMove,
    required this.onUngroup,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (sightings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No sightings recorded yet.',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.bgRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.62,
        ),
        itemCount: sightings.length,
        itemBuilder: (_, i) {
          final s = sightings[i];
          final ce = s['camera_events'];
          final path = ce is Map ? ce['snapshot_path']?.toString() : null;
          final eventFace = s['event_faces'] is Map
              ? s['event_faces'] as Map
              : null;
          final eventFaceId = eventFace?['id']?.toString();
          final canAct =
              isAdmin &&
              eventFaceId != null &&
              eventFaceId.isNotEmpty &&
              profileId.isNotEmpty;
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SnapshotThumb(path: path, fill: true)),
                if (canAct) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      _SightingIconButton(
                        tooltip: 'Assign to resident',
                        icon: Icons.person_add_alt_1,
                        color: tokens.emberCore,
                        busy: false,
                        onPressed: () => onAssign(s),
                      ),
                      _SightingIconButton(
                        tooltip: 'Move to another visitor',
                        icon: Icons.drive_file_move_outline,
                        color: tokens.cyanCore,
                        busy: busyAction == 'move:$eventFaceId',
                        onPressed: hasMoveTarget
                            ? () => onMove(eventFaceId, profileId)
                            : null,
                      ),
                      _SightingIconButton(
                        tooltip: 'Ungroup from visitor',
                        icon: Icons.link_off,
                        color: tokens.crimsonCore,
                        busy: busyAction == 'ungroup:$eventFaceId',
                        onPressed: () => onUngroup(eventFaceId, profileId),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SightingIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onPressed;

  const _SightingIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: busy
              ? SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 15, color: onPressed == null ? null : color),
        ),
      ),
    );
  }
}

class _RecentUnknownsTab extends StatelessWidget {
  final List<Map<String, dynamic>> faces;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onAssign;

  const _RecentUnknownsTab({
    required this.faces,
    required this.isAdmin,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (faces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.face_retouching_natural,
                size: 48,
                color: tokens.textWhisper,
              ),
              const SizedBox(height: 10),
              Text(
                'No recent unknown detections.',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: faces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final face = faces[i];
        final ce = face['camera_events'];
        final snapshotPath = ce is Map ? ce['snapshot_path']?.toString() : null;
        final createdRaw = ce is Map ? ce['created_at']?.toString() : null;
        final created = DateTime.tryParse(createdRaw ?? '');

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.borderSoft),
          ),
          child: Row(
            children: [
              _SnapshotThumb(path: snapshotPath, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unknown person',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (created != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy · HH:mm').format(created),
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: () => onAssign(face),
                  icon: const Icon(Icons.person_add_alt_1, size: 14),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.emberCore,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Persistent header that hosts the TabBar between scroll + tab views.
class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabsDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabsDelegate oldDelegate) =>
      oldDelegate.child != child;
}
