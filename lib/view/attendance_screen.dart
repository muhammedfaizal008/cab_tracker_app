import 'package:cab_tracker_app/controllers/attendance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ===== Shared color palette =====
const _kBg = Color(0xFFF8FAFC);
const _kGreen = Color(0xFF10B981); // both trips used
const _kOrange = Color(0xFFF59E0B); // morning only
const _kPurple = Color(0xFF8B5CF6); // evening only
const _kRed = Color(0xFFEF4444); // missed working day
const _kUpcoming = Color(0xFFCBD5E1); // upcoming / today, no data yet
const _kBlue = Color(0xFF3B82F6);
const _kSlate900 = Color(0xFF1E293B);
const _kSlate700 = Color(0xFF334155);
const _kSlate500 = Color(0xFF64748B);

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late TextEditingController _fareController;
  bool _isEditingFare = false;

  OverlayEntry? _popupOverlayEntry;
  GlobalKey<_StatusSelectionPopupState>? _popupKey;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fareController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptCabUsage();
    });
  }

  @override
  void dispose() {
    _popupOverlayEntry?.remove();
    _popupOverlayEntry = null;
    _fareController.dispose();
    super.dispose();
  }

  // ===================================================================
  // Cab usage prompt
  // ===================================================================

  void _checkAndPromptCabUsage() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final attendanceController = Provider.of<AttendanceController>(context, listen: false);
    if (!attendanceController.isWorkingDay(today)) return;

    final attendance = attendanceController.getAttendanceForDate(today);

    // Morning: e.g., between 6AM and 11AM
    if (now.hour >= 6 && now.hour <= 11 && attendance.morningCabUsed == false) {
      _showCabUsageDialog(isMorning: true);
    }
    // Evening: e.g., between 4PM and 8PM
    else if (now.hour >= 15 && now.hour <= 20 && attendance.eveningCabUsed == false) {
      _showCabUsageDialog(isMorning: false);
    }
  }

  Future<void> _showCabUsageDialog({required bool isMorning}) async {
    final attendanceController = Provider.of<AttendanceController>(context, listen: false);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    size: 40,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cab Service',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMorning ? Colors.orange.shade50 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMorning ? Colors.orange.shade200 : Colors.indigo.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMorning ? Icons.wb_sunny : Icons.nightlight_round,
                        size: 16,
                        color: isMorning ? Colors.orange.shade600 : Colors.indigo.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMorning ? 'Morning Trip' : 'Evening Trip',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isMorning ? Colors.orange.shade600 : Colors.indigo.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Will you be using the cab service for your ${isMorning ? 'morning' : 'evening'} commute today?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            side: BorderSide(color: Colors.red.shade300, width: 2),
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'No, Thanks',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: _kGreen.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Yes, I Will',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap outside to decide later',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return; // dismissed without choosing, ask again later

    final today = DateTime.now();
    if (isMorning) {
      attendanceController.updateMorningCabUsage(today, result);
    } else {
      attendanceController.updateEveningCabUsage(today, result);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result ? Icons.check_circle : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result
                    ? 'Cab usage recorded for ${isMorning ? 'morning' : 'evening'} trip'
                    : 'Got it — no cab for ${isMorning ? 'morning' : 'evening'} trip',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: result ? _kGreen : _kSlate500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===================================================================
  // Calendar callbacks
  // ===================================================================

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  // ===================================================================
  // Report generation
  // ===================================================================

  Future<void> _generateMonthlyReport(AttendanceController controller) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text('Generating report...', style: GoogleFonts.poppins()),
            ],
          ),
        ),
      );

      final result = await controller.generateMonthlyReport(forMonth: _focusedDay);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        _showSuccessDialog(
          result['filePath'],
          result['fileName'],
          (result['stats'] as Map<String, dynamic>?) ?? const {},
        );
      } else {
        _showErrorDialog(result['error']?.toString() ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('Failed to generate report: $e');
    }
  }

  void _showSuccessDialog(String filePath, String fileName, Map<String, dynamic> stats) {
    final totalFare = (stats['totalFare'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: _kGreen, size: 28),
            const SizedBox(width: 12),
            Text('Report Generated', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your monthly attendance report has been saved successfully!',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),

            if (stats.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Summary',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kSlate700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Working Days', '${stats['totalWorkingDays'] ?? 0}'),
                    _buildStatRow('Morning Trips', '${stats['totalMorningTrips'] ?? 0}'),
                    _buildStatRow('Evening Trips', '${stats['totalEveningTrips'] ?? 0}'),
                    _buildStatRow('Total Trips', '${stats['totalTrips'] ?? 0}'),
                    _buildStatRow('Total Fare', '₹${totalFare.toStringAsFixed(2)}'),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: _kSlate500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final result = await OpenFilex.open(filePath);
                        if (result.type != ResultType.done) {
                          _showErrorDialog('Could not open file: ${result.message}');
                        }
                      },
                      child: Text(
                        fileName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: _kSlate500, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final controller = Provider.of<AttendanceController>(context, listen: false);
                await controller.shareReport(filePath);
              } catch (e) {
                _showErrorDialog('Failed to share report: $e');
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text('Share', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _kSlate500)),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate700),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error, color: _kRed, size: 28),
              const SizedBox(width: 12),
              Text('Error', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(message, style: GoogleFonts.poppins()),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );
  }

  // ===================================================================
  // Build
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final attendanceController = Provider.of<AttendanceController>(context);
    final selectedDateAttendance = _selectedDay != null
        ? attendanceController.getAttendanceForDate(_selectedDay!)
        : null;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Attendance Tracker',
          style: GoogleFonts.poppins(
            color: _kSlate900,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _generateMonthlyReport(attendanceController),
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                'Report',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TableCalendar(
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                          _selectedDay = DateTime(focusedDay.year, focusedDay.month, 1);
                        });
                      },
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _kSlate900,
                        ),
                        leftChevronIcon: const Icon(Icons.chevron_left, color: _kSlate500, size: 28),
                        rightChevronIcon: const Icon(Icons.chevron_right, color: _kSlate500, size: 28),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kSlate500,
                        ),
                        weekendStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kSlate500,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kSlate700,
                        ),
                        weekendTextStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kSlate700,
                        ),
                        cellMargin: const EdgeInsets.all(4),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) => _buildDayCell(attendanceController, day),
                        todayBuilder: (context, day, focusedDay) => _buildDayCell(attendanceController, day, isToday: true),
                        selectedBuilder: (context, day, focusedDay) => _buildDayCell(attendanceController, day, isSelected: true),
                      ),
                    ),
                    const SizedBox(height: 12),
                     Divider(height: 1,color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    _buildLegend(),
                  ],
                ),
              ),
            ),

            // Monthly summary
            _buildMonthSummary(attendanceController),

            // Attendance Details
            if (_selectedDay != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cab Usage',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _kSlate900,
                          ),
                        ),
                        Text(
                          _selectedDayLabel(),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kSlate500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildFareCard(attendanceController),
                    const SizedBox(height: 16),

                    _buildCombinedTripCard(attendanceController, selectedDateAttendance),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Human-friendly label for the currently selected day, e.g.
  /// "Today", "Yesterday", or "Mon, 14 Jun".
  String _selectedDayLabel() {
    final day = _selectedDay!;
    final now = DateTime.now();
    if (isSameDay(day, now)) return 'Today';
    if (isSameDay(day, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  // ===================================================================
  // Sub-widgets
  // ===================================================================

  Widget _buildMonthSummary(AttendanceController controller) {
    final summary = controller.getMonthSummary(forMonth: _focusedDay);
    final totalTrips = summary['totalTrips'] as int;
    final totalFare = (summary['totalFare'] as num).toDouble();
    final workingDays = summary['totalWorkingDays'] as int;
    final daysCabUsed = summary['daysCabUsed'] as int;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kSlate500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryTile('Trips', '$totalTrips', Icons.directions_car_rounded, _kBlue)),
              Expanded(child: _summaryTile('Spent', '₹${totalFare.toStringAsFixed(0)}', Icons.currency_rupee_rounded, _kGreen)),
              Expanded(child: _summaryTile('Days Used', '$daysCabUsed/$workingDays', Icons.event_available_rounded, _kOrange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _kSlate900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: _kSlate500),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendItem(_kGreen, 'Both trips'),
            _legendItem(_kOrange, 'Morning only'),
            _legendItem(_kPurple, 'Evening only'),
            _legendItem(_kRed, 'Missed'),
            _legendItem(_kUpcoming, 'Upcoming'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 14, color: _kSlate500.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              'Long-press a day to cycle status',
              style: GoogleFonts.poppins(fontSize: 11, color: _kSlate500.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _kSlate500)),
      ],
    );
  }

  /// Builds a single calendar day cell. Weekends are shown in a neutral
  /// style since they are not working days and never count as "missed".
  Widget _buildDayCell(AttendanceController controller, DateTime day, {bool isToday = false, bool isSelected = false}) {
    final attendance = controller.getAttendanceForDate(day);
    final morning = attendance.morningCabUsed;
    final evening = attendance.eveningCabUsed;
    final isWorkingDay = controller.isWorkingDay(day);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPastDay = day.isBefore(today);

    Widget content;

    if (!isWorkingDay) {
      // Weekend — neutral, doesn't participate in the cab-usage color coding.
      content = Center(
        child: Text(
          '${day.day}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _kSlate500.withOpacity(0.6),
          ),
        ),
      );
    } else if (morning && evening) {
      content = _solidCircle(day, _kGreen, Colors.white);
    } else if (morning) {
      content = _splitCircle(day, leftColor: _kOrange, rightColor: const Color(0xFFF1F5F9), textColor: Colors.white);
    } else if (evening) {
      content = _splitCircle(day, leftColor: const Color(0xFFF1F5F9), rightColor: _kPurple, textColor: Colors.white, textOnLeft: false);
    } else if (isPastDay) {
      content = _solidCircle(day, _kRed, Colors.white);
    } else {
      content = _solidCircle(day, _kUpcoming, _kSlate700);
    }

    // Today gets an outline ring; selected gets a blue gradient ring.
    BoxBorder? border;
    if (isSelected) {
      border = Border.all(color: _kBlue, width: 2.5);
    } else if (isToday) {
      border = Border.all(color: _kBlue.withOpacity(0.5), width: 2);
    }

    if (border == null) {
      content = Center(
        child: SizedBox(width: 36, height: 36, child: content),
      );
    } else {
      content = Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, border: border),
          child: Center(child: SizedBox(width: 34, height: 34, child: content)),
        ),
      );
    }

    if (!isWorkingDay) return content;

    return GestureDetector(
      onLongPressStart: (details) {
        _showStatusPopup(context, details.globalPosition, day, controller, morning, evening);
      },
      onLongPressMoveUpdate: (details) {
        _isDragging = true;
        _popupKey?.currentState?.updateDragPosition(details.globalPosition);
      },
      onLongPressEnd: (details) {
        if (_isDragging && _popupKey?.currentState != null) {
          _popupKey!.currentState!.confirmSelection();
        }
      },
      child: content,
    );
  }

  void _showStatusPopup(
    BuildContext context,
    Offset position,
    DateTime day,
    AttendanceController controller,
    bool initialMorning,
    bool initialEvening,
  ) {
    _isDragging = false;
    _popupOverlayEntry?.remove();
    _popupKey = GlobalKey<_StatusSelectionPopupState>();
    _popupOverlayEntry = OverlayEntry(
      builder: (context) => StatusSelectionPopup(
        key: _popupKey,
        tapPosition: position,
        day: day,
        controller: controller,
        initialMorning: initialMorning,
        initialEvening: initialEvening,
        onDismiss: () {
          _hideStatusPopup();
        },
        onSelect: (morning, evening) {
          _cycleCabStatusTo(controller, day, morning, evening);
          _hideStatusPopup();
        },
      ),
    );
    Overlay.of(context).insert(_popupOverlayEntry!);
    HapticFeedback.mediumImpact();
  }

  void _hideStatusPopup() {
    _popupOverlayEntry?.remove();
    _popupOverlayEntry = null;
    _popupKey = null;
    _isDragging = false;
  }

  void _cycleCabStatusTo(AttendanceController controller, DateTime day, bool morning, bool evening) {
    controller.updateMorningCabUsage(day, morning);
    controller.updateEveningCabUsage(day, evening);
    HapticFeedback.selectionClick();

    String label;
    Color color;
    if (morning && evening) {
      label = 'Both trips marked';
      color = _kGreen;
    } else if (morning) {
      label = 'Morning trip only';
      color = _kOrange;
    } else if (evening) {
      label = 'Evening trip only';
      color = _kPurple;
    } else {
      label = 'Marked as missed';
      color = _kRed;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${DateFormat('d MMM').format(day)} — $label',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _solidCircle(DateTime day, Color bg, Color textColor) {
    return Container(
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '${day.day}',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
        ),
      ),
    );
  }

  /// A circle split vertically into two halves — used to represent
  /// "only one of the two trips was used" so it visually relates to the
  /// full-green "both used" state.
  Widget _splitCircle(
    DateTime day, {
    required Color leftColor,
    required Color rightColor,
    required Color textColor,
    bool textOnLeft = true,
  }) {
    return ClipOval(
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(child: Container(color: leftColor)),
              Expanded(child: Container(color: rightColor)),
            ],
          ),
          Center(
            child: Text(
              '${day.day}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textOnLeft ? textColor : _kSlate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard(AttendanceController controller) {
    final fare = controller.constFarePerTrip;

    if (!_isEditingFare) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_money, color: _kGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cab Fare per Trip',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kSlate500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${fare.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _kSlate900),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                _fareController.text = fare == 0 ? '' : fare.toString();
                setState(() => _isEditingFare = true);
              },
              icon: const Icon(Icons.edit_outlined, color: _kSlate500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: _kGreen),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _fareController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cab Fare per Trip',
                labelStyle: GoogleFonts.poppins(fontSize: 14, color: _kSlate500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: _kSlate900),
              onSubmitted: (_) => _handleFareUpdate(controller),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => setState(() => _isEditingFare = false),
            icon: const Icon(Icons.close, color: _kSlate500),
          ),
          ElevatedButton(
            onPressed: () => _handleFareUpdate(controller),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _handleFareUpdate(AttendanceController controller) {
    final newFare = double.tryParse(_fareController.text);
    if (newFare != null && newFare > 0) {
      controller.updateFarePerTrip(newFare);
      FocusScope.of(context).unfocus();
      setState(() => _isEditingFare = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Fare updated successfully!', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
            ],
          ),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Please enter a valid positive number', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
            ],
          ),
          backgroundColor: Colors.redAccent.shade200,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// A single card holding both morning and evening toggles side by side,
  /// instead of two full-width stacked cards.
  Widget _buildCombinedTripCard(AttendanceController controller, dynamic attendance) {
    final morning = attendance?.morningCabUsed ?? false;
    final evening = attendance?.eveningCabUsed ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _tripRow(
            title: 'Morning Trip',
            subtitle: 'Track your morning commute',
            icon: Icons.wb_sunny_outlined,
            iconColor: _kOrange,
            cabUsed: morning,
            onToggleCab: (used) => controller.updateMorningCabUsage(_selectedDay!, used),
          ),
           Divider(height: 1, indent: 20, endIndent: 20,color: Colors.grey.shade200),
          _tripRow(
            title: 'Evening Trip',
            subtitle: 'Track your evening commute',
            icon: Icons.nights_stay_outlined,
            iconColor: _kPurple,
            cabUsed: evening,
            onToggleCab: (used) => controller.updateEveningCabUsage(_selectedDay!, used),
          ),
        ],
      ),
    );
  }

  Widget _tripRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool cabUsed,
    required ValueChanged<bool> onToggleCab,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _kSlate900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400, color: _kSlate500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cabUsed ? _kGreen.withOpacity(0.1) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cabUsed ? 'Used' : 'Not Used',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cabUsed ? _kGreen : _kSlate500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: cabUsed,
              onChanged: onToggleCab,
              activeColor: _kGreen,
              activeTrackColor: _kGreen.withOpacity(0.3),
              inactiveThumbColor: const Color(0xFFCBD5E1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusSelectionPopup extends StatefulWidget {
  final Offset tapPosition;
  final DateTime day;
  final AttendanceController controller;
  final VoidCallback onDismiss;
  final Function(bool morning, bool evening) onSelect;
  final bool initialMorning;
  final bool initialEvening;

  const StatusSelectionPopup({
    super.key,
    required this.tapPosition,
    required this.day,
    required this.controller,
    required this.onDismiss,
    required this.onSelect,
    required this.initialMorning,
    required this.initialEvening,
  });

  @override
  State<StatusSelectionPopup> createState() => _StatusSelectionPopupState();
}

class _StatusSelectionPopupState extends State<StatusSelectionPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  int _currentIndex = -1;

  final double popupWidth = 232.0;
  final double popupHeight = 64.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    if (widget.initialMorning && widget.initialEvening) {
      _currentIndex = 0;
    } else if (widget.initialMorning && !widget.initialEvening) {
      _currentIndex = 1;
    } else if (!widget.initialMorning && widget.initialEvening) {
      _currentIndex = 2;
    } else {
      _currentIndex = 3;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void updateDragPosition(Offset globalPosition) {
    final screenSize = MediaQuery.of(context).size;
    double left = widget.tapPosition.dx - (popupWidth / 2);
    if (left < 16) left = 16;
    if (left + popupWidth > screenSize.width - 16) {
      left = screenSize.width - popupWidth - 16;
    }

    double relativeX = globalPosition.dx - left;
    double startX = 12.0 + 20.0; // padding + half of item width (40/2)
    double step = 40.0 + 16.0; // item width + spacing

    double bestDist = double.infinity;
    int bestIdx = _currentIndex;

    for (int i = 0; i < 4; i++) {
      double centerX = startX + i * step;
      double dist = (relativeX - centerX).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx != _currentIndex) {
      setState(() {
        _currentIndex = bestIdx;
      });
      HapticFeedback.selectionClick();
    }
  }

  void confirmSelection() {
    bool morning = false;
    bool evening = false;
    if (_currentIndex == 0) {
      morning = true;
      evening = true;
    } else if (_currentIndex == 1) {
      morning = true;
      evening = false;
    } else if (_currentIndex == 2) {
      morning = false;
      evening = true;
    } else if (_currentIndex == 3) {
      morning = false;
      evening = false;
    }
    widget.onSelect(morning, evening);
  }

  Widget _buildCircleOption(int index) {
    final isSelected = _currentIndex == index;

    Widget circle;
    String label;
    if (index == 0) {
      label = 'Both';
      circle = Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: _kGreen,
          shape: BoxShape.circle,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      );
    } else if (index == 1) {
      label = 'Morning';
      circle = ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Row(
            children: [
              Expanded(child: Container(color: _kOrange)),
              Expanded(child: Container(color: const Color(0xFFF1F5F9))),
            ],
          ),
        ),
      );
    } else if (index == 2) {
      label = 'Evening';
      circle = ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Row(
            children: [
              Expanded(child: Container(color: const Color(0xFFF1F5F9))),
              Expanded(child: Container(color: _kPurple)),
            ],
          ),
        ),
      );
    } else {
      label = 'Missed';
      circle = Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: _kRed,
          shape: BoxShape.circle,
        ),
        child: isSelected
            ? const Icon(Icons.close, color: Colors.white, size: 20)
            : null,
      );
    }

    return Tooltip(
      message: label,
      child: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
            confirmSelection();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    double left = widget.tapPosition.dx - (popupWidth / 2);
    if (left < 16) left = 16;
    if (left + popupWidth > screenSize.width - 16) {
      left = screenSize.width - popupWidth - 16;
    }

    double top = widget.tapPosition.dy - (popupHeight + 24);
    if (top < 16) {
      top = widget.tapPosition.dy + 24;
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: popupWidth,
              height: popupHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleOption(0),
                  _buildCircleOption(1),
                  _buildCircleOption(2),
                  _buildCircleOption(3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}