// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

// class DatabaseHelper {
//   static final DatabaseHelper instance = DatabaseHelper._init();
//   static Database? _database;

//   DatabaseHelper._init();

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB('attendance.db');
//     return _database!;
//   }

//   Future<Database> _initDB(String filePath) async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, filePath);

//     return await openDatabase(
//   path,
//   version: 2, // <-- bump version
//   onCreate: _createDB,
//   onUpgrade: _upgradeDB,
// );

//   }
//   Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
//   if (oldVersion < 2) {
//     await db.execute('''
//       CREATE TABLE settings (
//         key TEXT PRIMARY KEY,
//         value TEXT
//       )
//     ''');
//     await db.insert('settings', {'key': 'constFarePerTrip', 'value': '0'});
//   }
// }


//   Future _createDB(Database db, int version) async {
//     // Table for attendance trips
//     await db.execute('''
//       CREATE TABLE trips (
//         date TEXT PRIMARY KEY,
//         morningCabUsed INTEGER NOT NULL,
//         eveningCabUsed INTEGER NOT NULL
//       )
//     ''');

//     // Table for storing key-value settings
//     await db.execute('''
//       CREATE TABLE settings (
//         key TEXT PRIMARY KEY,
//         value TEXT
//       )
//     ''');

//     // Insert default fare value
//     await db.insert('settings', {'key': 'constFarePerTrip', 'value': '0'});
//   }

//   // Insert or update a trip record
//   Future<void> insertOrUpdateTrip(Map<String, dynamic> trip) async {
//     final db = await instance.database;
//     await db.insert(
//       'trips',
//       trip,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   // Get trip by date
//   Future<Map<String, dynamic>?> getTripByDate(String date) async {
//     final db = await instance.database;
//     final result = await db.query(
//       'trips',
//       where: 'date = ?',
//       whereArgs: [date],
//       limit: 1,
//     );
//     return result.isNotEmpty ? result.first : null;
//   }

//   // Get all trips
//   Future<List<Map<String, dynamic>>> getAllTrips() async {
//     final db = await instance.database;
//     return await db.query('trips');
//   }

//   // Clear all trips
//   Future<void> clearAllTrips() async {
//     final db = await instance.database;
//     await db.delete('trips');
//   }

//   // Get the constant fare per trip
//   Future<double?> getConstFarePerTrip() async {
//     final db = await instance.database;
//     final result = await db.query(
//       'settings',
//       columns: ['value'],
//       where: 'key = ?',
//       whereArgs: ['constFarePerTrip'],
//       limit: 1,
//     );
//     if (result.isNotEmpty) {
//       return double.tryParse(result.first['value'].toString());
//     }
//     return null;
//   }

//   // Set or update the constant fare per trip
//   Future<void> setConstFarePerTrip(double fare) async {
//     final db = await instance.database;
//     await db.insert(
//       'settings',
//       {'key': 'constFarePerTrip', 'value': fare.toString()},
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   // (Optional) Clear all settings
//   Future<void> clearAllSettings() async {
//     final db = await instance.database;
//     await db.delete('settings');
//   }
// }
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // ✅ Use correct database factory based on platform
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await db.insert('settings', {'key': 'constFarePerTrip', 'value': '0'});
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips (
        date TEXT PRIMARY KEY,
        morningCabUsed INTEGER NOT NULL,
        eveningCabUsed INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.insert('settings', {'key': 'constFarePerTrip', 'value': '0'});
  }

  // ✅ CRUD methods
  Future<void> insertOrUpdateTrip(Map<String, dynamic> trip) async {
    final db = await instance.database;
    await db.insert('trips', trip, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getTripByDate(String date) async {
    final db = await instance.database;
    final result = await db.query('trips', where: 'date = ?', whereArgs: [date], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllTrips() async {
    final db = await instance.database;
    return await db.query('trips');
  }

  Future<void> clearAllTrips() async {
    final db = await instance.database;
    await db.delete('trips');
  }

  Future<double?> getConstFarePerTrip() async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['constFarePerTrip'],
      limit: 1,
    );
    if (result.isNotEmpty) return double.tryParse(result.first['value'].toString());
    return null;
  }

  Future<void> setConstFarePerTrip(double fare) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': 'constFarePerTrip', 'value': fare.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllSettings() async {
    final db = await instance.database;
    await db.delete('settings');
  }
}


