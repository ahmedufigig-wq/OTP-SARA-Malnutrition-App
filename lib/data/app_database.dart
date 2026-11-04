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
      version: 2,
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
        await _createVisits(db);
        await db.execute("""
          CREATE TRIGGER enforce_visit_date_insert AFTER INSERT ON patients
          BEGIN UPDATE patients SET visit_date = date(NEW.admission_date, '+7 days') WHERE id = NEW.id; END
        """);
        await db.execute("""
          CREATE TRIGGER enforce_visit_date_update AFTER UPDATE OF admission_date ON patients
          BEGIN UPDATE patients SET visit_date = date(NEW.admission_date, '+7 days') WHERE id = NEW.id; END
        """);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createVisits(db);
          final oldRows = await db.query('patients');
          for (final row in oldRows) {
            await db.insert('visits', {
              'patient_id': row['id'],
              'visit_date': row['admission_date'],
              'weight_kg': row['weight_kg'],
              'height_cm': row['height_cm'],
              'muac_cm': row['muac_cm'],
              'z_score': row['z_score'],
              'notes': 'قياسات التسجيل الأولية (تم ترحيلها تلقائياً)',
            });
          }
        }
      },
    );
    return _db!;
  }

  static Future<void> _createVisits(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        visit_date TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        height_cm REAL NOT NULL,
        muac_cm REAL,
        z_score TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX visits_patient_date_idx ON visits(patient_id, visit_date)');
  }

  Future<int> insertPatient(Map<String, Object?> patient) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('patients', patient, conflictAlgorithm: ConflictAlgorithm.abort);
      await txn.insert('visits', {
        'patient_id': id,
        'visit_date': patient['admission_date'],
        'weight_kg': patient['weight_kg'],
        'height_cm': patient['height_cm'],
        'muac_cm': patient['muac_cm'],
        'z_score': patient['z_score'],
        'notes': 'قياسات التسجيل الأولية',
      });
      return id;
    });
  }

  Future<List<Map<String, Object?>>> getPatients({String search = ''}) async {
    final db = await database;
    if (search.trim().isEmpty) return db.query('patients', orderBy: 'child_name COLLATE NOCASE');
    return db.query('patients',
      where: 'child_name LIKE ? OR sam_number LIKE ?',
      whereArgs: ['%${search.trim()}%', '%${search.trim()}%'],
      orderBy: 'child_name COLLATE NOCASE');
  }

  Future<Map<String, Object?>?> getPatient(int id) async {
    final db = await database;
    final rows = await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updatePatient(int id, Map<String, Object?> values) async {
    final db = await database;
    return db.update('patients', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> getVisits(int patientId) async {
    final db = await database;
    return db.query('visits', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'visit_date ASC, id ASC');
  }

  Future<int> addVisit(int patientId, Map<String, Object?> values) async {
    final db = await database;
    return db.insert('visits', {'patient_id': patientId, ...values});
  }

  Future<int> updateVisit(int id, Map<String, Object?> values) async {
    final db = await database;
    return db.update('visits', values, where: 'id = ?', whereArgs: [id]);
  }
}
