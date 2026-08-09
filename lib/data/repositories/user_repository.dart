import '../../core/services/supabase_service.dart';
import '../models/app_user.dart';

class UserRepository {
  Future<AppUser?> login(String email, String password) async {
    final rows = await SupabaseService.client
        .from('users')
        .select()
        .eq('email', email)
        .eq('password', password)
        .eq('active', true)
        .limit(1);

    if (rows.isEmpty) return null;

    final row = rows.first;
    return AppUser(
      id: row['id'],
      name: row['name'] ?? '',
      email: row['email'],
      password: row['password'] ?? '',
      role: UserRole.fromString(row['role'] ?? 'operator'),
      active: row['active'] ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final existing = await SupabaseService.client
        .from('users')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (existing != null) return null;

    final res = await SupabaseService.client.from('users').insert({
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
      'active': true,
    }).select('id').single();

    return res['id'];
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    return SupabaseService.client
        .from('users')
        .select('id, name, email, role, active, created_at, correo_email, contrasena_email_app')
        .order('created_at', ascending: false);
  }
}
