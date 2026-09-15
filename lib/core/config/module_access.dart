import '../../data/models/app_user.dart';

class ModuleAccess {
  static bool soloOrdenes(AppUser? user) => user?.role == UserRole.operator;
  static String inicio(AppUser? user) =>
      soloOrdenes(user) ? '/ordenes-escolta' : '/';
  static bool permite(AppUser? user, String path) =>
      !soloOrdenes(user) ||
      path == '/ordenes-escolta' ||
      path == '/ordenes-escolta/nueva' ||
      RegExp(r'^/ordenes-escolta/editar/[^/]+$').hasMatch(path);
}
