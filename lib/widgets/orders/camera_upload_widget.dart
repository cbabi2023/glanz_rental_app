import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/supabase_client.dart';
import '../../services/permission_service.dart';

/// Camera Upload Widget
/// 
/// Handles image capture/selection and upload to Supabase Storage
class CameraUploadWidget extends StatefulWidget {
  final Function(String) onUploadComplete;
  final String? currentUrl;

  const CameraUploadWidget({
    super.key,
    required this.onUploadComplete,
    this.currentUrl,
  });

  @override
  State<CameraUploadWidget> createState() => _CameraUploadWidgetState();
}

class _CameraUploadWidgetState extends State<CameraUploadWidget> {
  bool _uploading = false;
  String? _previewUrl;

  Future<void> _pickImage(ImageSource source) async {
    // Check and request permission before picking image
    bool hasPermission = false;
    
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.isCameraPermissionGranted();
      if (!hasPermission) {
        hasPermission = await PermissionService.requestCameraPermission();
      }
    } else {
      hasPermission = await PermissionService.isGalleryPermissionGranted();
      if (!hasPermission) {
        hasPermission = await PermissionService.requestGalleryPermission();
      }
    }
    
    if (!hasPermission) {
      if (mounted) {
        _showPermissionDeniedDialog(source == ImageSource.camera ? 'camera' : 'gallery');
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _uploading = true;
          _previewUrl = image.path;
        });

        // Upload to Supabase Storage
        try {
          final supabase = SupabaseService.client;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final random = DateTime.now().microsecondsSinceEpoch.toString().substring(0, 6);
          final fileName = '$timestamp-$random.jpg';
          final filePath = 'order-items/$fileName';

          // Upload file
          final file = File(image.path);
          await supabase.storage.from('order-items').upload(
            filePath,
            file,
          );

          // Get public URL
          final url = supabase.storage
              .from('order-items')
              .getPublicUrl(filePath);

          setState(() {
            _uploading = false;
            _previewUrl = null;
          });

          widget.onUploadComplete(url);
        } catch (e) {
          setState(() {
            _uploading = false;
            _previewUrl = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _previewUrl = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          'This app needs $permissionType permission to add photos. Please grant the permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = widget.currentUrl ?? _previewUrl;

    if (displayUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(displayUrl),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(24, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _uploading
                  ? null
                  : () {
                      widget.onUploadComplete('');
                    },
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _uploading ? null : _showImageSourceDialog,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: _uploading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : const Icon(
                Icons.camera_alt,
                size: 32,
                color: Colors.grey,
              ),
      ),
    );
  }
}

