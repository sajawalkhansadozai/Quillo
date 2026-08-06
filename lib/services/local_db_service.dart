import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/generated_recipe.dart';
import '../models/shopping_list.dart';

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
      version: 3,
      onCreate: (db, version) async {
        await _createSavedRecipesTable(db);
        await _createShoppingListsTable(db);
        await _createSearchCacheTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createShoppingListsTable(db);
        }
        if (oldVersion < 3) {
          await _createSearchCacheTable(db);
        }
      },
    );
  }

  static Future<void> _createSavedRecipesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_recipes (
        id        TEXT PRIMARY KEY,
        data      TEXT NOT NULL,
        saved_at  TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createShoppingListsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_lists (
        id          TEXT PRIMARY KEY,
        recipe_name TEXT NOT NULL,
        recipe_id   TEXT,
        data        TEXT NOT NULL,
        created_at  TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createSearchCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS search_cache (
        search_term TEXT PRIMARY KEY,
        data        TEXT NOT NULL,
        cached_at   TEXT NOT NULL
      )
    ''');
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

  // ── Offline search cache (normalized term → recipe list) ───────────────────

  static String normalizeSearchTerm(String term) => term.trim().toLowerCase();

  static Future<void> cacheSearchResults(
    String term,
    List<GeneratedRecipe> recipes,
  ) async {
    final key = normalizeSearchTerm(term);
    if (key.isEmpty || recipes.isEmpty) return;
    try {
      final db = await _database;
      await db.insert(
        'search_cache',
        {
          'search_term': key,
          'data': jsonEncode(recipes.map((r) => r.toJson()).toList()),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<List<GeneratedRecipe>> loadSearchCache(String term) async {
    final key = normalizeSearchTerm(term);
    if (key.isEmpty) return [];
    try {
      final db = await _database;
      final rows = await db.query(
        'search_cache',
        where: 'search_term = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return [];
      final raw = jsonDecode(rows.first['data'] as String);
      if (raw is! List) return [];
      return raw
          .map((e) {
            try {
              return GeneratedRecipe.fromJson(
                Map<String, dynamic>.from(e as Map),
              );
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

  // ── Shopping lists ──────────────────────────────────────────────────────────

  static Future<void> saveShoppingList(ShoppingList list) async {
    final db = await _database;
    await db.insert(
      'shopping_lists',
      {
        'id': list.id,
        'recipe_name': list.recipeName,
        'recipe_id': list.recipeId,
        'data': jsonEncode(list.toJson()),
        'created_at': list.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<ShoppingList?> findShoppingListByRecipeId(String recipeId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'shopping_lists',
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _shoppingListFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  static Future<ShoppingList?> loadShoppingList(String id) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _shoppingListFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  static Future<List<ShoppingList>> loadAllShoppingLists() async {
    try {
      final db = await _database;
      final rows = await db.query(
        'shopping_lists',
        orderBy: 'created_at DESC',
      );
      return rows
          .map(_shoppingListFromRow)
          .whereType<ShoppingList>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static ShoppingList? _shoppingListFromRow(Map<String, Object?> row) {
    try {
      final json = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return ShoppingList.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteShoppingList(String id) async {
    final db = await _database;
    await db.delete('shopping_lists', where: 'id = ?', whereArgs: [id]);
  }
}
