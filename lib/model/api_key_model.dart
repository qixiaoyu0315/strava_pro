import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ApiKeyModel {
  static final ApiKeyModel _instance = ApiKeyModel._internal();
  factory ApiKeyModel() => _instance;

  ApiKeyModel._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'api_key.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE api_keys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_id TEXT NOT NULL,
            api_key TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertApiKey(String apiId, String apiKey) async {
    final db = await database;
    await db.insert(
      'api_keys',
      {'api_id': apiId, 'api_key': apiKey},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>?> getApiKey() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('api_keys', orderBy: 'id DESC', limit: 1);
    if (maps.isNotEmpty) {
      return {
        'api_id': maps.first['api_id'] as String,
        'api_key': maps.first['api_key'] as String,
      };
    }
    return null;
  }

  Future<void> deleteApiKey() async {
    final db = await database;
    await db.delete('api_keys');
  }
} 