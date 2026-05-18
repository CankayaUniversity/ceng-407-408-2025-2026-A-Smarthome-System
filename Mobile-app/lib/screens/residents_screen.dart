import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../utils/resident_account.dart';
import '../utils/resident_recognition.dart';

class ResidentsScreen extends StatefulWidget {
  final bool showBackButton;

  const ResidentsScreen({super.key, this.showBackButton = true});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  List<Map<String, dynamic>> _residents = [];
  bool _loading = true;
  String? _error;
  /// Web parity: `useEffect(() => fetchResidents(), [isAdmin])`.
  bool? _lastFetchedIncludeAuthStatus;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().addListener(_onAuthProviderChanged);
    _fetchResidents();
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthProviderChanged);
    super.dispose();
  }

  void _onAuthProviderChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;
    final includeAuth = auth.isAdmin;
    if (_lastFetchedIncludeAuthStatus == includeAuth) return;
    _fetchResidents();
  }

  Future<void> _fetchResidents() async {
    final gen = ++_fetchGeneration;
    final includeAuthStatus = context.read<AuthProvider>().isAdmin;
    try {
      final data = await SupabaseDataService.getResidents(
        includeAuthStatus: includeAuthStatus,
      );
      if (!mounted || gen != _fetchGeneration) return;
      setState(() {
        _residents = data;
        _loading = false;
        _error = null;
        _lastFetchedIncludeAuthStatus = includeAuthStatus;
      });
    } catch (e) {
      if (!mounted || gen != _fetchGeneration) return;
      setState(() {
        _error = 'Failed to load residents';
        _loading = false;
      });
    }
  }

  Future<void> _addResident() async {
    final tokens = context.tokens;
    final isAdmin = context.read<AuthProvider>().isAdmin;
    final nameController = TextEditingController();
    final accountEmailController = TextEditingController();
    File? selectedImage;
    bool createAccount = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: tokens.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Text(
                  'Add Resident',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: tokens.textSecondary),
                    prefixIcon: Icon(Icons.person, color: tokens.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.borderMedium),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.borderSoft),
                    ),
                    filled: true,
                    fillColor: tokens.bgRaised,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                    );
                    if (picked != null) {
                      setModalState(() => selectedImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: tokens.bgRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.borderSoft),
                      image: selectedImage != null
                          ? DecorationImage(
                              image: FileImage(selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: tokens.textWhisper,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.bgRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: createAccount,
                              onChanged: (v) => setModalState(
                                () => createAccount = v ?? false,
                              ),
                              activeColor: tokens.emberCore,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(
                                  () => createAccount = !createAccount,
                                ),
                                child: Text(
                                  'Create a system account for this resident',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (createAccount) ...[
                          const SizedBox(height: 8),
                          Text(
                            'They will receive an email to set their own password and sign in.',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: accountEmailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: tokens.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(
                                color: tokens.textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: tokens.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.borderMedium,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.borderSoft,
                                ),
                              ),
                              filled: true,
                              fillColor: tokens.bgSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;
                      if (createAccount &&
                          accountEmailController.text.trim().isEmpty) {
                        return;
                      }
                      Navigator.pop(ctx, {
                        'name': nameController.text.trim(),
                        'image': selectedImage,
                        'createAccount': createAccount,
                        'accountEmail': accountEmailController.text.trim(),
                      });
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'Add Resident',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.emberCore,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      if (!mounted) return;
      try {
        setState(() => _loading = true);
        final auth = context.read<AuthProvider>();
        String? photoPath;

        final File? image = result['image'];
        if (image != null) {
          final ext = image.path.split('.').last.toLowerCase();
          final fileName =
              'resident_photos/${DateTime.now().millisecondsSinceEpoch}.$ext';
          final bytes = await image.readAsBytes();
          await Supabase.instance.client.storage
              .from(SupabaseConfig.snapshotBucket)
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                  contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
                ),
              );
          photoPath = fileName;
        }

        final bool wantsAccount = (result['createAccount'] as bool?) ?? false;
        final String accountEmail = ((result['accountEmail'] as String?) ?? '')
            .trim();
        final bool linkAccount = wantsAccount && accountEmail.isNotEmpty;

        final insertedId = await SupabaseDataService.addResident(
          name: result['name'],
          userId: null,
          photoPath: photoPath,
          accountEmail: linkAccount ? accountEmail : null,
        );

        // Web parity: insert first, then attempt the auth account. If the
        // account creation fails, the resident row still survives so the
        // admin can retry with "Create Account". On success we also link
        // `residents.auth_user_id` so RLS resident-scoped policies match
        // their own row (mirrors website/client/src/pages/ResidentsPage.jsx).
        if (linkAccount) {
          final res = await auth.createResidentAccount(
            name: result['name'],
            email: accountEmail,
          );
          if (!mounted) return;
          if (!res.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Resident added, but account creation failed: ${res.error ?? 'unknown error'}',
                ),
              ),
            );
          } else if (insertedId != null && res.userId != null) {
            try {
              await SupabaseDataService.updateResident(insertedId, {
                'auth_user_id': res.userId,
              });
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Account created, but failed to link auth_user_id: $e',
                    ),
                  ),
                );
              }
            }
          }
        }
        _fetchResidents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add resident: $e')));
          setState(() => _loading = false);
        }
      }
    }
  }

  /// Admin-only: links an existing resident row to a new auth account.
  Future<void> _createAccountForResident(Map<String, dynamic> resident) async {
    final tokens = context.tokens;
    final emailController = TextEditingController();
    final name = (resident['name'] ?? '').toString();
    final residentId = resident['id']?.toString();
    if (residentId == null || residentId.isEmpty) return;

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Account',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a password-setup email to $name. They will be able to '
              'sign in once they finish setting their password.',
              style: TextStyle(color: tokens.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: tokens.textSecondary),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: tokens.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = emailController.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.emberCore,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final res = await auth.createResidentAccount(name: name, email: email);
    if (!mounted) return;

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account creation failed: ${res.error ?? 'unknown error'}',
          ),
        ),
      );
      return;
    }

    try {
      await SupabaseDataService.updateResident(residentId, {
        'account_email': email,
        // Web parity: link the resident row to the new auth user so
        // RLS resident-scoped policies can match (ResidentsPage.jsx:176).
        if (res.userId != null) 'auth_user_id': res.userId,
      });
      _fetchResidents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created, but failed to link row: $e'),
          ),
        );
      }
    }
  }

  Future<void> _deleteResident(String id) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resident'),
        content: const Text('Are you sure you want to remove this resident?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: tokens.crimsonCore)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseDataService.deleteResident(id);
        _fetchResidents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  bool _canEditResidentPhoto(Map<String, dynamic> resident) {
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) return true;
    final user = auth.user;
    if (user == null) return false;

    final authUserId = resident['auth_user_id']?.toString();
    if (authUserId != null && authUserId == user.id) return true;

    final accountEmail = resident['account_email']?.toString().toLowerCase();
    final userEmail = user.email?.toLowerCase();
    return accountEmail != null &&
        accountEmail.isNotEmpty &&
        accountEmail == userEmail;
  }

  Future<ImageSource?> _pickPhotoSource() {
    final tokens = context.tokens;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.borderSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: tokens.emberCore),
              title: Text(
                'Take Photo',
                style: TextStyle(color: tokens.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: tokens.emberCore),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: tokens.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePhoto(String id) async {
    final source = await _pickPhotoSource();
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800);
    if (picked == null) return;

    try {
      final image = File(picked.path);
      final ext = image.path.split('.').last.toLowerCase();
      final fileName =
          'resident_photos/${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await image.readAsBytes();

      await Supabase.instance.client.storage
          .from(SupabaseConfig.snapshotBucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
            ),
          );

      await SupabaseDataService.updateResident(id, {'photo_path': fileName});
      _fetchResidents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    }
  }

  /// Web parity (`ResidentsPage.jsx`): photo is sourced exclusively from
  /// `residents.photo_path` now that the `resident_faces` join is gone.
  /// `assign_event_face_to_resident` keeps this column in sync when an
  /// admin re-enrolls a face from the surveillance log.
  String? _getResidentPhotoUrl(Map<String, dynamic> resident) {
    final photoPath = resident['photo_path']?.toString();
    if (photoPath == null || photoPath.isEmpty) return null;
    return SupabaseConfig.snapshotUrl(photoPath);
  }

  Color _accountBadgeColor(ResidentAccountTone tone, AppTokens tokens) {
    return switch (tone) {
      ResidentAccountTone.success => tokens.jadeCore,
      ResidentAccountTone.warning => tokens.amberCore,
      ResidentAccountTone.info => tokens.cyanCore,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: tokens.bgVoid,
      appBar: widget.showBackButton
          ? AppBar(
              backgroundColor: tokens.bgVoid,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
            )
          : null,
      // Web parity: residents INSERT is admin-only (supabase_setup_v4 RLS).
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addResident,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Resident'),
              backgroundColor: tokens.emberCore,
              foregroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchResidents,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Residents',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _residents.isEmpty
                            ? 'Add household members so the front-door camera can recognize them.'
                            : '${_residents.length} household member${_residents.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 56,
                          color: tokens.textWhisper,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchResidents,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.emberCore,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_residents.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_add,
                          size: 56,
                          color: tokens.textWhisper,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No residents yet',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add a person',
                          style: TextStyle(
                            color: tokens.textWhisper,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildResidentCard(_residents[i], tokens),
                      childCount: _residents.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentCard(Map<String, dynamic> resident, AppTokens tokens) {
    final name = resident['name']?.toString().trim();
    final safeName = (name != null && name.isNotEmpty) ? name : 'Unknown';
    final id = resident['id']?.toString() ?? '';
    final imageUrl = _getResidentPhotoUrl(resident);
    final recognition = getResidentRecognitionStatus(resident);
    final accountBadge = getResidentAccountBadge(resident);
    final hasAccount = residentHasLoginAccount(resident);
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final canEditPhoto = _canEditResidentPhoto(resident);
    final recColor = recognitionToneColor(recognition.tone, tokens);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: canEditPhoto ? () => _updatePhoto(id) : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: tokens.emberCore.withValues(alpha: 0.1),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? Center(
                          child: Text(
                            safeName.isNotEmpty
                                ? safeName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: tokens.emberCore,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resident',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  onPressed: () => _deleteResident(id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: tokens.crimsonCore.withValues(alpha: 0.7),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.bgRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recognition.statusLine,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: recognitionToneBackground(
                      recognition.tone,
                      tokens,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(recognition.badgeIcon, size: 11, color: recColor),
                      const SizedBox(width: 4),
                      Text(
                        recognition.badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: recColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (canEditPhoto)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updatePhoto(id),
                    icon: Icon(
                      Icons.photo_camera_outlined,
                      size: 15,
                      color: tokens.textSecondary,
                    ),
                    label: Text(
                      'Upload Photo',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: tokens.borderSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (canEditPhoto && isAdmin && !hasAccount)
                const SizedBox(width: 8),
              if (isAdmin && !hasAccount)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createAccountForResident(resident),
                    icon: Icon(
                      Icons.person_add_alt_1,
                      size: 15,
                      color: tokens.violetCore,
                    ),
                    label: Text(
                      'Create Account',
                      style: TextStyle(
                        color: tokens.violetCore,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(
                        color: tokens.violetCore.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (accountBadge != null) ...[
                if (canEditPhoto || (isAdmin && !hasAccount))
                  const SizedBox(width: 8),
                Flexible(
                  child: Tooltip(
                    message: accountBadge.title,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          accountBadge.icon,
                          size: 13,
                          color: _accountBadgeColor(
                            accountBadge.tone,
                            tokens,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            accountBadge.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _accountBadgeColor(
                                accountBadge.tone,
                                tokens,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
