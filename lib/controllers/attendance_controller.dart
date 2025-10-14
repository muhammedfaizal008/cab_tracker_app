import 'dart:typed_data';

import 'package:cab_tracker_app/helpers/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/attendance_model.dart';
// Conditional imports
import 'dart:io' show File, Platform;
import 'dart:html' as html;

class AttendanceController with ChangeNotifier {
  final Map<DateTime, Attendance> _attendanceRecords = {};

  double _constFarePerTrip = 0;

  double get constFarePerTrip => _constFarePerTrip;


  Future<void> loadAllRecords() async {
  final records = await DatabaseHelper.instance.getAllTrips();
  _attendanceRecords.clear();
  for (var record in records) {
    final dateParts = record['date'].toString().split('-'); // yyyy-MM-dd
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    _attendanceRecords[date] = Attendance(
      date: date,
      morningCabUsed: record['morningCabUsed'] == 1,
      eveningCabUsed: record['eveningCabUsed'] == 1,
    );
  }
  notifyListeners();
}

  Future<void> loadFarePerTrip() async {
  try {
    final fare = await DatabaseHelper.instance.getConstFarePerTrip();
    _constFarePerTrip = fare ?? 0;
    notifyListeners();
  } catch (e) {
    print('Error loading fare per trip: $e');
  }
}

Future<void> updateFarePerTrip(double newFare) async {
  try {
    _constFarePerTrip = newFare;
    await DatabaseHelper.instance.setConstFarePerTrip(newFare);
    notifyListeners();
  } catch (e) {
    print('Error updating fare per trip: $e');
  }
}



  Attendance getAttendanceForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _attendanceRecords.putIfAbsent(
      normalizedDate,
      () => Attendance(date: normalizedDate),
    );
  }

  Future<void> updateMorningCabUsage(DateTime date, bool cabUsed) async {

      final normalizedDate = DateTime(date.year, date.month, date.day);
  final attendance = getAttendanceForDate(normalizedDate);
  final updatedAttendance = attendance.copyWith(morningCabUsed: cabUsed);
  _attendanceRecords[normalizedDate] = updatedAttendance;

  await DatabaseHelper.instance.insertOrUpdateTrip({
    'date': DateFormat('yyyy-MM-dd').format(normalizedDate),
    'morningCabUsed': updatedAttendance.morningCabUsed ? 1 : 0,
    'eveningCabUsed': updatedAttendance.eveningCabUsed ? 1 : 0,
  });

  notifyListeners();

  }

  Future<void> updateEveningCabUsage(DateTime date, bool cabUsed) async {

      final normalizedDate = DateTime(date.year, date.month, date.day);
  final attendance = getAttendanceForDate(normalizedDate);
  final updatedAttendance = attendance.copyWith(eveningCabUsed: cabUsed);
  _attendanceRecords[normalizedDate] = updatedAttendance;

  await DatabaseHelper.instance.insertOrUpdateTrip({
    'date': DateFormat('yyyy-MM-dd').format(normalizedDate),
    'morningCabUsed': updatedAttendance.morningCabUsed ? 1 : 0,
    'eveningCabUsed': updatedAttendance.eveningCabUsed ? 1 : 0,
  });

  notifyListeners();

  }
  

  // Get monthly statistics
  Map<String, int> getMonthlyStats({DateTime? forMonth}) {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    
    int totalMorningTrips = 0;
    int totalEveningTrips = 0;
    int totalWorkingDays = 0;
    
    for (DateTime date = firstDayOfMonth; 
         date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      
      // Skip weekends (optional - remove if you track weekends too)
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        continue;
      }
      
      totalWorkingDays++;
      final attendance = getAttendanceForDate(date);
      
      if (attendance.morningCabUsed) totalMorningTrips++;
      if (attendance.eveningCabUsed) totalEveningTrips++;
    }
    
    return {
      'totalMorningTrips': totalMorningTrips,
      'totalEveningTrips': totalEveningTrips,
      'totalTrips': totalMorningTrips + totalEveningTrips,
      'totalWorkingDays': totalWorkingDays,
    };
  }

  // Get all attendance records for a specific month
  List<Attendance> getMonthlyAttendance({DateTime? forMonth}) {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    
    List<Attendance> monthlyRecords = [];
    
    for (DateTime date = firstDayOfMonth; 
         date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      
      monthlyRecords.add(getAttendanceForDate(date));
    }
    
    return monthlyRecords;
  }


Future<Map<String, dynamic>> generateMonthlyReport({
  DateTime? forMonth,
  bool includeWeekends = true,
}) async {
  try {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    final farePerTrip = _constFarePerTrip;

    var excel = Excel.createExcel();
    excel.rename('Sheet1', 'Attendance Report');
    var sheet = excel['Attendance Report'];

    // Headers
    final headers = ['Date', 'Day', 'Morning', 'Evening', 'Trips', 'Fare'];
    for (int i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }

    int totalTrips = 0;
    double totalFare = 0;
    int rowIndex = 1;

    for (DateTime date = firstDayOfMonth;
        date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      
      bool isWeekend = date.weekday == DateTime.sunday;
      if (!includeWeekends && isWeekend) continue;

      // ✅ Safely get record
      final record = _attendanceRecords[DateTime(date.year, date.month, date.day)] ??
          Attendance(date: date, morningCabUsed: false, eveningCabUsed: false);

      final morning = record.morningCabUsed;
      final evening = record.eveningCabUsed;
      final trips = (morning ? 1 : 0) + (evening ? 1 : 0);
      final fare = trips * farePerTrip;

      totalTrips += trips;
      totalFare += fare;

      // ✅ Write to Excel
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(DateFormat('dd-MM-yyyy').format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(DateFormat('EEEE').format(date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(morning ? 'Yes' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(evening ? 'Yes' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = IntCellValue(trips);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = DoubleCellValue(fare);

      rowIndex++;
    }

    // Totals
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex + 1))
        .value = TextCellValue('Total');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex + 1))
        .value = IntCellValue(totalTrips);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex + 1))
        .value = DoubleCellValue(totalFare);

    // Encode and export
    final bytes = excel.encode()!;
    final fileName =
        'Attendance_Report_${DateFormat('MMM_yyyy').format(targetMonth)}.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      return {
        'success': true,
        'filePath': 'Downloaded via browser',
        'fileName': fileName,
      };
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          return {
            'success': false,
            'error': 'Storage permission is required to save the report.',
          };
        }
      }

      final directory =
          await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return {
        'success': true,
        'filePath': filePath,
        'fileName': fileName,
      };
    }
  } catch (e, stack) {
    debugPrint('❌ Error generating report: $e\n$stack');
    return {
      'success': false,
      'error': 'Failed to generate report: $e',
    };
  }
}




  // Share the generated report
  Future<void> shareReport(String filePath, {String? customMessage}) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)], 
        text: customMessage ?? 'Monthly Attendance Report',
      );
    } catch (e) {
      throw Exception('Failed to share report: $e');
    }
  }

  Future<void> clearAllRecords() async {
  _attendanceRecords.clear();
  await DatabaseHelper.instance.clearAllTrips();
  notifyListeners();
}


  // Get total records count
  int get totalRecords => _attendanceRecords.length;

  // Check if user has any cab usage for a specific month
  bool hasAnyUsageInMonth({DateTime? forMonth}) {
    final monthlyRecords = getMonthlyAttendance(forMonth: forMonth);
    return monthlyRecords.any((record) => 
        record.morningCabUsed || record.eveningCabUsed);
  }
}