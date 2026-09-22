import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/data/datasource/local_store.dart';
import 'package:transportegutierrez/modules/auth/providers/auth_provider.dart';
import 'package:transportegutierrez/modules/auth/remembered_login.dart';
import 'package:transportegutierrez/services/api_service.dart';

class MemoryRemember extends RememberedLogin {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> save(Map<String, dynamic> value) async {
    data = Map.from(value);
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

Map<String, dynamic> session() => {
  'token': 'test-token',
  'user': {
    'id': 'fixture',
    'name': 'Usuario',
    'email': 'User@Example.com',
    'role': 'operator',
    'active': true,
    'created_at': '2026-01-01',
  },
};
void main() {
  test(
    'normaliza correo, conserva contraseña exacta y recuerda acceso',
    () async {
      final memory = MemoryRemember();
      final store = LocalStore();
      final auth = AuthProvider(
        store,
        remember: memory,
        authenticate: (e, p) async {
          expect(e, 'user@example.com');
          expect(p, 'MiClave A');
          return session();
        },
      );
      expect(
        await auth.login(' USER@EXAMPLE.COM ', 'MiClave A', rememberMe: true),
        true,
      );
      expect(store.currentUser!.password, isEmpty);
      expect(memory.data!['email'], 'user@example.com');
      final restored = AuthProvider(
        LocalStore(),
        remember: memory,
        authenticate: (e, p) async => session(),
      );
      await restored.restore();
      expect(restored.isLoggedIn, true);
      await auth.logout();
      expect(memory.data, isNull);
      expect(store.isLoggedIn, false);
      expect(ApiService.sessionToken, isNull);
    },
  );
  test(
    'sin Recordarme no conserva credenciales; credencial rechazada borra recuerdo',
    () async {
      final memory = MemoryRemember()
        ..data = {'email': 'old', 'password': 'old'};
      final auth = AuthProvider(
        LocalStore(),
        remember: memory,
        authenticate: (e, p) async => session(),
      );
      expect(await auth.login('user@example.com', 'p'), true);
      expect(memory.data, isNull);
      memory.data = {'email': 'user@example.com', 'password': 'p'};
      final denied = AuthProvider(
        LocalStore(),
        remember: memory,
        authenticate: (e, p) async => null,
      );
      await denied.restore();
      expect(denied.isLoggedIn, false);
      expect(memory.data, isNull);
    },
  );
  test(
    'error de red no inicia sesión ni destruye recuerdo recuperable',
    () async {
      final memory = MemoryRemember()
        ..data = {'email': 'user@example.com', 'password': 'p'};
      final auth = AuthProvider(
        LocalStore(),
        remember: memory,
        authenticate: (e, p) async => throw Exception('offline'),
      );
      await auth.restore();
      expect(auth.isLoggedIn, false);
      expect(memory.data, isNotNull);
      expect(auth.loading, false);
    },
  );
  test('cerrar sesión durante login impide reapertura tardía', () async {
    final pending = Completer<Map<String, dynamic>?>();
    final memory = MemoryRemember();
    final auth = AuthProvider(
      LocalStore(),
      remember: memory,
      authenticate: (e, p) => pending.future,
    );
    final login = auth.login('a@b.com', 'p', rememberMe: true);
    await auth.logout();
    pending.complete(session());
    expect(await login, false);
    expect(auth.isLoggedIn, false);
    expect(memory.data, isNull);
  });
}
