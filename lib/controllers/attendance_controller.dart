import 'package:cab_tracker_app/helpers/database_helper.dart';
import 'package:flutter/foundation.dart';
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
      final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
      _attendanceRecords[date] = Attendance(date: date, morningCabUsed: record['morningCabUsed'] == 1, eveningCabUsed: record['eveningCabUsed'] == 1);
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
    return _attendanceRecords.putIfAbsent(normalizedDate, () => Attendance(date: normalizedDate));
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

    for (DateTime date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
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

    for (DateTime date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      monthlyRecords.add(getAttendanceForDate(date));
    }

    return monthlyRecords;
  }

  Future<Map<String, dynamic>> generateMonthlyReport({DateTime? forMonth, bool includeWeekends = true}) async {
    try {
      final targetMonth = forMonth ?? DateTime.now();
      final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
      final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      final farePerTrip = _constFarePerTrip;

      var excel = Excel.createExcel();
      excel.rename('Sheet1', 'Report');
      var sheet = excel['Report'];

      // Define colors
      final headerColor = ExcelColor.fromHexString('#2C3E50');
      final summaryColor = ExcelColor.fromHexString('#34495E');
      final weekendColor = ExcelColor.fromHexString('#ECF0F1');
      final totalColor = ExcelColor.fromHexString('#E8F8F5');
      final whiteColor = ExcelColor.fromHexString('#FFFFFF');

      // === TITLE SECTION ===
      final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('CAB USAGE REPORT');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: headerColor,
        horizontalAlign: HorizontalAlign.Center,
      );
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0));

      // === REPORT INFO ===
      int currentRow = 2;

      _addInfoRow(sheet, currentRow++, 'Report Period:', DateFormat('MMMM yyyy').format(targetMonth));
      _addInfoRow(sheet, currentRow++, 'Generated On:', DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()));
      _addInfoRow(sheet, currentRow++, 'Rate Per Trip:', '₹${farePerTrip.toStringAsFixed(2)}');

      currentRow++; // Blank row

      // === DATA TABLE HEADERS ===
      final headers = ['Date', 'Day', 'Type', 'Morning', 'Evening', 'Daily Trips', 'Daily Fare (₹)'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 11,
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: headerColor,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      currentRow++;

      // === DATA ROWS ===
      int totalTrips = 0;
      double totalFare = 0;
      int workingDays = 0;
      int weekendDays = 0;
      int morningTrips = 0;
      int eveningTrips = 0;

      for (DateTime date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
        if (!includeWeekends && isWeekend) continue;

        final record =
            _attendanceRecords[DateTime(date.year, date.month, date.day)] ?? Attendance(date: date, morningCabUsed: false, eveningCabUsed: false);

        final morning = record.morningCabUsed;
        final evening = record.eveningCabUsed;
        final trips = (morning ? 1 : 0) + (evening ? 1 : 0);
        final fare = trips * farePerTrip;

        totalTrips += trips;
        totalFare += fare;
        if (morning) morningTrips++;
        if (evening) eveningTrips++;

        if (isWeekend) {
          weekendDays++;
        } else {
          workingDays++;
        }

        // Date
        final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        dateCell.value = TextCellValue(DateFormat('dd-MM-yyyy').format(date));
        dateCell.cellStyle = CellStyle(backgroundColorHex: isWeekend ? weekendColor : whiteColor, horizontalAlign: HorizontalAlign.Center);

        // Day
        final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
        dayCell.value = TextCellValue(DateFormat('EEEE').format(date));
        dayCell.cellStyle = CellStyle(backgroundColorHex: isWeekend ? weekendColor : whiteColor, bold: isWeekend);

        // Type
        final typeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
        typeCell.value = TextCellValue(isWeekend ? 'Weekend' : 'Working');
        typeCell.cellStyle = CellStyle(backgroundColorHex: isWeekend ? weekendColor : whiteColor, fontSize: 9);

        // Morning
        final morningCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
        morningCell.value = TextCellValue(morning ? '✓' : '—');
        morningCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: morning ? ExcelColor.fromHexString('#27AE60') : ExcelColor.fromHexString('#95A5A6'),
          bold: morning,
        );

        // Evening
        final eveningCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
        eveningCell.value = TextCellValue(evening ? '✓' : '—');
        eveningCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: evening ? ExcelColor.fromHexString('#27AE60') : ExcelColor.fromHexString('#95A5A6'),
          bold: evening,
        );

        // Trips
        final tripsCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
        tripsCell.value = IntCellValue(trips);
        tripsCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          bold: trips > 0,
        );

        // Fare
        final fareCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow));
        fareCell.value = DoubleCellValue(fare);
        fareCell.cellStyle = CellStyle(backgroundColorHex: isWeekend ? weekendColor : whiteColor, horizontalAlign: HorizontalAlign.Right);

        currentRow++;
      }

      currentRow++; // Blank row

      // === SUMMARY SECTION ===
      final summaryStart = currentRow;

      // Summary Title
      final summaryTitle = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      summaryTitle.value = TextCellValue('MONTHLY SUMMARY');
      summaryTitle.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: summaryColor,
        horizontalAlign: HorizontalAlign.Center,
      );
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow));
      currentRow++;

      // Summary Data
      _addSummaryRow(sheet, currentRow++, 'Total Working Days:', workingDays.toString(), totalColor);
      _addSummaryRow(sheet, currentRow++, 'Total Weekend Days:', weekendDays.toString(), totalColor);
      _addSummaryRow(sheet, currentRow++, 'Morning Trips:', morningTrips.toString(), totalColor);
      _addSummaryRow(sheet, currentRow++, 'Evening Trips:', eveningTrips.toString(), totalColor);
      currentRow++; // Blank row

      // Grand Total
      _addTotalRow(sheet, currentRow++, 'TOTAL TRIPS:', totalTrips.toString(), ExcelColor.fromHexString('#D5F4E6'));
      _addTotalRow(sheet, currentRow++, 'TOTAL FARE:', '₹${totalFare.toStringAsFixed(2)}', ExcelColor.fromHexString('#D5F4E6'));

      currentRow++; // Blank row

      // Statistics
      final avgPerDay = workingDays > 0 ? totalTrips / workingDays : 0;
      final avgFarePerDay = workingDays > 0 ? totalFare / workingDays : 0;

      _addSummaryRow(sheet, currentRow++, 'Avg Trips/Day:', avgPerDay.toStringAsFixed(2), ExcelColor.fromHexString('#FEF5E7'));
      _addSummaryRow(sheet, currentRow++, 'Avg Fare/Day:', '₹${avgFarePerDay.toStringAsFixed(2)}', ExcelColor.fromHexString('#FEF5E7'));

      // Set column widths
      sheet.setColumnWidth(0, 15); // Date
      sheet.setColumnWidth(1, 12); // Day
      sheet.setColumnWidth(2, 10); // Type
      sheet.setColumnWidth(3, 10); // Morning
      sheet.setColumnWidth(4, 10); // Evening
      sheet.setColumnWidth(5, 12); // Trips
      sheet.setColumnWidth(6, 15); // Fare

      // Encode and export
      final bytes = excel.encode()!;
      final fileName = 'Cab_Report_${DateFormat('MMM_yyyy').format(targetMonth)}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..click();
        html.Url.revokeObjectUrl(url);

        return {'success': true, 'filePath': 'Downloaded via browser', 'fileName': fileName};
      } else {
        if (Platform.isAndroid || Platform.isIOS) {
          var status = await Permission.storage.request();
          if (!status.isGranted) {
            return {'success': false, 'error': 'Storage permission is required to save the report.'};
          }
        }

        final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        return {'success': true, 'filePath': filePath, 'fileName': fileName};
      }
    } catch (e, stack) {
      debugPrint('❌ Error generating report: $e\n$stack');
      return {'success': false, 'error': 'Failed to generate report: $e'};
    }
  }

  // Helper method to add info rows
  void _addInfoRow(Sheet sheet, int row, String label, String value) {
    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, fontSize: 10);

    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(fontSize: 10);
  }

  // Helper method to add summary rows
  void _addSummaryRow(Sheet sheet, int row, String label, String value, ExcelColor bgColor) {
    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, backgroundColorHex: bgColor);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));

    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(bold: true, backgroundColorHex: bgColor, horizontalAlign: HorizontalAlign.Center);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
  }

  // Helper method to add total rows
  void _addTotalRow(Sheet sheet, int row, String label, String value, ExcelColor bgColor) {
    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, fontSize: 12, backgroundColorHex: bgColor);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));

    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(bold: true, fontSize: 12, backgroundColorHex: bgColor, horizontalAlign: HorizontalAlign.Center);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
  }

  // Share the generated report
  Future<void> shareReport(String filePath, {String? customMessage}) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: customMessage ?? 'Monthly Attendance Report');
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
    return monthlyRecords.any((record) => record.morningCabUsed || record.eveningCabUsed);
  }
}
