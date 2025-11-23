import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';

/// Storage service for uploading files to Supabase Storage
class StorageService {
  final _supabase = SupabaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Upload license card image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadLicenseCard({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'license_${riderId}_$timestamp.$extension';
      final filePath = 'rider-licenses/$fileName';

      // Read file as bytes
      final fileBytes = await imageFile.readAsBytes();

      // Upload file to Supabase Storage
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload license card: $e');
    }
  }

  /// Pick image from gallery or camera
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Upload profile picture (2x2) to Supabase Storage
  /// Saved in rider-documents/rider-profiles/ folder
  Future<String> uploadProfilePicture({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      // Validate file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Check file size (max 10MB)
      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate file extension
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

      final fileName = 'profile_${riderId}_$timestamp.$extension';
      // Store under dedicated folder
      final filePath = 'rider-profiles/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      
      // Try to delete existing file first if it exists (to allow re-upload)
      try {
        await _supabase.storage
            .from('rider-documents')
            .remove([filePath]);
      } catch (_) {
        // Ignore if file doesn't exist
      }
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      // Provide more detailed error message
      String errorMessage = 'Failed to upload profile picture';
      
      if (e.toString().contains('StorageException') || 
          e.toString().contains('storage')) {
        if (e.toString().contains('new row violates row-level security') ||
            e.toString().contains('RLS') ||
            e.toString().contains('permission denied')) {
          errorMessage = 'Permission denied. Please ensure your account has upload permissions.';
        } else if (e.toString().contains('Bucket not found') ||
                   e.toString().contains('does not exist')) {
          errorMessage = 'Storage bucket not found. Please contact support.';
        } else if (e.toString().contains('duplicate') ||
                   e.toString().contains('already exists')) {
          errorMessage = 'File already exists. Please try again.';
        } else {
          errorMessage = 'Storage error: ${e.toString()}';
        }
      } else {
        errorMessage = '$errorMessage: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Upload driver's license to Supabase Storage
  /// Saved in rider-documents/rider-licenses/ folder
  Future<String> uploadDriversLicense({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      // Match RLS policy prefix: license_
      final fileName = 'license_${riderId}_$timestamp.$extension';
      final filePath = 'rider-licenses/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload driver license: $e');
    }
  }

  /// Upload Official Receipt (OR) to Supabase Storage
  /// Saved in rider-documents/rider-or/ folder
  Future<String> uploadOfficialReceipt({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'official_receipt_${riderId}_$timestamp.$extension';
      final filePath = 'rider-or/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload official receipt: $e');
    }
  }

  /// Upload Certificate of Registration (CR) to Supabase Storage
  /// Saved in rider-documents/rider-cr/ folder
  Future<String> uploadCertificateOfRegistration({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'certificate_registration_${riderId}_$timestamp.$extension';
      final filePath = 'rider-cr/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload certificate of registration: $e');
    }
  }

  /// Upload vehicle picture (front, side, or back) to Supabase Storage
  /// Saved in rider-documents/rider-vehicles/ folder
  Future<String> uploadVehiclePicture({
    required String riderId,
    required File imageFile,
    required String pictureType, // 'front', 'side', or 'back'
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'vehicle_${pictureType}_${riderId}_$timestamp.$extension';
      final filePath = 'rider-vehicles/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Failed to upload vehicle $pictureType picture: $e');
    }
  }

  /// Delete license card from storage
  Future<void> deleteLicenseCard(String fileUrl) async {
    try {
      // Extract file path from URL
      // URL format: https://[project].supabase.co/storage/v1/object/public/rider-documents/rider-licenses/filename
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.path.split('/');
      
      // Find the index of 'rider-documents' in the path
      final bucketIndex = pathSegments.indexOf('rider-documents');
      if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
        // Get the path after 'rider-documents' (should be 'rider-licenses/filename')
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        
        await _supabase.storage
            .from('rider-documents')
            .remove([filePath]);
      }
    } catch (e) {
      // Silently fail if file doesn't exist or URL is malformed
      // throw Exception('Failed to delete license card: $e');
    }
  }
}

