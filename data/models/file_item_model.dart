import '../../domain/entities/file_item.dart';

class FileItemModel extends FileItem {
  const FileItemModel({
    required super.id,
    required super.fileName,
    required super.originalName,
    required super.mimeType,
    required super.sizeBytes,
    required super.storagePath,
    required super.storageBucket,
  });

  factory FileItemModel.fromJson(Map<String, dynamic> json) {
    return FileItemModel(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '0') ?? 0,
      storagePath: json['storage_path']?.toString() ?? '',
      storageBucket: json['storage_bucket']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'original_name': originalName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'storage_path': storagePath,
      'storage_bucket': storageBucket,
    };
  }
}
