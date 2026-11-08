import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/services/media_storage_service.dart';

/// Resolves both native file paths and persistent browser media references.
class MediaImage extends StatefulWidget {
  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = MediaStorageService.readBytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant MediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = MediaStorageService.readBytes(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        );
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: snapshot.connectionState == ConnectionState.waiting
              ? const CircularProgressIndicator()
              : const Icon(Icons.broken_image_outlined),
        ),
      );
    },
  );
}
