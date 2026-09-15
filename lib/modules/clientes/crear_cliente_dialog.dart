import 'clientes_api.dart';
import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import '../../data/models/cliente.dart';

class CrearClienteDialog extends StatefulWidget {
  final String token;
  final Future<Cliente> Function(Map<String, dynamic>)? crear;
  const CrearClienteDialog({super.key, required this.token, this.crear});
  @override
  State<CrearClienteDialog> createState() => _CrearClienteDialogState();
}

class _CrearClienteDialogState extends State<CrearClienteDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _id = const Uuid().v4();
  String _tipo = 'empresa';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final datos = <String, dynamic>{
        'id': _id,
        'tipo': _tipo,
        'nombre': _nombre.text.trim(),
        'documento': _documento.text.trim(),
      };
      final cliente =
          await (widget.crear ??
              (datos) => ClientesApi.crear(widget.token, datos))(datos);
      if (mounted) {
        Navigator.pop(context, cliente);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Crear empresa o cliente'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'empresa', child: Text('Empresa')),
                    DropdownMenuItem(value: 'persona', child: Text('Persona')),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _tipo = v!),
                ),
                TextFormField(
                  controller: _nombre,
                  enabled: !_saving,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o razón social',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingrese el nombre'
                      : null,
                ),
                TextFormField(
                  controller: _documento,
                  enabled: !_saving,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'NIT sin dígito de verificación / documento',
                  ),
                  validator: (v) =>
                      v == null || !RegExp(r'^\d{5,20}$').hasMatch(v.trim())
                      ? 'Ingrese de 5 a 20 dígitos'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _guardar,
          child: Text(_saving ? 'Guardando…' : 'Crear cliente'),
        ),
      ],
    ),
  );
}
