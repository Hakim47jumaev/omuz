import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveResumePdf(Uint8List bytes, int id) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/resume_$id.pdf';
  await File(path).writeAsBytes(bytes);
  return path;
}
