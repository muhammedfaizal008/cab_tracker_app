import 'package:cab_tracker_app/controllers/export_helper.dart' as export_helper;
import 'package:cab_tracker_app/helpers/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';


class AttendanceController with ChangeNotifier {
  final Map<DateTime, Attendance> _attendanceRecords = {};

  double _constFarePerTrip = 0;

  double get constFarePerTrip => _constFarePerTrip;

  // Get total records count
  int get totalRecords => _attendanceRecords.length;

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
      debugPrint('Error loading fare per trip: $e');
    }
  }

  Future<void> updateFarePerTrip(double newFare) async {
    try {
      _constFarePerTrip = newFare;
      await DatabaseHelper.instance.setConstFarePerTrip(newFare);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating fare per trip: $e');
    }
  }

  Attendance getAttendanceForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _attendanceRecords.putIfAbsent(
      normalizedDate,
      () => Attendance(date: normalizedDate),
    );
  }

  /// Whether the given date counts as a working day (Mon-Fri).
  bool isWorkingDay(DateTime date) {
    return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
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

  /// Get monthly statistics. Weekends are always excluded since they are
  /// not working days.
  Map<String, int> getMonthlyStats({DateTime? forMonth}) {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    int totalMorningTrips = 0;
    int totalEveningTrips = 0;
    int totalWorkingDays = 0;
    int daysCabUsed = 0;

    for (DateTime date = firstDayOfMonth;
        !date.isAfter(lastDayOfMonth);
        date = date.add(const Duration(days: 1))) {
      if (!isWorkingDay(date)) continue;

      totalWorkingDays++;
      final attendance = getAttendanceForDate(date);

      if (attendance.morningCabUsed) totalMorningTrips++;
      if (attendance.eveningCabUsed) totalEveningTrips++;
      if (attendance.morningCabUsed || attendance.eveningCabUsed) {
        daysCabUsed++;
      }
    }

    return {
      'totalMorningTrips': totalMorningTrips,
      'totalEveningTrips': totalEveningTrips,
      'totalTrips': totalMorningTrips + totalEveningTrips,
      'totalWorkingDays': totalWorkingDays,
      'daysCabUsed': daysCabUsed,
    };
  }

  /// Convenience wrapper that adds fare totals to [getMonthlyStats].
  /// Use this from the UI for the month summary card.
  Map<String, dynamic> getMonthSummary({DateTime? forMonth}) {
    final stats = getMonthlyStats(forMonth: forMonth);
    final totalTrips = stats['totalTrips']!;
    final totalFare = totalTrips * _constFarePerTrip;

    return {
      ...stats,
      'totalFare': totalFare,
      'farePerTrip': _constFarePerTrip,
    };
  }

  /// Get all attendance records for a specific month (includes every day,
  /// weekends included, since this is used for calendar rendering).
  List<Attendance> getMonthlyAttendance({DateTime? forMonth}) {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    List<Attendance> monthlyRecords = [];

    for (DateTime date = firstDayOfMonth;
        !date.isAfter(lastDayOfMonth);
        date = date.add(const Duration(days: 1))) {
      monthlyRecords.add(getAttendanceForDate(date));
    }

    return monthlyRecords;
  }

  /// Check if user has any cab usage for a specific month (working days only).
  bool hasAnyUsageInMonth({DateTime? forMonth}) {
    final targetMonth = forMonth ?? DateTime.now();
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    for (DateTime date = firstDayOfMonth;
        !date.isAfter(lastDayOfMonth);
        date = date.add(const Duration(days: 1))) {
      if (!isWorkingDay(date)) continue;
      final record = getAttendanceForDate(date);
      if (record.morningCabUsed || record.eveningCabUsed) return true;
    }
    return false;
  }

  /// Generates the monthly Excel report.
  ///
  /// Weekends are excluded by default since they are not working days.
  /// Pass [includeWeekends] = true to include them anyway.
  Future<Map<String, dynamic>> generateMonthlyReport({
    DateTime? forMonth,
    bool includeWeekends = false,
  }) async {
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
      final whiteColor = ExcelColor.fromHexString('#FFFFFF');

      final columnCount = includeWeekends ? 7 : 6;
      final lastColIndex = columnCount - 1;

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
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: lastColIndex, rowIndex: 0),
      );

      // === REPORT INFO ===
      int currentRow = 2;

      _addInfoRow(sheet, currentRow++, 'Report Period:', DateFormat('MMMM yyyy').format(targetMonth));
      _addInfoRow(sheet, currentRow++, 'Generated On:', DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()));
      _addInfoRow(sheet, currentRow++, 'Rate Per Trip:', '₹${farePerTrip.toStringAsFixed(2)}');
      _addInfoRow(sheet, currentRow++, 'Includes Weekends:', includeWeekends ? 'Yes' : 'No');

      currentRow++; // Blank row

      // === DATA TABLE HEADERS ===
      final headers = includeWeekends
          ? ['Date', 'Day', 'Type', 'Morning', 'Evening', 'Daily Trips', 'Daily Fare (₹)']
          : ['Date', 'Day', 'Morning', 'Evening', 'Daily Trips', 'Daily Fare (₹)'];

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
      int daysCabUsed = 0;

      for (DateTime date = firstDayOfMonth;
          !date.isAfter(lastDayOfMonth);
          date = date.add(const Duration(days: 1))) {
        final isWeekend = !isWorkingDay(date);
        if (isWeekend && !includeWeekends) continue;

        final record = getAttendanceForDate(date);

        final morning = record.morningCabUsed;
        final evening = record.eveningCabUsed;
        final trips = (morning ? 1 : 0) + (evening ? 1 : 0);
        final fare = trips * farePerTrip;

        totalTrips += trips;
        totalFare += fare;
        if (morning) morningTrips++;
        if (evening) eveningTrips++;
        if (trips > 0) daysCabUsed++;

        if (isWeekend) {
          weekendDays++;
        } else {
          workingDays++;
        }

        int col = 0;

        // Date
        final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        dateCell.value = TextCellValue(DateFormat('dd-MM-yyyy').format(date));
        dateCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
        );
        col++;

        // Day
        final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        dayCell.value = TextCellValue(DateFormat('EEEE').format(date));
        dayCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          bold: isWeekend,
        );
        col++;

        // Type (only if weekends included)
        if (includeWeekends) {
          final typeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
          typeCell.value = TextCellValue(isWeekend ? 'Weekend' : 'Working');
          typeCell.cellStyle = CellStyle(
            backgroundColorHex: isWeekend ? weekendColor : whiteColor,
            fontSize: 9,
          );
          col++;
        }

        // Morning
        final morningCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        morningCell.value = TextCellValue(morning ? '✓' : '—');
        morningCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: morning ? ExcelColor.fromHexString('#27AE60') : ExcelColor.fromHexString('#95A5A6'),
          bold: morning,
        );
        col++;

        // Evening
        final eveningCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        eveningCell.value = TextCellValue(evening ? '✓' : '—');
        eveningCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: evening ? ExcelColor.fromHexString('#27AE60') : ExcelColor.fromHexString('#95A5A6'),
          bold: evening,
        );
        col++;

        // Trips
        final tripsCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        tripsCell.value = IntCellValue(trips);
        tripsCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Center,
          bold: trips > 0,
        );
        col++;

        // Fare
        final fareCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        fareCell.value = DoubleCellValue(fare);
        fareCell.cellStyle = CellStyle(
          backgroundColorHex: isWeekend ? weekendColor : whiteColor,
          horizontalAlign: HorizontalAlign.Right,
        );

        currentRow++;
      }

      currentRow++; // Blank row

      // === SUMMARY SECTION ===
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
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        CellIndex.indexByColumnRow(columnIndex: lastColIndex, rowIndex: currentRow),
      );
      currentRow++;

      // Summary Data
      _addSummaryRow(sheet, currentRow++, 'Total Working Days:', workingDays.toString(), ExcelColor.fromHexString('#E8F8F5'), lastColIndex);
      if (includeWeekends) {
        _addSummaryRow(sheet, currentRow++, 'Total Weekend Days:', weekendDays.toString(), ExcelColor.fromHexString('#E8F8F5'), lastColIndex);
      }
      _addSummaryRow(sheet, currentRow++, 'Days Cab Used:', daysCabUsed.toString(), ExcelColor.fromHexString('#E8F8F5'), lastColIndex);
      _addSummaryRow(sheet, currentRow++, 'Morning Trips:', morningTrips.toString(), ExcelColor.fromHexString('#E8F8F5'), lastColIndex);
      _addSummaryRow(sheet, currentRow++, 'Evening Trips:', eveningTrips.toString(), ExcelColor.fromHexString('#E8F8F5'), lastColIndex);
      currentRow++; // Blank row

      // Grand Total
      _addTotalRow(sheet, currentRow++, 'TOTAL TRIPS:', totalTrips.toString(), ExcelColor.fromHexString('#D5F4E6'), lastColIndex);
      _addTotalRow(sheet, currentRow++, 'TOTAL FARE:', '₹${totalFare.toStringAsFixed(2)}', ExcelColor.fromHexString('#D5F4E6'), lastColIndex);

      currentRow++; // Blank row

      // Statistics
      final avgPerDay = workingDays > 0 ? totalTrips / workingDays : 0;
      final avgFarePerDay = workingDays > 0 ? totalFare / workingDays : 0;

      _addSummaryRow(sheet, currentRow++, 'Avg Trips/Day:', avgPerDay.toStringAsFixed(2), ExcelColor.fromHexString('#FEF5E7'), lastColIndex);
      _addSummaryRow(sheet, currentRow++, 'Avg Fare/Day:', '₹${avgFarePerDay.toStringAsFixed(2)}', ExcelColor.fromHexString('#FEF5E7'), lastColIndex);

      // Set column widths
      sheet.setColumnWidth(0, 15); // Date
      sheet.setColumnWidth(1, 12); // Day
      int idx = 2;
      if (includeWeekends) {
        sheet.setColumnWidth(idx, 10); // Type
        idx++;
      }
      sheet.setColumnWidth(idx++, 10); // Morning
      sheet.setColumnWidth(idx++, 10); // Evening
      sheet.setColumnWidth(idx++, 12); // Trips
      sheet.setColumnWidth(idx++, 15); // Fare

      // Encode and export
      final bytes = excel.encode()!;
      final fileName = 'Cab_Report_${DateFormat('MMM_yyyy').format(targetMonth)}.xlsx';

      // Request storage permission on mobile platforms (handled inside the
      // platform-specific export helper for web vs io).
      final permissionResult = await _requestExportPermissionIfNeeded();
      if (permissionResult != null) return permissionResult;

      final exportResult = await export_helper.writeReportBytes(bytes, fileName);

      return {
        ...exportResult,
        'stats': {
          'totalWorkingDays': workingDays,
          'totalWeekendDays': weekendDays,
          'daysCabUsed': daysCabUsed,
          'totalMorningTrips': morningTrips,
          'totalEveningTrips': eveningTrips,
          'totalTrips': totalTrips,
          'totalFare': totalFare,
          'avgTripsPerDay': avgPerDay,
          'avgFarePerDay': avgFarePerDay,
        },
      };
    } catch (e, stack) {
      debugPrint('Error generating report: $e\n$stack');
      return {'success': false, 'error': 'Failed to generate report: $e'};
    }
  }

  /// Requests storage permission on Android/iOS only. Returns an error map
  /// if permission was denied, or null if it's fine to proceed (web and
  /// other platforms don't need this).
  Future<Map<String, dynamic>?> _requestExportPermissionIfNeeded() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        return {'success': false, 'error': 'Storage permission is required to save the report.'};
      }
    }
    return null;
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
  void _addSummaryRow(Sheet sheet, int row, String label, String value, ExcelColor bgColor, int lastColIndex) {
    final labelEnd = (lastColIndex - 2).clamp(0, lastColIndex);

    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, backgroundColorHex: bgColor);
    if (labelEnd > 0) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: labelEnd, rowIndex: row),
      );
    }

    final valueStart = (labelEnd + 1).clamp(0, lastColIndex);
    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: valueStart, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(bold: true, backgroundColorHex: bgColor, horizontalAlign: HorizontalAlign.Center);
    if (valueStart < lastColIndex) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: valueStart, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: lastColIndex, rowIndex: row),
      );
    }
  }

  // Helper method to add total rows
  void _addTotalRow(Sheet sheet, int row, String label, String value, ExcelColor bgColor, int lastColIndex) {
    final labelEnd = (lastColIndex - 2).clamp(0, lastColIndex);

    final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, fontSize: 12, backgroundColorHex: bgColor);
    if (labelEnd > 0) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: labelEnd, rowIndex: row),
      );
    }

    final valueStart = (labelEnd + 1).clamp(0, lastColIndex);
    final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: valueStart, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(bold: true, fontSize: 12, backgroundColorHex: bgColor, horizontalAlign: HorizontalAlign.Center);
    if (valueStart < lastColIndex) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: valueStart, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: lastColIndex, rowIndex: row),
      );
    }
  }

  // Share the generated report
  Future<void> shareReport(String filePath, {String? customMessage}) async {
    try {
      if (kIsWeb) {
        // Sharing a file path doesn't apply on web; the file is already
        // downloaded via the browser by export_helper_web.dart.
        return;
      }
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
}