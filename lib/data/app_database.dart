import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'otp_sara.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sam_number TEXT NOT NULL UNIQUE,
            child_name TEXT NOT NULL,
            age_months INTEGER NOT NULL,
            gender TEXT NOT NULL,
            phone TEXT,
            governorate TEXT,
            district TEXT,
            village TEXT,
            admission_date TEXT NOT NULL,
            visit_date TEXT NOT NULL,
            twins TEXT NOT NULL,
            weight_kg REAL NOT NULL,
            height_cm REAL NOT NULL,
            z_score TEXT NOT NULL,
            muac_cm REAL NOT NULL,
            admission_reasons TEXT,
            admission_type TEXT NOT NULL,
            outcome TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        // Enforce the follow-up date in the database as well as in the UI.
        await db.execute('''
          CREATE TRIGGER enforce_visit_date_insert
          AFTER INSERT ON patients
          BEGIN
            UPDATE patients
            SET visit_date = date(NEW.admission_date, '+7 days')
            WHERE id = NEW.id;
          END
        ''');
        await db.execute('''
          CREATE TRIGGER enforce_visit_date_update
          AFTER UPDATE OF admission_date ON patients
          BEGIN
            UPDATE patients
            SET visit_date = date(NEW.admission_date, '+7 days')
            WHERE id = NEW.id;
          END
        ''');
      },
    );
    return _db!;
  }

  Future<int> insertPatient(Map<String, Object?> patient) async {
    final db = await database;
    return db.insert('patients', patient, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Map<String, Object?>>> getPatients() async {
    final db = await database;
    return db.query('patients', orderBy: 'id DESC');
  }
}
