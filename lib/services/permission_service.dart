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

  /// Request gallery/media permissions
  /// 
  /// Note: On Android 13+, we use Android Photo Picker which doesn't require permissions.
  /// The image_picker package automatically uses Photo Picker when gallery permissions
  /// are not requested. For older Android versions (API 32 and below), READ_EXTERNAL_STORAGE
  /// in the manifest (with maxSdkVersion="32") handles it.
  /// 
  /// Returns true to allow Photo Picker usage (no explicit permission needed).
  static Future<bool> requestGalleryPermission() async {
    // Photo Picker (Android 13+) doesn't require explicit permissions
    // The image_picker package will use Photo Picker automatically when permissions aren't requested
    return true;
  }

  /// Request both camera and gallery permissions
  /// 
  /// Note: Only requests camera permission. Gallery uses Android Photo Picker
  /// which doesn't require explicit permissions.
  static Future<Map<ph.Permission, ph.PermissionStatus>> requestAllPermissions() async {
    // Only request camera permission - gallery uses Photo Picker (no permission needed)
    final statuses = await [ph.Permission.camera].request();
    return statuses;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await ph.Permission.camera.status;
    return status.isGranted;
  }

  /// Check if gallery permission is granted
  /// 
  /// Note: Photo Picker (Android 13+) doesn't require permissions, so always returns true.
  /// For older Android versions, READ_EXTERNAL_STORAGE in manifest handles it.
  static Future<bool> isGalleryPermissionGranted() async {
    // Photo Picker doesn't require explicit permissions - always allow
    return true;
  }

  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}
