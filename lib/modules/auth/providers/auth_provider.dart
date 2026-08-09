import 'package:flutter/foundation.dart';
import '../../../data/datasource/local_store.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final LocalStore _store;
  final UserRepository _repo = UserRepository();

  AuthProvider(this._store);

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

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _repo.login(email, password);
      if (user == null) {
        _error = 'Correo o contraseña incorrectos';
        _loading = false;
        notifyListeners();
        return false;
      }
      final token = await ApiService.iniciarSesion(email, password);
      if (token == null) {
        _error = 'No fue posible iniciar la sesión segura';
        _loading = false;
        notifyListeners();
        return false;
      }
      _store.setSession(AppUser(
        id: user.id,
        name: user.name,
        email: user.email,
        password: user.password,
        role: user.role,
        active: user.active,
        createdAt: user.createdAt,
        apiToken: token,
      ));
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error de conexión';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
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
    _store.clearSession();
    notifyListeners();
  }
}
