import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/contacto_escolta.dart';

class VehiculosUsuarioScreen extends StatefulWidget {
  final String usuario;
  final String nombre;
  const VehiculosUsuarioScreen({
    super.key,
    required this.usuario,
    required this.nombre,
  });
  @override
  State<VehiculosUsuarioScreen> createState() => _VehiculosUsuarioScreenState();
}

class _VehiculosUsuarioScreenState extends State<VehiculosUsuarioScreen> {
  final _placas = TextEditingController();
  final _destino = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _placas.dispose();
    _destino.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ContactoEscolta.cargar(usuario: widget.usuario);
      if (!mounted) return;
      _placas.text = c.placas.join(', ');
      _destino.text = c.destino;
    } catch (_) {
      if (mounted) {
        _error =
            'No se pudo cargar la configuración. Revise la migración de contactos.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _lista => _placas.text
      .toUpperCase()
      .split(RegExp(r'[,\s]+'))
      .where((p) => p.isNotEmpty)
      .toSet()
      .toList();
  Future<void> _save(bool destino) async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (destino) {
        await ApiService.guardarDestinoWhatsapp(
          normalizarCelular(_destino.text),
        );
      } else {
        await ApiService.guardarVehiculosEscolta(widget.usuario, _lista);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              destino
                  ? 'Destino de WhatsApp actualizado para todas las órdenes.'
                  : 'Vehículos del usuario actualizados.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardaron los cambios. Vuelva a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Vehículos de ${widget.nombre}')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _load,
                    child: const Text('Recargar'),
                  ),
                ],
                TextFormField(
                  controller: _placas,
                  enabled: !_saving,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Placas de los vehículos escolta',
                    helperText: 'Separadas por comas. Ejemplo: ABC123, MNB124',
                    helperMaxLines: 3,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (_) =>
                      _lista.length > 30 ||
                          _lista.any(
                            (p) => !RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(p),
                          )
                      ? 'Revise las placas: tres letras y tres números.'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : () => _save(false),
                  child: const Text('Guardar vehículos'),
                ),
                const Divider(height: 32),
                Text(
                  'Destino de todas las órdenes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este número recibe las órdenes por WhatsApp; es independiente del celular del usuario.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _destino,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de WhatsApp destinatario',
                    hintText: '+57 322 350 9469',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: Icon(Icons.chat_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                  validator: (s) => (s ?? '').trim().isEmpty
                      ? 'Ingrese el destinatario.'
                      : validarCelular(s),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(true),
                  child: const Text('Guardar destinatario'),
                ),
              ],
            ),
          ),
  );
}
