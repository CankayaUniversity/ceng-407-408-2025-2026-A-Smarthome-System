import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_data_service.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  List<Map<String, dynamic>> _residents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchResidents();
  }

  Future<void> _fetchResidents() async {
    try {
      final data = await SupabaseDataService.getResidents();
      if (mounted) {
        setState(() {
          _residents = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load residents';
          _loading = false;
        });
      }
    }
  }

  Future<void> _addResident() async {
    final nameController = TextEditingController();
    File? selectedImage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Resident',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a2e))),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery, maxWidth: 800);
                  if (picked != null) {
                    setModalState(() => selectedImage = File(picked.path));
                  }
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 32, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Tap to add photo',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.pop(ctx, {
                      'name': nameController.text.trim(),
                      'image': selectedImage,
                    });
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Resident',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C61B2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        setState(() => _loading = true);
        final userId = context.read<AuthProvider>().user?.id ?? '';
        String? photoPath;

        final File? image = result['image'];
        if (image != null) {
          final ext = image.path.split('.').last.toLowerCase();
          final fileName =
              'resident_photos/${DateTime.now().millisecondsSinceEpoch}.$ext';
          final bytes = await image.readAsBytes();
          await Supabase.instance.client.storage
              .from(SupabaseConfig.snapshotBucket)
              .uploadBinary(fileName, bytes,
                  fileOptions:
                      FileOptions(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'));
          photoPath = fileName;
        }

        await SupabaseDataService.addResident(
          name: result['name'],
          userId: userId,
          photoPath: photoPath,
        );
        _fetchResidents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add resident: $e')),
          );
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _deleteResident(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resident'),
        content:
            const Text('Are you sure you want to remove this resident?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _updatePhoto(String id) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;

    try {
      final image = File(picked.path);
      final ext = image.path.split('.').last.toLowerCase();
      final fileName =
          'resident_photos/${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await image.readAsBytes();

      await Supabase.instance.client.storage
          .from(SupabaseConfig.snapshotBucket)
          .uploadBinary(fileName, bytes,
              fileOptions:
                  FileOptions(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'));

      await SupabaseDataService.updateResident(id, {'photo_path': fileName});
      _fetchResidents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    }
  }

  String? _getResidentPhotoUrl(Map<String, dynamic> resident) {
    // Prefer resident_faces[0].image_path, fallback to photo_path
    final faces = resident['resident_faces'] as List?;
    final facePath = (faces != null && faces.isNotEmpty)
        ? faces.first['image_path']?.toString()
        : null;
    final photoPath = facePath ?? resident['photo_path']?.toString();
    if (photoPath == null || photoPath.isEmpty) return null;
    return SupabaseConfig.snapshotUrl(photoPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addResident,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Resident'),
        backgroundColor: const Color(0xFF5C61B2),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchResidents,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Residents',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a1a2e))),
                      const SizedBox(height: 4),
                      Text('${_residents.length} registered faces',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style:
                                TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchResidents,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C61B2),
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
                        Icon(Icons.group_add,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No residents yet',
                            style:
                                TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('Tap + to add a person',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildResidentCard(_residents[i]),
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

  Widget _buildResidentCard(Map<String, dynamic> resident) {
    final name = resident['name'] ?? 'Unknown';
    final hasEmbedding = resident['embedding'] != null;
    final id = resident['id']?.toString() ?? '';
    final imageUrl = _getResidentPhotoUrl(resident);

    return Container(
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
          GestureDetector(
            onTap: () => _updatePhoto(id),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF5C61B2).withOpacity(0.1),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null
                  ? Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C61B2)),
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
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasEmbedding
                            ? const Color(0xFF00E5A0).withOpacity(0.12)
                            : Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasEmbedding ? 'Enrolled' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasEmbedding
                              ? const Color(0xFF00E5A0)
                              : Colors.orange,
                        ),
                      ),
                    ),
                    if (imageUrl != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.photo_camera,
                          size: 14, color: Colors.grey.shade400),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _updatePhoto(id),
            icon: const Icon(Icons.camera_alt, size: 20),
            color: Colors.grey.shade400,
            tooltip: 'Update Photo',
          ),
          IconButton(
            onPressed: () => _deleteResident(id),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red.shade300,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
