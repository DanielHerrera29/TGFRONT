import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/app_user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'register_user_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _repo = UserRepository();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _repo.listAll();
      if (mounted) setState(() => _users = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editarUsuario(Map<String, dynamic> user) async {
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditarUsuarioScreen(user: user, token: token),
      ),
    );
    if (actualizado == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Crear usuario',
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const _RegisterUserWrapper(),
                    ),
                  )
                  .then((_) => _load()),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('Sin usuarios'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (_, index) {
                final user = _users[index];
                final role = UserRole.fromString(
                  user['role']?.toString() ?? 'operator',
                );
                final active = user['active'] != false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        role == UserRole.admin
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(user['name']?.toString() ?? 'Usuario'),
                    subtitle: Text('${user['email'] ?? ''} - ${role.label}'),
                    trailing: active
                        ? const Icon(Icons.edit_outlined)
                        : const Icon(Icons.cancel_outlined, color: Colors.red),
                    onTap: isAdmin ? () => _editarUsuario(user) : null,
                  ),
                );
              },
            ),
    );
  }
}

class _EditarUsuarioScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;
  const _EditarUsuarioScreen({required this.user, required this.token});

  @override
  State<_EditarUsuarioScreen> createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<_EditarUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _usuarioRndc;
  late final TextEditingController _claveRndc;
  late final TextEditingController _correo;
  late final TextEditingController _claveApp;
  late UserRole _role;
  late bool _active;
  bool _guardando = false;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(
      text: widget.user['name']?.toString() ?? '',
    );
    _usuarioRndc = TextEditingController(
      text: widget.user['email']?.toString() ?? '',
    );
    _claveRndc = TextEditingController();
    _correo = TextEditingController(
      text: widget.user['correo_email']?.toString() ?? '',
    );
    _claveApp = TextEditingController();
    _role = UserRole.fromString(widget.user['role']?.toString() ?? 'operator');
    _active = widget.user['active'] != false;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _usuarioRndc.dispose();
    _claveRndc.dispose();
    _correo.dispose();
    _claveApp.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final correoOriginal = widget.user['correo_email']?.toString() ?? '';
    final cambiaCorreo =
        _correo.text.trim() != correoOriginal || _claveApp.text.isNotEmpty;
    if (cambiaCorreo &&
        (_correo.text.trim().isEmpty || _claveApp.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para cambiar correo, complete correo y contrasena de aplicacion.',
          ),
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiService.actualizarUsuario(
        token: widget.token,
        usuarioId: widget.user['id'].toString(),
        name: _nombre.text.trim(),
        email: _usuarioRndc.text.trim(),
        password: _claveRndc.text.isEmpty ? null : _claveRndc.text,
        role: _role.name,
        active: _active,
        correoEmail: cambiaCorreo ? _correo.text.trim() : null,
        contrasenaApp: cambiaCorreo ? _claveApp.text : null,
      );
      _guardado = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el usuario')),
        );
      }
    } finally {
      if (!_guardado && mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Editar ${widget.user['name'] ?? 'usuario'}')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
          children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _required('Ingrese el nombre'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _usuarioRndc,
              decoration: const InputDecoration(labelText: 'Usuario RNDC'),
              validator: _required('Ingrese el usuario RNDC'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _claveRndc,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva clave RNDC',
                helperText: 'Dejela vacia para conservarla.',
              ),
            ),
            const Divider(height: 28),
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo remitente'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _claveApp,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contrasena de aplicacion Gmail',
                helperText: 'Dejela vacia para conservar la actual.',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: UserRole.values
                  .map(
                    (role) =>
                        DropdownMenuItem(value: role, child: Text(role.label)),
                  )
                  .toList(),
              onChanged: _guardando
                  ? null
                  : (value) => setState(() => _role = value ?? _role),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usuario activo'),
              value: _active,
              onChanged: _guardando
                  ? null
                  : (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
        ],
      ),
    ),
  );

  String? Function(String?) _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
}

class _RegisterUserWrapper extends StatelessWidget {
  const _RegisterUserWrapper();
  @override
  Widget build(BuildContext context) => const RegisterUserScreen();
}
