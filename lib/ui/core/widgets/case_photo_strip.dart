import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/models/incident.dart';

/// Horizontal strip of a case's photos: the device file when it still exists,
/// otherwise a signed URL resolved by [resolveUrl].
class CasePhotoStrip extends StatelessWidget {
  const CasePhotoStrip({
    super.key,
    required this.photos,
    required this.resolveUrl,
    this.size = 120,
  });

  final List<IncidentPhotoInfo> photos;
  final Future<String?> Function(String storagePath) resolveUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox.square(
          dimension: size,
          child: CasePhotoTile(photo: photos[i], resolveUrl: resolveUrl),
        ),
      ),
    );
  }
}

/// One photo, filling its parent (square thumbnails).
class CasePhotoTile extends StatelessWidget {
  const CasePhotoTile({
    super.key,
    required this.photo,
    required this.resolveUrl,
  });

  final IncidentPhotoInfo photo;
  final Future<String?> Function(String storagePath) resolveUrl;

  static const _missing = ColoredBox(
    color: Colors.black12,
    child: Icon(Icons.image_not_supported_outlined, size: 32),
  );

  @override
  Widget build(BuildContext context) {
    final local = photo.localPath;
    final hasLocal = local != null && File(local).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: hasLocal
          ? Image.file(File(local), fit: BoxFit.cover)
          : FutureBuilder<String?>(
              future: resolveUrl(photo.storagePath),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final url = snapshot.data;
                if (url == null) return _missing;
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _missing,
                );
              },
            ),
    );
  }
}
