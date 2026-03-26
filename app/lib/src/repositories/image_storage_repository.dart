import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class PickedImageFile {
  const PickedImageFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ImageStorageRepository {
  ImageStorageRepository(this._client);

  static const String bucketName = 'app-images';

  final SupabaseClient _client;

  Future<PickedImageFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('이미지 파일을 읽을 수 없습니다.');
    }

    return PickedImageFile(
      bytes: _convertToJpeg(bytes),
      fileName: '${_fileStem(file.name)}.jpg',
    );
  }

  String studioObjectPath(String studioId) => 'studios/$studioId.jpg';

  String userObjectPath(String memberCode) =>
      'users/${memberCode.trim().toLowerCase()}.jpg';

  String instructorObjectPath({
    required String studioId,
    required String instructorName,
  }) => 'instructors/${studioId}_${_sanitizePathSegment(instructorName)}.jpg';

  Future<String> uploadStudioImage({
    required String studioId,
    required PickedImageFile file,
  }) async {
    final objectPath = studioObjectPath(studioId);
    return _uploadImage(objectPath: objectPath, file: file);
  }

  Future<String> uploadUserImage({
    required String memberCode,
    required PickedImageFile file,
  }) async {
    final objectPath = userObjectPath(memberCode);
    return _uploadImage(objectPath: objectPath, file: file);
  }

  Future<String> uploadInstructorImage({
    required String studioId,
    required String instructorName,
    required PickedImageFile file,
  }) async {
    final objectPath = instructorObjectPath(
      studioId: studioId,
      instructorName: instructorName,
    );
    return _uploadImage(objectPath: objectPath, file: file);
  }

  Future<Uint8List> downloadObject(String objectPath) async {
    return _client.storage.from(bucketName).download(objectPath);
  }

  Future<void> removeObject(String objectPath) async {
    if (objectPath.trim().isEmpty) {
      return;
    }
    try {
      await _client.storage.from(bucketName).remove([objectPath]);
    } on StorageException catch (error) {
      final message = error.message.toLowerCase();
      if (!message.contains('not found') && !message.contains('no such')) {
        rethrow;
      }
    }
  }

  String? tryExtractObjectPath(String? imageUrl) {
    final value = imageUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex < 0 || publicIndex + 1 >= segments.length) {
      return null;
    }
    if (segments[publicIndex + 1] != bucketName) {
      return null;
    }

    final objectSegments = segments
        .skip(publicIndex + 2)
        .toList(growable: false);
    if (objectSegments.isEmpty) {
      return null;
    }
    return objectSegments.join('/');
  }

  Future<String> _uploadImage({
    required String objectPath,
    required PickedImageFile file,
  }) async {
    await _client.storage
        .from(bucketName)
        .uploadBinary(
          objectPath,
          file.bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage.from(bucketName).getPublicUrl(objectPath);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Uint8List _convertToJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('지원하지 않는 이미지 형식입니다.');
    }

    final flattened = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flattened, decoded);

    return Uint8List.fromList(img.encodeJpg(flattened, quality: 88));
  }

  String _fileStem(String name) {
    final index = name.lastIndexOf('.');
    if (index <= 0) {
      return 'image';
    }
    return name.substring(0, index);
  }

  String _sanitizePathSegment(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'image';
    }

    final buffer = StringBuffer();
    var previousDash = false;
    for (final rune in trimmed.runes) {
      final isDigit = rune >= 48 && rune <= 57;
      final isLowercase = rune >= 97 && rune <= 122;
      if (isDigit || isLowercase) {
        buffer.writeCharCode(rune);
        previousDash = false;
        continue;
      }

      if (rune == 32 || rune == 45 || rune == 95) {
        if (!previousDash && buffer.isNotEmpty) {
          buffer.write('-');
          previousDash = true;
        }
        continue;
      }

      if (!previousDash && buffer.isNotEmpty) {
        buffer.write('-');
      }
      buffer.write('u${rune.toRadixString(16)}');
      previousDash = false;
    }

    final sanitized = buffer.toString().replaceAll(RegExp(r'-+'), '-');
    final normalized = sanitized.replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'image' : normalized;
  }
}
