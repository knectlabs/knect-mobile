import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import 'initials_avatar.dart';

class ProfilePhotoAvatar extends StatefulWidget {
  const ProfilePhotoAvatar(
      {required this.name, this.photoUrl, this.radius = 30, super.key});
  final String name;
  final String? photoUrl;
  final double radius;

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  Future<Uint8List?>? _photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photo ??= _load();
  }

  @override
  void didUpdateWidget(ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _photo = _load();
  }

  Future<Uint8List?> _load() async {
    final url = widget.photoUrl;
    if (url == null || url.trim().isEmpty) return null;
    final api = context.read<ApiClient>();
    final uri = Uri.tryParse(url);
    final base = Uri.parse(api.dio.options.baseUrl);
    // Protected images must use the configured API host, including after a tunnel URL changes.
    if (uri == null) return null;
    final protected = uri.path.startsWith('/api/v1/files/');
    if (!protected && (uri.scheme != 'https' || uri.host.isEmpty)) return null;
    final target = protected
        ? base.replace(path: uri.path, query: null, fragment: null)
        : uri;
    try {
      // Public profile images use a separate client without API credentials.
      final client = protected
          ? api.dio
          : Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));
      final response = await client.get<List<int>>(target.toString(),
          options: Options(responseType: ResponseType.bytes));
      final bytes = response.data;
      return bytes == null ? null : Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return InitialsAvatar(name: widget.name, radius: widget.radius);
        }
        return ClipOval(
          child: Image.memory(
            bytes,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                InitialsAvatar(name: widget.name, radius: widget.radius),
          ),
        );
      });
}
