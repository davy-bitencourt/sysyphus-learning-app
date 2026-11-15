import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/services/media_storage_service.dart';

class MediaImage extends StatefulWidget {
  const MediaImage({super.key, required this.path, this.width, this.height, this.fit = BoxFit.cover});
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  late Future<List<int>?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = MediaStorageService.readBytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant MediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = MediaStorageService.readBytes(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>?>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
      return Image.memory(
        Uint8List.fromList(bytes),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    },
  );
}
