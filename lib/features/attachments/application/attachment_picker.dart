import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../domain/attachment_policy.dart';

enum AttachmentPickerKind { images, files }

abstract interface class AttachmentPicker {
  /// A null result is a user cancellation. Adapters only expose streams; file
  /// bytes remain owned by [SelectAttachments] and are never loaded at once.
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind);
}

final class NativeAttachmentPicker implements AttachmentPicker {
  NativeAttachmentPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) async {
    switch (kind) {
      case AttachmentPickerKind.images:
        final List<XFile> picked = await _imagePicker.pickMultiImage();
        if (picked.isEmpty) return null;
        return List<AttachmentInput>.unmodifiable(
          picked.map(
            (XFile file) => AttachmentInput(
              name: file.name,
              declaredMime: file.mimeType ?? lookupMimeType(file.name),
              openRead: file.openRead,
            ),
          ),
        );
      case AttachmentPickerKind.files:
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const <String>[
            'jpg',
            'jpeg',
            'png',
            'webp',
            'pdf',
          ],
          withData: false,
          withReadStream: true,
        );
        if (result == null || result.files.isEmpty) return null;
        return List<AttachmentInput>.unmodifiable(
          result.files.map((PlatformFile file) {
            Stream<List<int>> openRead() {
              final Stream<List<int>>? stream = file.readStream;
              if (stream != null) return stream;
              final String? sourcePath = file.path;
              if (sourcePath == null) {
                return Stream<List<int>>.error(
                  const FileSystemException('Picker stream unavailable'),
                );
              }
              return File(sourcePath).openRead();
            }

            return AttachmentInput(
              name: file.name,
              declaredMime: lookupMimeType(file.name),
              openRead: openRead,
            );
          }),
        );
    }
  }
}
