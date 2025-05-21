// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/services/storage_service.dart';
import '../../models/services/auth_service.dart';
import '../../viewmodels/user_viewmodel.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  File? _imageFile;
  bool _isLoading = false;
  final _storageService = StorageService();

  Future<void> _showImageOptionsDialog() async {
    final theme = Theme.of(context);
    
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Choose new photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Remove photo',
                style: TextStyle(
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _handleProfilePhotoUpdate(null);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            cropStyle: CropStyle.circle,
            toolbarTitle: 'Crop Photo',
            statusBarColor: Colors.transparent,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile != null) {
        await _handleProfilePhotoUpdate(File(croppedFile.path));
      }
    }
  }

  Future<void> _handleProfilePhotoUpdate(File? newImageFile) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      String? photoURL;
      if (newImageFile != null) {
        photoURL = await _storageService.uploadProfileImage(
          currentUser.uid,
          newImageFile,
        );
      }

      // Update the user's photo URL in Firestore
      final userVM = Provider.of<UserViewModel>(context, listen: false);
      await userVM.updateProfilePhoto(photoURL);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userVM = Provider.of<UserViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ClipOval(
                              child: userVM.profileImageUrl != null
                                  ? Image.network(
                                      userVM.profileImageUrl!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(
                                        Icons.person,
                                        size: 64,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          color: theme.colorScheme.onPrimary,
                          onPressed: _showImageOptionsDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name Section
              Text(
                'Personal Information',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Name'),
                subtitle: Text(
                  '${userVM.firstName} ${userVM.lastName}',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.lock_outline),
              ),
              ListTile(
                title: const Text('Email'),
                subtitle: Text(
                  userVM.email ?? 'Not set',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.lock_outline),
              ),
              ListTile(
                title: const Text('Class'),
                subtitle: Text(
                  userVM.classYear ?? 'Not set',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.lock_outline),
              ),
              const SizedBox(height: 16),
              Text(
                'Your name, email, and class cannot be changed. Please contact support if you need to make corrections.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}