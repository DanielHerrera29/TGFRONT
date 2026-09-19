import 'clientes_api.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cliente.dart';

class CrearClienteDialog extends StatefulWidget {
  final String token;
  final Cliente? cliente;
  final Future<Cliente> Function(Map<String, dynamic>)? crear;
  const CrearClienteDialog({
    super.key,
    required this.token,
    this.crear,
    this.cliente,
  });
  @override
  State<CrearClienteDialog> createState() => _CrearClienteDialogState();
}

class _CrearClienteDialogState extends State<CrearClienteDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _placa = TextEditingController();
  final _id = const Uuid().v4();
  final Set<String> _placas = {};
  Map<String, dynamic>? _solicitud;
  String _tipo = 'empresa';
  bool _saving = false;
  String? _error;
  String? _placaError;
  bool get _locked => _saving || _solicitud != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    if (c != null) {
      _nombre.text = c.nombre;
      _documento.text = c.documento;
      _tipo = c.tipoCliente;
      _placas.addAll(c.placasCarga);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _placa.dispose();
    super.dispose();
  }

  bool _agregar() {
    final p = _placa.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(p) || _placas.length >= 100) {
      setState(
        () =>
            _placaError = 'Use tres letras y tres números (máximo 100 placas).',
      );
      return false;
    }
    if (_placas.contains(p)) {
      setState(() => _placaError = 'Esta placa ya está agregada.');
      return false;
    }
    setState(() {
      _placas.add(p);
      _placa.clear();
      _placaError = null;
    });
    return true;
  }

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_solicitud == null && _placa.text.trim().isNotEmpty && !_agregar()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final datos = _solicitud ??= <String, dynamic>{
        'id': widget.cliente?.id ?? _id,
        'tipo': _tipo,
        'nombre': _nombre.text.trim(),
        'documento': _documento.text.trim(),
        'placas': _placas.toList(),
      };
      final cliente =
          await (widget.crear ?? (d) => ClientesApi.crear(widget.token, d))(
            datos,
          );
      if (mounted) Navigator.pop(context, cliente);
    } catch (e) {
      if (e is ClienteRechazado) _solicitud = null;
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
      title: Text(
        widget.cliente == null
            ? 'Crear empresa o cliente'
            : 'Agregar placas al cliente',
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Agregue las placas de carga que estarán disponibles al crear una orden. Puede guardar el cliente sin placas y agregarlas después.',
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
                  onChanged: _locked || widget.cliente != null
                      ? null
                      : (v) => setState(() => _tipo = v!),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombre,
                  enabled: !_locked && widget.cliente == null,
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
                  enabled: !_locked && widget.cliente == null,
                  maxLength: 20,
                  keyboardType: TextInputType.number,
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
                  enabled: !_locked,
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: _locked ? null : (_) => _agregar(),
                  decoration: InputDecoration(
                    labelText: 'Placa de carga',
                    hintText: 'ABC123',
                    errorText: _placaError,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _locked ? null : _agregar,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar placa'),
                ),
                Wrap(
                  spacing: 8,
                  children: _placas
                      .map(
                        (p) => InputChip(
                          label: Text(p),
                          onDeleted:
                              _locked ||
                                  (widget.cliente?.placasCarga.contains(p) ??
                                      false)
                              ? null
                              : () => setState(() => _placas.remove(p)),
                        ),
                      )
                      .toList(),
                ),
                if (_solicitud != null && !_saving)
                  const Text(
                    'El resultado anterior no se confirmó. Reintente la misma solicitud para evitar duplicados.',
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
          child: Text(
            _saving
                ? 'Guardando…'
                : widget.cliente == null
                ? 'Crear cliente'
                : 'Guardar placas',
          ),
        ),
      ],
    ),
  );
}
