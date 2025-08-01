// import '../helpers/database_helper.dart';

// // Save a trip
// Future<void> saveTrip({
//   required String pickup,
//   required String drop,
//   required DateTime dateTime,
//   required double fare,
// }) async {
//   await DatabaseHelper.instance.insertTrip({
//     'pickup': pickup,
//     'drop': drop,
//     'dateTime': dateTime.toIso8601String(),
//     'fare': fare,
//   });
// }

// // Load all trips
// Future<void> loadTrips() async {
//   List<Map<String, dynamic>> trips = await DatabaseHelper.instance.getAllTrips();
//   print('All trips: $trips');
// }
