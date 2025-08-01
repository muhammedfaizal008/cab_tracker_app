

class Attendance {
  final DateTime date;
  bool morningCabUsed;
  bool eveningCabUsed;

  Attendance({
    required this.date,
    this.morningCabUsed = false,
    this.eveningCabUsed = false,
  });

  Attendance copyWith({
    DateTime? date,
    bool? morningCabUsed,
    bool? eveningCabUsed,
  }) {
    return Attendance(
      date: date ?? this.date,
      morningCabUsed: morningCabUsed ?? this.morningCabUsed,
      eveningCabUsed: eveningCabUsed ?? this.eveningCabUsed,
    );
  }
}
