import 'dart:typed_data';

/// In-memory file payload used by KYC (picker + camera + signature pad).
///
/// Kept separate from `file_picker`'s [PlatformFile], which is platform-owned
/// and no longer constructible from raw bytes in file_picker 13+.
class PickedBytesFile {
  const PickedBytesFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get size => bytes.length;

  String? get extension {
    final parts = name.split('.');
    if (parts.length < 2) return null;
    final ext = parts.last.trim().toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  PickedBytesFile renamed(String newName) =>
      PickedBytesFile(name: newName, bytes: bytes);
}
