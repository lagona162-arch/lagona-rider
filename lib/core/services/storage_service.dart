import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';


class StorageService {
  final _supabase = SupabaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();



  Future<String> uploadLicenseCard({
    required String riderId,
    required File imageFile,
  }) async {
    try {

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'license_${riderId}_$timestamp.$extension';
      final filePath = 'rider-licenses/$fileName';


      final fileBytes = await imageFile.readAsBytes();


      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);


      final publicUrl = _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload license card: $e');
    }
  }


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



  Future<String> uploadProfilePicture({
    required String riderId,
    required File imageFile,
  }) async {
    try {

      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }


      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024; 
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

      final fileName = 'profile_${riderId}_$timestamp.$extension';

      final filePath = 'rider-profiles/$fileName';

      final fileBytes = await imageFile.readAsBytes();
      

      try {
        await _supabase.storage
            .from('rider-documents')
            .remove([filePath]);
      } catch (_) {

      }
      

      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {

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



  Future<String> uploadDriversLicense({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

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
      String errorMessage = 'Failed to upload driver license';
      
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



  Future<String> uploadOfficialReceipt({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

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
      String errorMessage = 'Failed to upload official receipt';
      
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



  Future<String> uploadCertificateOfRegistration({
    required String riderId,
    required File imageFile,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

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
      String errorMessage = 'Failed to upload certificate of registration';
      
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



  Future<String> uploadVehiclePicture({
    required String riderId,
    required File imageFile,
    required String pictureType, 
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

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
      String errorMessage = 'Failed to upload vehicle $pictureType picture';
      
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



  Future<String> uploadDeliveryPhoto({
    required String deliveryId,
    required File imageFile,
    required String photoType,
    required String riderId,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final deliveryResponse = await _supabase
          .from('deliveries')
          .select('rider_id')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryResponse == null) {
        throw Exception('Delivery not found');
      }

      final deliveryRiderId = deliveryResponse['rider_id'] as String?;
      if (deliveryRiderId != riderId) {
        throw Exception('You are not assigned to this delivery');
      }

      final fileSize = await imageFile.length();
      const maxSize = 10 * 1024 * 1024;
      if (fileSize > maxSize) {
        throw Exception('Image file is too large. Maximum size is 10MB');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Invalid file format. Please use JPG, PNG, or WEBP');
      }

      final fileName = '${photoType}_${deliveryId}_$timestamp.$extension';
      final filePath = 'delivery-photos/$fileName';

      final fileBytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from('rider-documents')
          .uploadBinary(filePath, fileBytes);

      return _supabase.storage
          .from('rider-documents')
          .getPublicUrl(filePath);
    } catch (e) {
      String errorMessage = 'Failed to upload delivery photo';
      if (e.toString().contains('StorageException') ||
          e.toString().contains('storage')) {
        if (e.toString().contains('new row violates row-level security') ||
            e.toString().contains('RLS') ||
            e.toString().contains('permission denied')) {
          errorMessage = 'Permission denied. Please ensure you are assigned to this delivery and have upload permissions.';
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


  Future<void> deleteLicenseCard(String fileUrl) async {
    try {


      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.path.split('/');
      

      final bucketIndex = pathSegments.indexOf('rider-documents');
      if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {

        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        
        await _supabase.storage
            .from('rider-documents')
            .remove([filePath]);
      }
    } catch (e) {


    }
  }
}

