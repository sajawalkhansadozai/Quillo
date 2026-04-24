import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/generated_recipe.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalDbService — SQLite cache for offline saved recipes
// ─────────────────────────────────────────────────────────────────────────────

class LocalDbService {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), 'quillo.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS saved_recipes (
            id        TEXT PRIMARY KEY,
            data      TEXT NOT NULL,
            saved_at  TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Upsert a recipe into local cache ────────────────────────────────────────

  static Future<void> cacheRecipe(GeneratedRecipe recipe) async {
    if (recipe.id == null) return;
    final db = await _database;
    await db.insert(
      'saved_recipes',
      {
        'id': recipe.id,
        'data': jsonEncode(recipe.toJson()),
        'saved_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Remove a recipe from local cache ────────────────────────────────────────

  static Future<void> removeRecipe(String recipeId) async {
    final db = await _database;
    await db.delete('saved_recipes', where: 'id = ?', whereArgs: [recipeId]);
  }

  // ── Load all cached recipes (sorted by saved_at desc) ──────────────────────

  static Future<List<GeneratedRecipe>> loadAllRecipes() async {
    try {
      final db = await _database;
      final rows = await db.query(
        'saved_recipes',
        orderBy: 'saved_at DESC',
      );
      return rows
          .map((r) {
            try {
              final json = jsonDecode(r['data'] as String) as Map<String, dynamic>;
              return GeneratedRecipe.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<GeneratedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Check if a recipe is cached ─────────────────────────────────────────────

  static Future<bool> isCached(String recipeId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'saved_recipes',
        where: 'id = ?',
        whereArgs: [recipeId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Clear all cached recipes ─────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final db = await _database;
    await db.delete('saved_recipes');
  }
}
