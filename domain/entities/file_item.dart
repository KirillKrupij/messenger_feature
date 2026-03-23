import 'package:equatable/equatable.dart';

class FileItem extends Equatable {
  final String id;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String storagePath;
  final String storageBucket;

  const FileItem({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.storageBucket,
  });

  @override
  List<Object?> get props => [
        id,
        fileName,
        originalName,
        mimeType,
        sizeBytes,
        storagePath,
        storageBucket,
      ];
}
