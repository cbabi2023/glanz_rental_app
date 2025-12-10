import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

/// Permission Service
/// 
/// Handles permission requests for camera and gallery access
class PermissionService {
  static const String _permissionsRequestedKey = 'permissions_requested';

  /// Check if permissions have been requested before
  static Future<bool> hasRequestedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsRequestedKey) ?? false;
  }

  /// Mark permissions as requested
  static Future<void> markPermissionsAsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsRequestedKey, true);
  }

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return status.isGranted;
  }

  /// Request gallery/media permissions based on Android version
  static Future<bool> requestGalleryPermission() async {
    // Check Android version - use READ_MEDIA_IMAGES for Android 13+
    // For older versions, use READ_EXTERNAL_STORAGE
    // The permission_handler plugin handles this automatically based on platform
    ph.Permission permission;
    
    // Try to use photos permission (Android 13+), fallback to storage
    try {
      // Check if photos permission is available (Android 13+)
      final photosStatus = await ph.Permission.photos.status;
      permission = ph.Permission.photos;
      
      // If photos permission is permanently denied or restricted, try storage
      if (photosStatus.isPermanentlyDenied || photosStatus.isRestricted) {
        permission = ph.Permission.storage;
      }
    } catch (e) {
      // Fallback to storage permission for older Android versions
      permission = ph.Permission.storage;
    }
    
    final status = await permission.request();
    return status.isGranted;
  }

  /// Request both camera and gallery permissions
  static Future<Map<ph.Permission, ph.PermissionStatus>> requestAllPermissions() async {
    List<ph.Permission> permissions = [];
    
    // Always request camera
    permissions.add(ph.Permission.camera);
    
    // Request appropriate storage/gallery permission
    // The permission_handler will use the correct one based on Android version
    // Try photos first (Android 13+), fallback to storage for older versions
    try {
      // Check if photos permission is available (Android 13+)
      await ph.Permission.photos.status;
      permissions.add(ph.Permission.photos);
    } catch (e) {
      // Fallback to storage for older versions
      permissions.add(ph.Permission.storage);
    }

    final statuses = await permissions.request();
    return statuses;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await ph.Permission.camera.status;
    return status.isGranted;
  }

  /// Check if gallery permission is granted
  static Future<bool> isGalleryPermissionGranted() async {
    try {
      // Check photos permission first (Android 13+)
      final photosStatus = await ph.Permission.photos.status;
      if (photosStatus.isGranted) {
        return true;
      }
      
      // Check storage permission for older versions
      final storageStatus = await ph.Permission.storage.status;
      return storageStatus.isGranted;
    } catch (e) {
      // Fallback to storage permission check
      final storageStatus = await ph.Permission.storage.status;
      return storageStatus.isGranted;
    }
  }

  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}
