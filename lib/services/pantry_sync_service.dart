import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pantry_item.dart';
import '../utils/pantry_sync_decision.dart';
import 'local_db_service.dart';

/// Cloud sync for pantry items (Supabase `user_pantry_items`).
///
/// Local SQLite stays the source of truth for offline use. Sync is best-effort:
/// upserts/deletes when signed in; [pullAndMerge] on hub open.
class PantrySync {
  PantrySync._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'user_pantry_items';

  static String? get _uid => _client.auth.currentUser?.id;

  static Future<void> upsert(PantryItem item, {DateTime? updatedAt}) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from(_table).upsert({
      'id': item.id,
      'user_id': uid,
      'data': item.toJson(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': null,
    });
  }

  static Future<void> delete(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from(_table).upsert({
      'id': id,
      'user_id': uid,
      'data': {'id': id},
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': DateTime.now().toIso8601String(),
    });
  }

  /// Pull remote rows and merge into local DB by [updated_at].
  static Future<void> pullAndMerge() async {
    final uid = _uid;
    if (uid == null) return;
    final rows = await _client
        .from(_table)
        .select('id, data, updated_at, deleted_at')
        .eq('user_id', uid);
    final localUpdated = await LocalDbService.loadPantryUpdatedAts();

    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String?;
      if (id == null) continue;
      final remoteUpdated =
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      final remoteDeleted = DateTime.tryParse(map['deleted_at'] as String? ?? '');
      final action = decidePantrySync(
        localUpdated: localUpdated[id],
        remoteUpdated: remoteUpdated,
        remoteDeleted: remoteDeleted,
      );

      if (action == PantrySyncAction.deleteLocal) {
        await LocalDbService.deletePantryItem(id);
        continue;
      }
      if (action != PantrySyncAction.takeRemote) continue;

      final data = map['data'];
      if (data is! Map) continue;
      final remote = PantryItem.fromJson(Map<String, dynamic>.from(data));
      await LocalDbService.savePantryItem(remote, updatedAt: remoteUpdated);
    }
  }

  /// Push all local items (e.g. after first login).
  static Future<void> pushAll() async {
    final uid = _uid;
    if (uid == null) return;
    final updated = await LocalDbService.loadPantryUpdatedAts();
    final items = await LocalDbService.loadAllPantryItems();
    for (final item in items) {
      await upsert(item, updatedAt: updated[item.id]);
    }
  }

  static const _activityTable = 'user_pantry_activity';

  static Future<({
    List<dynamic> useLog,
    List<String> dismissed,
    DateTime updatedAt,
  })?> fetchActivity() async {
    final uid = _uid;
    if (uid == null) return null;
    final rows = await _client
        .from(_activityTable)
        .select('use_log, dismissed_restock, updated_at')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    final map = Map<String, dynamic>.from(rows.first as Map);
    final updated =
        DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final log = map['use_log'];
    final dismissed = map['dismissed_restock'];
    return (
      useLog: log is List ? log : <dynamic>[],
      dismissed: dismissed is List
          ? dismissed.map((e) => e.toString()).toList()
          : <String>[],
      updatedAt: updated,
    );
  }

  static Future<void> saveActivity({
    required List<Map<String, dynamic>> useLog,
    required List<String> dismissed,
    required DateTime updatedAt,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from(_activityTable).upsert({
      'user_id': uid,
      'use_log': useLog,
      'dismissed_restock': dismissed,
      'updated_at': updatedAt.toIso8601String(),
    });
  }
}
