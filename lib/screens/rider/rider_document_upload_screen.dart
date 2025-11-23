import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/registration_service.dart';
import '../auth/auth_wrapper.dart';
import '../auth/login_screen.dart';

/// Screen for riders to upload all required documents after registration
/// Required uploads:
/// 1. 2x2 Picture
/// 2. Driver's License
/// 3. Official Receipt (OR)
/// 4. Certificate of Registration (CR)
/// 5. Vehicle Front Picture
/// 6. Vehicle Side Picture
/// 7. Vehicle Back Picture
class RiderDocumentUploadScreen extends StatefulWidget {
  const RiderDocumentUploadScreen({super.key});

  @override
  State<RiderDocumentUploadScreen> createState() => _RiderDocumentUploadScreenState();
}

class _RiderDocumentUploadScreenState extends State<RiderDocumentUploadScreen> {
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final RegistrationService _registrationService = RegistrationService();
  bool _isUploading = false;

  // All required file uploads
  File? _profilePicture;
  File? _driversLicense;
  File? _officialReceipt;
  File? _certificateOfRegistration;
  File? _vehicleFrontPicture;
  File? _vehicleSidePicture;
  File? _vehicleBackPicture;

  Future<void> _pickImage({
    required Function(File) onImagePicked,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        onImagePicked(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildImageUploadSection({
    required String title,
    required String description,
    required File? image,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isUploading ? null : onTap,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: image == null
                    ? (isRequired && _isUploading == false 
                        ? AppColors.error.withValues(alpha: 0.5)
                        : AppColors.inputBorder)
                    : AppColors.primary,
                width: image == null ? 1 : 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: image == null
                  ? AppColors.inputBackground
                  : Colors.transparent,
            ),
            child: image == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG, PNG (Max 10MB)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: _isUploading ? null : onRemove,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (image == null && isRequired && _isUploading == false)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              '$title is required',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  bool _validateAllRequiredUploads() {
    return _profilePicture != null &&
        _driversLicense != null &&
        _officialReceipt != null &&
        _certificateOfRegistration != null &&
        _vehicleFrontPicture != null &&
        _vehicleSidePicture != null &&
        _vehicleBackPicture != null;
  }

  Future<void> _handleUpload(AuthProvider authProvider) async {
    if (!_validateAllRequiredUploads()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload all required documents'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User not authenticated'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final riderId = authProvider.user!.id;

      // Upload all documents in sequence
      final profilePictureUrl = await _storageService.uploadProfilePicture(
        riderId: riderId,
        imageFile: _profilePicture!,
      );

      final driversLicenseUrl = await _storageService.uploadDriversLicense(
        riderId: riderId,
        imageFile: _driversLicense!,
      );

      final officialReceiptUrl = await _storageService.uploadOfficialReceipt(
        riderId: riderId,
        imageFile: _officialReceipt!,
      );

      final certificateOfRegistrationUrl =
          await _storageService.uploadCertificateOfRegistration(
        riderId: riderId,
        imageFile: _certificateOfRegistration!,
      );

      final vehicleFrontPictureUrl = await _storageService.uploadVehiclePicture(
        riderId: riderId,
        imageFile: _vehicleFrontPicture!,
        pictureType: 'front',
      );

      final vehicleSidePictureUrl = await _storageService.uploadVehiclePicture(
        riderId: riderId,
        imageFile: _vehicleSidePicture!,
        pictureType: 'side',
      );

      final vehicleBackPictureUrl = await _storageService.uploadVehiclePicture(
        riderId: riderId,
        imageFile: _vehicleBackPicture!,
        pictureType: 'back',
      );

      // Update rider record with all document URLs
      await _registrationService.updateRiderDetails(
        riderId,
        profilePictureUrl: profilePictureUrl,
        driversLicenseUrl: driversLicenseUrl,
        officialReceiptUrl: officialReceiptUrl,
        certificateOfRegistrationUrl: certificateOfRegistrationUrl,
        vehicleFrontPictureUrl: vehicleFrontPictureUrl,
        vehicleSidePictureUrl: vehicleSidePictureUrl,
        vehicleBackPictureUrl: vehicleBackPictureUrl,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'All documents uploaded successfully! Your account is pending admin approval.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      // Reload auth provider to refresh user state
      await authProvider.loadUser();

      if (!mounted) return;

      // After successful submission, sign out and redirect to Login.
      // Rider must wait for admin approval before being able to sign in.
      await authProvider.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload documents: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                Icons.upload_file,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Your Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please upload all required documents to complete your registration',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Information Card
              Card(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Important',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your documents will be reviewed by an admin. You will be notified once your account is approved. All fields marked with * are required.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Personal Documents Section
              Text(
                'Personal Documents',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // 2x2 Picture
              _buildImageUploadSection(
                title: '2x2 Picture',
                description: 'Upload a clear 2x2 passport-sized photo',
                image: _profilePicture,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _profilePicture = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _profilePicture = null;
                  });
                },
                isRequired: true,
              ),
              // Driver's License
              _buildImageUploadSection(
                title: "Driver's License",
                description: 'Upload a clear photo of your valid driver\'s license',
                image: _driversLicense,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _driversLicense = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _driversLicense = null;
                  });
                },
                isRequired: true,
              ),
              const SizedBox(height: 24),
              // Vehicle Documents Section
              Text(
                'Vehicle Documents',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // Official Receipt
              _buildImageUploadSection(
                title: 'Official Receipt (OR)',
                description: 'Upload a clear photo of your motor vehicle\'s Official Receipt',
                image: _officialReceipt,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _officialReceipt = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _officialReceipt = null;
                  });
                },
                isRequired: true,
              ),
              // Certificate of Registration
              _buildImageUploadSection(
                title: 'Certificate of Registration (CR)',
                description: 'Upload a clear photo of your motor vehicle\'s Certificate of Registration',
                image: _certificateOfRegistration,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _certificateOfRegistration = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _certificateOfRegistration = null;
                  });
                },
                isRequired: true,
              ),
              const SizedBox(height: 24),
              // Vehicle Pictures Section
              Text(
                'Vehicle Pictures',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // Vehicle Front
              _buildImageUploadSection(
                title: 'Vehicle Front Picture',
                description: 'Upload a clear photo of your vehicle from the front',
                image: _vehicleFrontPicture,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _vehicleFrontPicture = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _vehicleFrontPicture = null;
                  });
                },
                isRequired: true,
              ),
              // Vehicle Side
              _buildImageUploadSection(
                title: 'Vehicle Side Picture',
                description: 'Upload a clear photo of your vehicle from the side',
                image: _vehicleSidePicture,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _vehicleSidePicture = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _vehicleSidePicture = null;
                  });
                },
                isRequired: true,
              ),
              // Vehicle Back
              _buildImageUploadSection(
                title: 'Vehicle Back Picture',
                description: 'Upload a clear photo of your vehicle from the back',
                image: _vehicleBackPicture,
                onTap: () => _pickImage(
                  onImagePicked: (file) {
                    setState(() {
                      _vehicleBackPicture = file;
                    });
                  },
                ),
                onRemove: () {
                  setState(() {
                    _vehicleBackPicture = null;
                  });
                },
                isRequired: true,
              ),
              const SizedBox(height: 32),
              // Submit Button
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return ElevatedButton(
                    onPressed: (_isUploading || !_validateAllRequiredUploads())
                        ? null
                        : () => _handleUpload(authProvider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Upload All Documents',
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
