import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/incident.dart';

enum PhotoSource { camera, gallery }

/// Captures a photo, shrinks it and keeps a copy inside the app.
abstract interface class PhotoService {
  /// Returns null when the user cancels.
  Future<PickedPhoto?> pick(PhotoSource source);

  /// Deletes a photo that was picked but never saved.
  Future<void> discard(String localPath);
}

class DevicePhotoService implements PhotoService {
  DevicePhotoService({ImagePicker? picker, Uuid uuid = const Uuid()})
    : _picker = picker ?? ImagePicker(),
      _uuid = uuid;

  /// Long edge limit in pixels.
  static const maxEdge = 1280.0;
  static const jpegQuality = 80;

  final ImagePicker _picker;
  final Uuid _uuid;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxEdge,
      maxHeight: maxEdge,
      imageQuality: jpegQuality,
    );
    if (file == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'incident_photos'));
    await folder.create(recursive: true);
    final target = p.join(folder.path, '${_uuid.v4()}.jpg');
    final bytes = await file.readAsBytes();
    await File(target).writeAsBytes(bytes, flush: true);

    final size = await _dimensions(bytes);
    return PickedPhoto(
      localPath: target,
      width: size.$1,
      height: size.$2,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<void> discard(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort: an orphaned file is harmless.
    }
  }

  Future<(int, int)> _dimensions(Uint8List bytes) async {
    final image = await decodeImageFromList(bytes);
    final size = (image.width, image.height);
    image.dispose();
    return size;
  }
}
