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
    if (url == null) return null;
    final api = context.read<ApiClient>();
    final uri = Uri.tryParse(url);
    final base = Uri.parse(api.dio.options.baseUrl);
    // Protected images must use the configured API host, including after a tunnel URL changes.
    if (uri == null || !uri.path.startsWith('/api/v1/files/')) {
      return null;
    }
    final target = base.replace(path: uri.path, query: null, fragment: null);
    try {
      final response = await api.dio.get<List<int>>(target.toString(),
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
        return CircleAvatar(
            radius: widget.radius, backgroundImage: MemoryImage(bytes));
      });
}
