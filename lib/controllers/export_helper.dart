// TODO Implement this library.
import 'dart:html' as html;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Triggers a browser download of the report bytes.
/// Used on web builds.
Future<Map<String, dynamic>> writeReportBytes(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  return {'success': true, 'filePath': 'Downloaded via browser', 'fileName': fileName};
}


