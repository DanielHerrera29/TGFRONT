import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<Map<String, dynamic>?> findById(String table, String id) async {
    final res = await client.from(table).select().eq('id', id).maybeSingle();
    return res;
  }

  static Future<List<Map<String, dynamic>>> findAll(String table, {String? column, dynamic value}) async {
    var query = client.from(table).select();
    if (column != null) {
      query = query.eq(column, value);
    }
    return query;
  }

  static Future<Map<String, dynamic>?> findOneBy(String table, String column, dynamic value) async {
    final res = await client.from(table).select().eq(column, value).maybeSingle();
    return res;
  }

  static Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data) async {
    final res = await client.from(table).insert(data).select().single();
    return res;
  }

  static Future<void> update(String table, String id, Map<String, dynamic> data) async {
    await client.from(table).update(data).eq('id', id);
  }

  static Future<void> delete(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }
}
