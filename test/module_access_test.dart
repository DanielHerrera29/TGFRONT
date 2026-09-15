import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/core/config/module_access.dart';
import 'package:transportegutierrez/data/models/app_user.dart';

void main() {
  AppUser usuario(UserRole role) => AppUser(
    id: 'id',
    name: 'Prueba',
    email: 'prueba@example.com',
    password: '',
    role: role,
    createdAt: DateTime(2026),
  );
  test('operador inicia en órdenes y no puede abrir módulos por URL', () {
    final user = usuario(UserRole.operator);
    expect(ModuleAccess.inicio(user), '/ordenes-escolta');
    for (final path in [
      '/',
      '/settings',
      '/remesas',
      '/manifiestos',
      '/vehiculos',
      '/register-user',
      '/manage-users',
      '/dispatch',
      '/history',
    ]) {
      expect(ModuleAccess.permite(user, path), false, reason: path);
    }
    for (final path in [
      '/ordenes-escolta',
      '/ordenes-escolta/nueva',
      '/ordenes-escolta/editar/abc',
    ]) {
      expect(ModuleAccess.permite(user, path), true, reason: path);
    }
  });
  test('administrador conserva módulos y gestión de clientes', () {
    expect(ModuleAccess.inicio(usuario(UserRole.admin)), '/');
    expect(
      ModuleAccess.permite(usuario(UserRole.admin), '/manage-users'),
      true,
    );
  });
}
