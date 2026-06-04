import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // =========================
  // 🔵 REAL-TIME STREAM DATA
  // =========================
  Stream<List<Map<String, dynamic>>> getDeathsStream() {
    return client
        .from('death_data')
        .stream(primaryKey: ['id']);
  }

  // =========================
  // 🟢 ONE-TIME FETCH (fallback)
  // =========================
  Future<List<Map<String, dynamic>>> fetchDeaths() async {
    final response = await client.from('death_data').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // 🟡 INSERT NEW RECORD
  // =========================
  Future<void> insertDeathRecord(Map<String, dynamic> data) async {
    await client.from('death_data').insert(data);
  }

  // =========================
  // 🔴 DELETE RECORD (optional admin feature)
  // =========================
  Future<void> deleteDeathRecord(String id) async {
    await client.from('death_data').delete().eq('id', id);
  }
}