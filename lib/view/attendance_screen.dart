  import 'package:cab_tracker_app/controllers/attendance_controller.dart';
  import 'package:flutter/material.dart';
  import 'package:open_filex/open_filex.dart';
  import 'package:provider/provider.dart';
  import 'package:table_calendar/table_calendar.dart';
  import 'package:google_fonts/google_fonts.dart';

  class AttendanceScreen extends StatefulWidget {
    const AttendanceScreen({super.key});

    @override
    State<AttendanceScreen> createState() => _AttendanceScreenState();
  }

  class _AttendanceScreenState extends State<AttendanceScreen> {
    DateTime _focusedDay = DateTime.now();
    DateTime? _selectedDay;
    late TextEditingController _fareController;
    


    @override
    void initState() {
      super.initState();
      _selectedDay = _focusedDay;
       _fareController = TextEditingController();
       WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndPromptCabUsage();
  });
       
    }
    void _checkAndPromptCabUsage() {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final attendanceController = Provider.of<AttendanceController>(context, listen: false);
          // Use your controller to check if already marked
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
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Container(
          padding:  EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 40,
                  color: const Color(0xFF10B981),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Cab Service',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle with time indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isMorning 
                    ? Colors.orange.shade50 
                    : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMorning 
                      ? Colors.orange.shade200 
                      : Colors.indigo.shade200,
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
              
              // Question text
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
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          side: BorderSide(color: Colors.red.shade300, width: 2),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            
                            Text(
                              'No, Thanks',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                   SizedBox(width: 15),
                  
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF10B981).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Text(
                              'Yes, I Will',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13  ,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (result == true) {
    final today = DateTime.now();
    if (isMorning) {
      attendanceController.updateMorningCabUsage(today, true);
    } else {
      attendanceController.updateEveningCabUsage(today, true);
    }
    
    // Optional: Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Cab usage recorded for ${isMorning ? 'morning' : 'evening'} trip',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

    

    void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }

    Future<void> _generateMonthlyReport(AttendanceController controller) async {
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(
                  'Generating report...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
        );

        // Generate report using controller
        final result = await controller.generateMonthlyReport(
          forMonth: _focusedDay,
        );
        
        Navigator.pop(context); // Close loading dialog
        
        if (result['success']) {
          _showSuccessDialog(
            result['filePath'], 
            result['fileName'],
            // result['stats'],
          );
        } else {
          _showErrorDialog(result['error']);
        }
        
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('Failed to generate report: $e');
      }
    }
    
    void _showSuccessDialog(String filePath, String fileName
    // , Map<String, dynamic> stats
    ) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Text(
                'Report Generated',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
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
              
              // Stats Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  // border: Border.all(color:  Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Summary',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // _buildStatRow('Working Days', '${stats['totalWorkingDays']}'),
                    // _buildStatRow('Morning Trips', '${stats['totalMorningTrips']}'),
                    // _buildStatRow('Evening Trips', '${stats['totalEveningTrips']}'),
                    // _buildStatRow('Total Trips', '${stats['totalTrips']}'),
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
                    const Icon(Icons.insert_drive_file, color: Color(0xFF64748B)),
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
                            color: const Color(0xFF3B82F6),
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
                style: GoogleFonts.poppins(color: Colors.white),
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
              label: Text(
                'Share',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
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
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }
    
    void _showErrorDialog(String message) {
      showDialog(
        context: context,
        builder: (context) {
          print(message);
          return
          AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 12),
              Text(
                'Error',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
        }
      );
    }

    @override
    Widget build(BuildContext context) {
      final attendanceController = Provider.of<AttendanceController>(context);
      final selectedDateAttendance = _selectedDay != null
          ? attendanceController.getAttendanceForDate(_selectedDay!)
          : null;

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Attendance Tracker',
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () => _generateMonthlyReport(attendanceController),
                icon: const Icon(Icons.download, size: 18),
                label: Text(
                  'Report',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Container
              Container(
                margin: const EdgeInsets.all(16),
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
                  child: TableCalendar( 
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
                    color: const Color(0xFF1E293B),
                  ),
                  leftChevronIcon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF64748B),
                    size: 28,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF64748B),
                    size: 28,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  weekendStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                  weekendTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                  selectedDecoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  
                  cellMargin: const EdgeInsets.all(4),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final attendance = attendanceController.getAttendanceForDate(day);

                    final morning = attendance.morningCabUsed;
                    final evening = attendance.eveningCabUsed;

                    final today = DateTime.now();
                    final isPastDay = day.isBefore(DateTime(today.year, today.month, today.day));

                    Color? bgColor;

                    if (morning && evening) {
                      bgColor = const Color(0xFF10B981); // green
                    } else if (morning) {
                      bgColor = const Color(0xFFF59E0B); // orange
                    } else if (evening) {
                      bgColor = const Color(0xFF8B5CF6); // purple
                    } else if (isPastDay) {
                      bgColor = Colors.redAccent; // red for previous days where neither trip used
                    } else {
                      bgColor = const Color.fromARGB(255, 190, 199, 212); // upcoming days or today
                    }

                    return Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
  
              ),

                ),
              ),

              // Attendance Details
              if (_selectedDay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Date',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDay!.toLocal().toString().split(' ')[0],
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Text(
                        'Cab Usage',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 10,),
                      Consumer<AttendanceController>(
                        builder: (context, controller, _) {
                          // Update text field when model changes
                          _fareController.text = controller.constFarePerTrip.toString();

                          // Helper to show snackbars
                          void showSnackBar(String message, {required Color color, IconData? icon}) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    if (icon != null) Icon(icon, color: Colors.white),
                                    if (icon != null) const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: color,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }

                          void handleFareUpdate() {
                            final newFare = double.tryParse(_fareController.text);
                            if (newFare != null && newFare > 0) {
                              controller.updateFarePerTrip(newFare);
                              FocusScope.of(context).unfocus();
                              showSnackBar('Fare updated successfully!',
                                  color: Colors.green.shade600, icon: Icons.check_circle_rounded);
                            } else {
                              showSnackBar('Please enter a valid positive number',
                                  color: Colors.redAccent.shade200, icon: Icons.warning_amber_rounded);
                            }
                          }

                          return Container(
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
                            child: Row(
                              children: [
                                const Icon(Icons.attach_money, color: Color(0xFF10B981)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _fareController,
                                    keyboardType: TextInputType.numberWithOptions(),
                                    decoration: InputDecoration(
                                      labelText: 'Cab Fare per Trip',
                                      labelStyle: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
                                    onSubmitted: (_) => handleFareUpdate(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: handleFareUpdate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Update',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      ModernCabUsageCard(
                        title: 'Morning Trip',
                        subtitle: 'Track your morning commute',
                        icon: Icons.wb_sunny_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        cabUsed: selectedDateAttendance?.morningCabUsed ?? false,
                        onToggleCab: (bool cabUsed) {
                          attendanceController.updateMorningCabUsage(
                            _selectedDay!,
                            cabUsed,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      ModernCabUsageCard(
                        title: 'Evening Trip',
                        subtitle: 'Track your evening commute',
                        icon: Icons.nights_stay_outlined,
                        iconColor: const Color(0xFF8B5CF6),
                        cabUsed: selectedDateAttendance?.eveningCabUsed ?? false,
                        onToggleCab: (bool cabUsed) {
                          attendanceController.updateEveningCabUsage(
                            _selectedDay!,
                            cabUsed,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  class ModernCabUsageCard extends StatelessWidget {
    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;
    final bool cabUsed;
    final ValueChanged<bool> onToggleCab;

    const ModernCabUsageCard({
      super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.iconColor,
      required this.cabUsed,
      required this.onToggleCab,
    });

    @override
    Widget build(BuildContext context) {
      return Container(
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cabUsed 
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cabUsed ? 'Used' : 'Not Used',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cabUsed 
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
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
                  activeColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
                  inactiveThumbColor: const Color(0xFFE2E8F0),
                  inactiveTrackColor: const Color(0xFFF1F5F9),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }