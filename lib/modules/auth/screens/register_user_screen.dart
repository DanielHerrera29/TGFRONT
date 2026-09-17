import 'package:flutter/material.dart';

import '../../../data/models/app_user.dart';

import '../../../services/contacto_escolta.dart';
import '../../../services/api_service.dart';
import 'package:uuid/uuid.dart';

class RegisterUserScreen extends StatefulWidget {
  final Future<String> Function(Map<String, dynamic>)? crearUsuario;
  const RegisterUserScreen({super.key, this.crearUsuario});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _role = UserRole.operator;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  final String _altaId = const Uuid().v4();
  final Set<String> _placas = {};
  final _placaCtrl = TextEditingController();
  bool _enlazar = false;
  String? _placaError;
  bool _creando = false;
  String? _altaError;
  Map<String, dynamic>? _solicitud;

  bool _agregarPlaca() {
    final placa = _placaCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(placa)) {
      setState(
        () => _placaError =
            'Escriba tres letras y tres números. Ejemplo: ABC123.',
      );
      return false;
    }
    if (_placas.contains(placa)) {
      setState(() => _placaError = 'Esta placa ya está agregada.');
      return false;
    }
    if (_placas.length >= 30) {
      setState(
        () => _placaError = 'Puede agregar hasta 30 placas por usuario.',
      );
      return false;
    }
    setState(() {
      _placas.add(placa);
      _placaCtrl.clear();
      _placaError = null;
    });
    return true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingrese el correo';
    final emailReg = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailReg.hasMatch(v.trim())) return 'Correo inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingrese la contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del usuario',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: _solicitud == null,
                controller: _nameCtrl,
                decoration: _input('Nombre completo', Icons.person_outline),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: _solicitud == null,
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                decoration: _input('Celular / WhatsApp', Icons.phone_outlined),
                validator: validarCelular,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: _solicitud == null,
                controller: _emailCtrl,
                decoration: _input('Correo electrónico', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: _solicitud == null,
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: _input(
                  'Contraseña',
                  Icons.lock_outlined,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enabled: _solicitud == null,
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: _input(
                  'Confirmar contraseña',
                  Icons.lock_outlined,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _passCtrl.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: _input('Rol', Icons.badge_outlined),
                items: UserRole.values
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: _solicitud != null
                    ? null
                    : (v) => setState(() => _role = v ?? UserRole.operator),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enlazar placas al crear el usuario'),
                value: _enlazar,
                onChanged: _solicitud != null
                    ? null
                    : (value) {
                        setState(() => _enlazar = value);
                      },
              ),
              if (_enlazar) ...[
                TextFormField(
                  key: const ValueKey('placa-usuario'),
                  controller: _placaCtrl,
                  enabled: _solicitud == null,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_solicitud == null) _agregarPlaca();
                  },
                  decoration: InputDecoration(
                    labelText: 'Escriba una placa',
                    hintText: 'ABC123',
                    errorText: _placaError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _solicitud == null ? _agregarPlaca : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar placa'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _placas
                      .map(
                        (p) => InputChip(
                          label: Text(p),
                          onDeleted: _solicitud != null
                              ? null
                              : () => setState(() => _placas.remove(p)),
                        ),
                      )
                      .toList(),
                ),
                const Text(
                  'Puede enlazar varias placas. Desactive la opción para crearlo sin vehículos.',
                ),
              ],
              if (_altaError != null)
                Text(
                  _altaError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _creando ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _creando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Crear usuario',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _submit() async {
    if (_creando || !_formKey.currentState!.validate()) return;
    if (_solicitud == null &&
        _enlazar &&
        _placaCtrl.text.trim().isNotEmpty &&
        !_agregarPlaca())
      return;
    if (_solicitud == null && _enlazar && _placas.isEmpty) {
      setState(
        () => _altaError =
            'Agregue al menos una placa o desactive Enlazar placas.',
      );
      return;
    }
    _solicitud ??= {
      'id': _altaId,
      'nombre': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
      'role': _role.name,
      'whatsapp': normalizarCelular(_whatsappCtrl.text),
      'placas': _enlazar ? _placas.toList() : <String>[],
    };
    setState(() {
      _creando = true;
      _altaError = null;
    });
    try {
      await (widget.crearUsuario?.call(_solicitud!) ??
          ApiService.crearUsuarioConPlacas(_solicitud!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario y placas guardados.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is AltaUsuarioRechazada) {
            _solicitud = null;
            _altaError = '$e Puede corregir los datos.';
          } else {
            _altaError =
                '$e\nReintentar conservará los datos y no creará otra cuenta.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }
}
