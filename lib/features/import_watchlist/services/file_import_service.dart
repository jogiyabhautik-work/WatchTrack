import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class FileImportResult {
  final List<String> rawTitles;
  final String fileName;
  final String? error;

  FileImportResult({this.rawTitles = const [], this.fileName = '', this.error});
}

class FileImportService {
  /// Picks a file (.txt, .csv) and extracts non-empty lines/rows.
  static Future<FileImportResult> pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return FileImportResult(error: 'No file selected.');
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final extension = result.files.single.extension?.toLowerCase();

      List<String> extractedTitles = [];

      if (extension == 'csv') {
        final csvString = await file.readAsString();
        List<List<dynamic>> rowsAsListOfValues = Csv().decode(csvString);
        
        // Extract the first non-empty column from each row
        for (var row in rowsAsListOfValues) {
          if (row.isNotEmpty) {
            String potentialTitle = row.first.toString().trim();
            if (potentialTitle.isNotEmpty) {
              extractedTitles.add(potentialTitle);
            }
          }
        }
      } else if (extension == 'txt') {
        final lines = await file.readAsLines();
        for (var line in lines) {
          String potentialTitle = line.trim();
          if (potentialTitle.isNotEmpty) {
            extractedTitles.add(potentialTitle);
          }
        }
      } else {
        return FileImportResult(error: 'Unsupported file format.');
      }

      // Deduplicate
      extractedTitles = extractedTitles.toSet().toList();

      if (extractedTitles.isEmpty) {
        return FileImportResult(error: 'File is empty or contains no valid text.');
      }

  // ... existing code in file_import_service.dart
      return FileImportResult(rawTitles: extractedTitles, fileName: fileName);
    } catch (e) {
      return FileImportResult(error: 'Failed to read file: ${e.toString()}');
    }
  }

  /// Parses a raw text string by splitting it into lines and extracting non-empty lines.
  static Future<FileImportResult> parseText(String text) async {
    try {
      if (text.trim().isEmpty) {
        return FileImportResult(error: 'Text is empty.');
      }

      final lines = text.split(RegExp(r'\r?\n'));
      List<String> extractedTitles = [];

      for (var line in lines) {
        String potentialTitle = line.trim();
        if (potentialTitle.isNotEmpty) {
          extractedTitles.add(potentialTitle);
        }
      }

      // Deduplicate
      extractedTitles = extractedTitles.toSet().toList();

      if (extractedTitles.isEmpty) {
        return FileImportResult(error: 'Text contains no valid titles.');
      }

      return FileImportResult(rawTitles: extractedTitles, fileName: 'Pasted Text');
    } catch (e) {
      return FileImportResult(error: 'Failed to parse text: ${e.toString()}');
    }
  }
}
