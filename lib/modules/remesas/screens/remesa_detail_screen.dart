import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/manifiesto.dart';
import '../../../data/models/remesa.dart';
import '../../../services/api_service.dart';

class RemesaDetailScreen extends StatefulWidget {
  final String remesaId;

  const RemesaDetailScreen({super.key, required this.remesaId});

  @override
  State<RemesaDetailScreen> createState() => _RemesaDetailScreenState();
}

class _RemesaDetailScreenState extends State<RemesaDetailScreen> {
  Remesa? _remesa;
  Manifiesto? _manifiesto;
  bool _loading = true;
  bool _cumpliendo = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.obtenerRemesa(widget.remesaId);
      final remesa = Remesa.fromMap(
        Map<String, dynamic>.from(data['remesa'] as Map),
      );
      final manifiestoData = data['manifiesto'];
      final manifiesto = manifiestoData == null
          ? null
          : Manifiesto.fromMap(
              Map<String, dynamic>.from(manifiestoData as Map),
            );

      if (mounted) {
        setState(() {
          _remesa = remesa;
          _manifiesto = manifiesto;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cumplirRemesa() async {
    if (_remesa == null) return;

    final tipo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cumplir Remesa'),
        content: const Text('Seleccione el tipo de cumplido:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'N'),
            child: const Text('Normal (N)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'S'),
            child: const Text('Suspensión (S)'),
          ),
        ],
      ),
    );

    if (tipo == null || !mounted) return;

    setState(() => _cumpliendo = true);

    final auth = context.read<AuthProvider>();
    final result = await ApiService.cumplirRemesa(
      rndcUsername: auth.user!.email,
      rndcPassword: auth.user!.password,
      remesaId: _remesa!.id,
      tipocumplido: tipo,
    );

    if (!mounted) return;
    setState(() => _cumpliendo = false);

    if (result.exito) {
      _snack('Remesa cumplida exitosamente');
      _manifiesto = null;
      _load();
    } else {
      _snack(result.error ?? 'Error al cumplir remesa');
    }
  }

  Future<void> _crearManifiesto() async {
    if (_remesa == null) return;
    context.push('/manifiestos/nuevo',
        extra: _remesa!.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_remesa == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remesa')),
        body: const Center(child: Text('Remesa no encontrada')),
      );
    }
    return _DetailBody(
      remesa: _remesa!,
      manifiesto: _manifiesto,
      onCumplir: _cumplirRemesa,
      onCrearManifiesto: _crearManifiesto,
      cumpliendo: _cumpliendo,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Remesa remesa;
  final Manifiesto? manifiesto;
  final VoidCallback onCumplir;
  final VoidCallback onCrearManifiesto;
  final bool cumpliendo;

  const _DetailBody({
    required this.remesa,
    this.manifiesto,
    required this.onCumplir,
    required this.onCrearManifiesto,
    required this.cumpliendo,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final r = remesa;
    final m = manifiesto;

    return Scaffold(
      appBar: AppBar(title: Text('Remesa #${r.consecutivo}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row('Estado', _statusLabel(r.estado)),
            _Row('Consecutivo', r.consecutivo),
            _Row('Creado', df.format(r.createdAt)),
            if (r.updatedAt != r.createdAt)
              _Row('Actualizado', df.format(r.updatedAt)),
            if (r.radicadoRndc != null)
              _Row('Radicado RNDC', r.radicadoRndc!),
            if (r.errorDetalle != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Text('Error: ${r.errorDetalle}',
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ],
            const Divider(height: 28),
            _Section('Generador'),
            _Value(r.generadorNit),
            if (r.generadorNombre != null) _Value(r.generadorNombre!),
            const Divider(height: 28),
            _Section('Origen (Cargue)'),
            _Value(r.remitenteNit),
            if (r.remitenteNombre != null) _Value(r.remitenteNombre!),
            if (r.remitenteDireccion != null)
              _Value('Dir: ${r.remitenteDireccion}'),
            _Value('Municipio DANE: ${r.remitenteMunicipioDane}'),
            const Divider(height: 28),
            _Section('Destino (Descargue)'),
            _Value(r.destinatarioNit),
            if (r.destinatarioNombre != null) _Value(r.destinatarioNombre!),
            if (r.destinatarioDireccion != null)
              _Value('Dir: ${r.destinatarioDireccion}'),
            _Value('Municipio DANE: ${r.destinatarioMunicipioDane}'),
            const Divider(height: 28),
            _Section('Mercancía'),
            _Value('Peso: ${r.pesoKg} kg'),
            if (r.descripcionProducto != null)
              _Value('Producto: ${r.descripcionProducto}'),
            if (r.cantidad != null && r.cantidad! > 0)
              _Value('Cantidad: ${r.cantidad} ${r.unidadMedida}'),
            _Value('Naturaleza: ${r.naturalezaCarga}'),
            _Value('Operación: ${r.tipoOperacion}'),
            _Value('Valor mercancía: \$${r.valorMercancia.toStringAsFixed(0)}'),
            _Value('Valor flete: \$${r.valorFlete.toStringAsFixed(0)}'),
            if (r.polizaNumero != null) ...[
              const Divider(height: 28),
              _Section('Póliza'),
              _Value('No: ${r.polizaNumero}'),
              if (r.polizaAseguradora != null)
                _Value(r.polizaAseguradora!),
              if (r.polizaVencimiento != null)
                _Value('Vence: ${DateFormat('dd/MM/yyyy').format(r.polizaVencimiento!)}'),
            ],
            if (r.clienteNombre != null) ...[
              const Divider(height: 28),
              _Section('Cliente'),
              _Value(r.clienteNombre!),
              if (r.obra != null) _Value('Obra: ${r.obra}'),
              if (r.programa != null) _Value('Programa: ${r.programa}'),
            ],
            if (m != null) ...[
              const Divider(height: 28),
              _Section('Manifiesto ${m.consecutivo}'),
              _Row('Estado', _statusLabel(m.estado)),
              _Value('Placa: ${m.placaVehiculo}'),
              _Value('Conductor: ${m.conductorNombre ?? m.conductorCedula}'),
              _Value('Valor viaje: \$${m.valorViaje.toStringAsFixed(0)}'),
              _Value('Anticipo: \$${m.valorAnticipo.toStringAsFixed(0)}'),
              _Value('Saldo: \$${m.valorSaldo.toStringAsFixed(0)}'),
              if (m.radicadoRndc != null)
                _Value('Radicado RNDC: ${m.radicadoRndc}'),
              if (m.numeroAutorizacion != null)
                _Value('Autorización: ${m.numeroAutorizacion}'),
              if (m.errorDetalle != null && m.errorDetalle!.isNotEmpty)
                _Value('Error RNDC: ${m.errorDetalle}'),
              if (m.pdfUrl != null) _Value('PDF: ${m.pdfUrl}'),
            ],
            if (r.observaciones != null && r.observaciones!.isNotEmpty) ...[
              const Divider(height: 28),
              _Section('Observaciones'),
              _Value(r.observaciones!),
            ],
            if (r.rawMessage != null) ...[
              const Divider(height: 28),
              _Section('Mensaje original'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(r.rawMessage!,
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ),
            ],
            const SizedBox(height: 24),
            if (r.estado == 'generated' &&
                (m == null || m.estado == 'error_rndc'))
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCrearManifiesto,
                  icon: Icon(m == null ? Icons.add_circle : Icons.refresh),
                  label: Text(m == null
                      ? 'Crear Manifiesto'
                      : 'Corregir y reintentar manifiesto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (m?.estado == 'generated' && r.estado == 'generated') ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cumpliendo ? null : onCumplir,
                  icon: cumpliendo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: Text(cumpliendo
                      ? 'Cumpliendo...'
                      : 'Cumplir Remesa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (r.estado == 'cumplido')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Remesa cumplida',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    return switch (s) {
      'draft' => 'Borrador',
      'pending_rndc' => 'Pendiente RNDC',
      'sent_rndc' => 'Enviada RNDC',
      'error_rndc' => 'Error RNDC',
      'generated' => 'Completada',
      'cumplido' => 'Cumplido',
      'anulado' => 'Anulado',
      _ => s,
    };
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary));
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  final String text;
  const _Value(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text,
          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
    );
  }
}
