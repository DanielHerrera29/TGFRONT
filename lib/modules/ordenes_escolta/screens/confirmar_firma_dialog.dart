import '../borrador_orden.dart';

import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class ConfirmarFirmaDialog extends StatefulWidget {
  final String token, ordenId;

  final BorradorOrden draft;
  const ConfirmarFirmaDialog({
    super.key,
    required this.token,
    required this.ordenId,

    required this.draft,
  });
  @override
  State<ConfirmarFirmaDialog> createState() => _ConfirmarFirmaDialogState();
}

class _ConfirmarFirmaDialogState extends State<ConfirmarFirmaDialog> {
  final _nombre = TextEditingController(),
      _email = TextEditingController(),
      _codigo = TextEditingController();
  String? _id, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final saved = widget.draft.state['firmaOtp'] as Map?;
    _nombre.text = saved?['nombre'] ?? '';
    _email.text = saved?['email'] ?? '';
    _id = saved?['email'] == null ? null : saved?['id'];
  }

  Future<void> _persistir() async {
    widget.draft.state['firmaOtp'] = {
      'nombre': _nombre.text.trim(),
      'email': _email.text.trim(),
      'id': _id,
    };
    await widget.draft.persist();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _persistir();
      final result = await ApiService.operacionFirma(
        widget.token,
        widget.ordenId,
        'solicitar',
        {'nombre': _nombre.text.trim(), 'email': _email.text.trim()},
      );
      if (!mounted) return;
      if (result['estado'] == 'VERIFICADA') {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _id = result['id'] as String?;
        if (result['estado'] != 'PENDIENTE') {
          _error =
              'Solicitud en curso. Si no recibe el código, espere diez minutos antes de solicitar otro.';
        }
      });
      await _persistir();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _comprobar() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_codigo.text.trim())) {
      setState(() => _error = 'Ingrese los seis dígitos.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _persistir();
      final result = await ApiService.operacionFirma(
        widget.token,
        widget.ordenId,
        'comprobar',
        {'id': _id, 'codigo': _codigo.text.trim()},
      );
      if (!mounted) return;
      if (result['estado'] == 'VERIFICADA') {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _error = 'Código incorrecto o intentos agotados.');
      await _persistir();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Desbloquear firma'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingrese el correo del arquitecto y pida el código. Al comprobarlo, se habilitará el botón Firmar en esta orden.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                enabled: !_busy && _id == null,
                decoration: const InputDecoration(
                  labelText: 'Nombre del arquitecto',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                enabled: !_busy && _id == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo del arquitecto (Gmail)',
                  hintText: 'arquitecto@gmail.com',
                ),
              ),
              if (_id != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codigo,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Código de seis dígitos',
                    helperText: 'Vence en diez minutos. Máximo cinco intentos.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_id != null)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _id = null;
                      _error = null;
                      _codigo.clear();
                    });
                    await _persistir();
                  },
            child: const Text('Recuperar / solicitar otro código'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Continuar después'),
        ),
        FilledButton(
          onPressed: _busy ? null : (_id == null ? _enviar : _comprobar),
          child: Text(_id == null ? 'Pedir código' : 'Validar código'),
        ),
      ],
    ),
  );
}
