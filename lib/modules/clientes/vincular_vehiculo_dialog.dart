import 'package:flutter/material.dart';
import 'clientes_api.dart';

class VincularVehiculoDialog extends StatefulWidget {
  final String token;
  final String clienteId;
  final String nombre;
  const VincularVehiculoDialog({
    super.key,
    required this.token,
    required this.clienteId,
    required this.nombre,
  });
  @override
  State<VincularVehiculoDialog> createState() => _VincularVehiculoDialogState();
}

class _VincularVehiculoDialogState extends State<VincularVehiculoDialog> {
  late Future<List<Map<String, dynamic>>> _vehiculos;
  String? _seleccion;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _vehiculos = ClientesApi.vehiculos(widget.token);
  }

  Future<void> _guardar() async {
    if (_saving || _seleccion == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ClientesApi.vincular(widget.token, widget.clienteId, _seleccion!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se guardó la asociación. Reintente con el mismo vehículo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Vehículo de ${widget.nombre}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _vehiculos,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el catálogo de vehículos.'),
                    TextButton(
                      onPressed: () => setState(
                        () => _vehiculos = ClientesApi.vehiculos(widget.token),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const Text(
                  'Primero registre el vehículo de carga en el módulo Vehículos. Después podrá vincularlo a este cliente.',
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccione un vehículo de carga registrado. Esta asociación es independiente de los carros del escolta.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _seleccion,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Placa de carga',
                      border: OutlineInputBorder(),
                    ),
                    items: rows
                        .map(
                          (r) => DropdownMenuItem(
                            value: r['id'].toString(),
                            child: Text(r['placa'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _seleccion = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving || _seleccion == null ? null : _guardar,
          child: Text(_saving ? 'Guardando…' : 'Vincular vehículo'),
        ),
      ],
    ),
  );
}
