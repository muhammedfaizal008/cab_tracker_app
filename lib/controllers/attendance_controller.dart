import 'package:cab_tracker_app/helpers/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/attendance_model.dart';

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

  // Generate and save monthly Excel report
Future<Map<String, dynamic>> generateMonthlyReport({
  DateTime? forMonth,
  bool includeWeekends = true,
}) async {
  try {
    // Request storage permission
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      return {
        'success': false,
        'error': 'Storage permission is required to save the report.',
      };
    }

    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    final farePerTrip = _constFarePerTrip; // <-- get fare per trip

    // Create Excel workbook
    var excel = Excel.createExcel();
    excel.rename('Sheet1', 'Attendance Report');
    var sheet = excel['Attendance Report'];

    // Set headers
    final headers = ['Date', 'Day', 'Morning Trip', 'Evening Trip', 'Total Trips'];
    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    int rowIndex = 1;
    int totalMorningTrips = 0;
    int totalEveningTrips = 0;
    int totalWorkingDays = 0;

    // Generate daily rows
    for (DateTime date = firstDayOfMonth;
        date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      if (!includeWeekends &&
          (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)) {
        continue;
      }

      final attendance = getAttendanceForDate(date);
      final morningUsed = attendance.morningCabUsed;
      final eveningUsed = attendance.eveningCabUsed;
      final dailyTotal = (morningUsed ? 1 : 0) + (eveningUsed ? 1 : 0);

      if (morningUsed) totalMorningTrips++;
      if (eveningUsed) totalEveningTrips++;
      totalWorkingDays++;

      // Fill cells
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(DateFormat('dd-MM-yyyy').format(date));

      var dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      dayCell.value = TextCellValue(DateFormat('EEEE').format(date));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        dayCell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.grey200);
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
        ..value = TextCellValue(morningUsed ? 'Yes' : 'No')
        ..cellStyle = CellStyle(
            backgroundColorHex: morningUsed ? ExcelColor.lightGreen : ExcelColor.none,
            horizontalAlign: HorizontalAlign.Center);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        ..value = TextCellValue(eveningUsed ? 'Yes' : 'No')
        ..cellStyle = CellStyle(
            backgroundColorHex: eveningUsed ? ExcelColor.lightGreen : ExcelColor.none,
            horizontalAlign: HorizontalAlign.Center);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
        ..value = IntCellValue(dailyTotal)
        ..cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

      rowIndex++;
    }

    // Summary
    rowIndex += 2;
    var summaryHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    summaryHeaderCell.value = TextCellValue('MONTHLY SUMMARY');
    summaryHeaderCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
      fontSize: 14,
    );
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
    rowIndex += 2;

    final totalTrips = totalMorningTrips + totalEveningTrips;
    final totalCost = totalTrips * farePerTrip;

    final summaryData = [
      ['Total Working Days:', totalWorkingDays],
      ['Total Morning Trips:', totalMorningTrips],
      ['Total Evening Trips:', totalEveningTrips],
      ['Total Trips:', totalTrips],
      ['Fare Per Trip:', '₹$farePerTrip'],
      ['Total Cost:', '₹$totalCost'],
      ['Morning Usage %:', totalWorkingDays > 0
          ? '${((totalMorningTrips / totalWorkingDays) * 100).toStringAsFixed(1)}%' : '0%'],
      ['Evening Usage %:', totalWorkingDays > 0
          ? '${((totalEveningTrips / totalWorkingDays) * 100).toStringAsFixed(1)}%' : '0%'],
    ];

    for (var data in summaryData) {
      var labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      labelCell.value = TextCellValue(data[0].toString());
      labelCell.cellStyle = CellStyle(bold: true);

      var valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      valueCell.value = TextCellValue(data[1].toString());
      valueCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

      rowIndex++;
    }

    // Timestamp
    rowIndex += 2;
    var timestampCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    timestampCell.value = TextCellValue(
      'Report Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}'
    );
    timestampCell.cellStyle = CellStyle(italic: true, fontColorHex: ExcelColor.grey);


    // Save file
    final directory = await getExternalStorageDirectory();
    final fileName = 'Attendance_Report_${DateFormat('MMM_yyyy').format(targetMonth)}.xlsx';
    final filePath = '${directory?.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return {
      'success': true,
      'filePath': filePath,
      'fileName': fileName,
      'stats': {
        'totalWorkingDays': totalWorkingDays,
        'totalMorningTrips': totalMorningTrips,
        'totalEveningTrips': totalEveningTrips,
        'totalTrips': totalTrips,
        'totalCost': totalCost,
      }
    };
  } catch (e) {
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