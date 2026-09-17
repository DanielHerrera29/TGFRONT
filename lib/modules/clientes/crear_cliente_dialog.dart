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
  final _placa = TextEditingController();
  final _id = const Uuid().v4();
  String _tipo = 'empresa';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _placa.dispose();
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
        'placa': _placa.text.trim().toUpperCase(),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 720),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: const Text('Crear empresa o cliente'),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Registre los datos del cliente y la placa de carga en un solo paso.',
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cliente',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'empresa', child: Text('Empresa')),
                    DropdownMenuItem(value: 'persona', child: Text('Persona')),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _tipo = v!),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombre,
                  enabled: !_saving,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o razón social',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingrese el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documento,
                  enabled: !_saving,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'NIT o documento',
                    helperText: 'Escriba el NIT sin dígito de verificación.',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || !RegExp(r'^\d{5,20}$').hasMatch(v.trim())
                      ? 'Ingrese de 5 a 20 dígitos'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('placa-cliente'),
                  controller: _placa,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Placa de carga',
                    hintText: 'ABC123',
                    helperText:
                        'Se guardará con el cliente y estará disponible al crear la orden.',
                    helperMaxLines: 3,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[A-Z]{3}[0-9]{3}$',
                      ).hasMatch((v ?? '').trim().toUpperCase())
                      ? null
                      : 'Ingrese una placa: tres letras y tres números.',
                ),
                const SizedBox(height: 12),
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
