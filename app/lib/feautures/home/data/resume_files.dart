import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

class PickedResume {
  const PickedResume({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef ResumePicker = Future<List<PickedResume>> Function();

Future<List<PickedResume>> pickResumeFiles() async {
  const group = XTypeGroup(
    label: 'Word',
    extensions: ['docx'],
    mimeTypes: [
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ],
  );
  final files = await openFiles(acceptedTypeGroups: const [group]);
  if (files.isEmpty) return const [];
  final picked = <PickedResume>[];
  for (final file in files) {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    picked.add(PickedResume(name: file.name, bytes: bytes));
  }
  return picked;
}
