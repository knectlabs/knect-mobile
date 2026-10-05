import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../shell/signed_in_scope.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _upload(ImageSource source) async {
    if (_busy) return;
    final api = context.read<ApiClient>();
    final profile = context.read<ProfileCubit>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 90);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final extension = photo.path.split('.').last.toLowerCase();
      final type = extension == 'png'
          ? 'png'
          : extension == 'webp'
              ? 'webp'
              : 'jpeg';
      await api.dio.post('/face/profile-photo',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes,
                filename: photo.name, contentType: DioMediaType('image', type))
          }));
      await profile.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = apiFailureOf(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile photo')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.account_circle_outlined,
                      size: 80, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                      'Use a clear photo showing only your face. Your company can use this photo to verify your attendance selfies.'),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  FilledButton.icon(
                      onPressed:
                          _busy ? null : () => _upload(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take profile photo')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _upload(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from gallery')),
                  if (_busy)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator())),
                ])),
      );
}
