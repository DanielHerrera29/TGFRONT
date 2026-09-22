import '../remembered_login.dart';
import 'package:flutter/foundation.dart';
import '../../../data/datasource/local_store.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final LocalStore _store;
  final UserRepository _repo = UserRepository();

  final RememberedLogin _remember;
  final Future<Map<String, dynamic>?> Function(String, String) _authenticate;
  final Future<Map<String, dynamic>?> Function(String) _restoreToken;
  int _epoch = 0;
  AuthProvider(
    this._store, {
    RememberedLogin? remember,
    Future<Map<String, dynamic>?> Function(String, String)? authenticate,
    Future<Map<String, dynamic>?> Function(String)? restoreToken,
  }) : _remember = remember ?? RememberedLogin(),
       _authenticate = authenticate ?? ApiService.autenticar,
       _restoreToken = restoreToken ?? ApiService.recuperarSesion;

  AppUser? get user => _store.currentUser;
  bool get isLoggedIn => _store.isLoggedIn;

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  AppUser _parse(Map<String, dynamic> data) {
    final row = Map<String, dynamic>.from(data['user'] as Map);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty || row['active'] != true) {
      throw StateError('Sesión inválida');
    }
    return AppUser(
      id: row['id'],
      name: row['name'] ?? '',
      email: row['email'],
      password: '',
      role: UserRole.fromString(row['role'] ?? 'operator'),
      active: true,
      createdAt: DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
      apiToken: token,
      whatsapp: row['whatsapp'],
    );
  }

  Future<void> restore() async {
    if (_loading || isLoggedIn) return;
    final epoch = ++_epoch;
    _loading = true;
    notifyListeners();
    try {
      final saved = await _remember.read();
      if (saved == null || epoch != _epoch) return;
      final password = saved['password'] as String?;
      final data = password != null && !kIsWeb
          ? await _authenticate(saved['email'] as String, password)
          : await _restoreToken(saved['token'] as String);
      if (epoch != _epoch) return;
      if (data == null) {
        await _remember.clear();
        _error = 'La sesión guardada venció o cambió. Ingrese nuevamente.';
        return;
      }
      _store.setSession(_parse(data));
    } catch (e, st) {
      debugPrint('RESTORE SESSION ERROR: $e\n$st');
      if (epoch == _epoch) {
        _error =
            'No se pudo recuperar la sesión. Revise la conexión o ingrese nuevamente.';
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    if (_loading) return false;
    final epoch = ++_epoch;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      email = email.trim().toLowerCase();
      final data = await _authenticate(email, password);
      if (epoch != _epoch) return false;
      if (data == null) {
        _error = 'Correo o contraseña incorrectos';
        return false;
      }
      final user = _parse(data);
      if (rememberMe) {
        await _remember.save({
          'email': email,
          'token': user.apiToken,
          if (!kIsWeb) 'password': password,
        });
      } else {
        await _remember.clear();
      }
      if (epoch != _epoch) {
        await _remember.clear();
        return false;
      }
      _store.setSession(user);
      return true;
    } catch (e, st) {
      debugPrint('LOGIN ERROR: $e\n$st');
      if (epoch == _epoch) {
        _error =
            'No se pudo iniciar o guardar la sesión. Revise la conexión y reintente.';
      }
      return false;
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? whatsapp,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = await _repo.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
        whatsapp: whatsapp,
      );
      if (userId == null) {
        _error = 'El correo ya está registrado';
        _loading = false;
        notifyListeners();
        return null;
      }
      _loading = false;
      notifyListeners();
      return userId;
    } catch (e) {
      _error = 'Error al crear usuario';
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    ++_epoch;
    _loading = false;
    _error = null;
    await _remember.clear();
    _store.clearSession();
    notifyListeners();
  }
}
