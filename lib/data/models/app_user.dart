enum UserRole {
  admin,
  operator,
  auditor;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.operator:
        return 'Operador';
      case UserRole.auditor:
        return 'Auditor';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'auditor':
        return UserRole.auditor;
      default:
        return UserRole.operator;
    }
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final bool active;
  final DateTime createdAt;
  final String? apiToken;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.role = UserRole.operator,
    this.active = true,
    required this.createdAt,
    this.apiToken,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get canWrite =>
      role == UserRole.admin || role == UserRole.operator;
}
