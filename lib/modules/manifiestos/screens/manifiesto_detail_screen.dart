import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/manifiesto.dart';
import '../../../data/models/remesa.dart';
import '../../../services/api_service.dart';
import '../providers/firma_provider.dart';

class ManifiestoDetailScreen extends StatefulWidget {
  final String manifiestoId;

  const ManifiestoDetailScreen({super.key, required this.manifiestoId});

  @override
  State<ManifiestoDetailScreen> createState() => _ManifiestoDetailScreenState();
}

class _ManifiestoDetailScreenState extends State<ManifiestoDetailScreen> {
  Manifiesto? _manifiesto;
  Remesa? _remesa;
  bool _loading = true;
  bool _cumpliendo = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.obtenerManifiesto(widget.manifiestoId);
      final m = Manifiesto.fromMap(
        Map<String, dynamic>.from(data['manifiesto'] as Map),
      );
      final remesaData = data['remesa'];
      final remesa = remesaData == null
          ? null
          : Remesa.fromMap(Map<String, dynamic>.from(remesaData as Map));

      if (mounted) {
        setState(() {
          _manifiesto = m;
          _remesa = remesa;
          _loading = false;
        });
      }

      if (m.estado == 'generated') {
        _refreshFirma();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFirma() async {
    final auth = context.read<AuthProvider>();
    final fp = context.read<FirmaProvider>();
    if (auth.user != null && _manifiesto != null) {
      await fp.consultarFirma(
        rndcUsername: auth.user!.email,
        rndcPassword: auth.user!.password,
        manifiestoId: _manifiesto!.id,
      );
    }
  }

  Future<void> _cumplirManifiesto() async {
    if (_manifiesto == null) return;

    final tipo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cumplir Manifiesto'),
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
    final result = await ApiService.cumplirManifiesto(
      rndcUsername: auth.user!.email,
      rndcPassword: auth.user!.password,
      manifiestoId: _manifiesto!.id,
      tipoCumplido: tipo,
    );

    if (!mounted) return;
    setState(() => _cumpliendo = false);

    if (result.exito) {
      _snack('Manifiesto cumplido exitosamente');
      _load();
    } else {
      _snack(result.error ?? 'Error al cumplir manifiesto');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_manifiesto == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manifiesto')),
        body: const Center(child: Text('Manifiesto no encontrado')),
      );
    }

    final fp = context.watch<FirmaProvider>();
    final firmaStatus = fp.status;

    return _DetailBody(
      manifiesto: _manifiesto!,
      remesa: _remesa,
      onCumplir: _cumplirManifiesto,
      cumpliendo: _cumpliendo,
      firmaStatus: firmaStatus,
      onRefreshFirma: _refreshFirma,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Manifiesto manifiesto;
  final Remesa? remesa;
  final VoidCallback onCumplir;
  final bool cumpliendo;
  final ManifiestoFirmaStatus? firmaStatus;
  final Future<void> Function() onRefreshFirma;

  const _DetailBody({
    required this.manifiesto,
    this.remesa,
    required this.onCumplir,
    required this.cumpliendo,
    this.firmaStatus,
    required this.onRefreshFirma,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final m = manifiesto;
    final r = remesa;
    final requiereFirma = m.aceptacionElectronica == 'SI';
    final firmaCompleta = firmaStatus?.estaCompleto ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manifiesto #${m.consecutivo}'),
        actions: [
          if (m.estado == 'generated' && requiereFirma)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar estado de firma',
              onPressed: onRefreshFirma,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await onRefreshFirma();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row('Estado', _statusLabel(m.estado)),
              _Row('Consecutivo', m.consecutivo),
              _Row('Creado', df.format(m.createdAt)),
              if (m.updatedAt != m.createdAt)
                _Row('Actualizado', df.format(m.updatedAt)),
              if (requiereFirma) ...[
                const SizedBox(height: 12),
                _FirmaStatusBadge(firmaStatus: firmaStatus),
              ],
              if (requiereFirma && firmaStatus != null && !firmaCompleta) ...[
                const SizedBox(height: 8),
                _FirmaActionBanner(firmaStatus: firmaStatus!),
              ],
              const Divider(height: 28),
              _Section('Vehículo'),
              _Value('Placa: ${m.placaVehiculo}'),
              if (m.placaRemolque != null && m.placaRemolque!.isNotEmpty)
                _Value('Remolque: ${m.placaRemolque}'),
              const Divider(height: 28),
              _Section('Conductor'),
              _Value('Cédula: ${m.conductorCedula}'),
              if (m.conductorNombre != null)
                _Value('Nombre: ${m.conductorNombre}'),
              if (m.conductor2Cedula != null && m.conductor2Cedula!.isNotEmpty)
                _Value('2do conductor: ${m.conductor2Cedula}'),
              if (m.propietarioCedula != null &&
                  m.propietarioCedula!.isNotEmpty)
                _Value('Propietario: ${m.propietarioCedula}'),
              const Divider(height: 28),
              _Section('Económicas'),
              _Value('Valor viaje: \$${m.valorViaje.toStringAsFixed(0)}'),
              _Value('Anticipo: \$${m.valorAnticipo.toStringAsFixed(0)}'),
              _Value('Saldo: \$${m.valorSaldo.toStringAsFixed(0)}'),
              _Value('Tipo valor: ${_tipoLabel(m.tipoValorPactado)}'),
              if (m.municipioPagoDane != null)
                _Value('Pago municipio DANE: ${m.municipioPagoDane}'),
              if (m.fechaLimitePago != null)
                _Value('Límite pago: ${df.format(m.fechaLimitePago!)}'),
              const Divider(height: 28),
              _Section('Programación'),
              if (m.fechaDespacho != null)
                _Value('Despacho: ${df.format(m.fechaDespacho!)}'),
              if (m.fechaLimiteEntrega != null)
                _Value('Límite entrega: ${df.format(m.fechaLimiteEntrega!)}'),
              _Value('Resp. cargue: ${m.respCargue}'),
              _Value('Resp. descargue: ${m.respDescargue}'),
              _Value('Horas espera cargue: ${m.horasEsperaCargue}'),
              _Value('Horas espera descargue: ${m.horasEsperaDescargue}'),
              if (requiereFirma) ...[
                const Divider(height: 28),
                _Section('Aceptación Electrónica'),
                _Value('Estado: ${_firmaEstadoLabel(firmaStatus?.estado)}'),
              ],
              if (m.radicadoRndc != null) ...[
                const Divider(height: 28),
                _Section('Respuesta RNDC'),
                _Value('Radicado: ${m.radicadoRndc}'),
                _Value('Autorización: ${m.numeroAutorizacion ?? '—'}'),
                if (m.pdfUrl != null) _Value('PDF: ${m.pdfUrl}'),
              ],
              if (m.observaciones != null && m.observaciones!.isNotEmpty) ...[
                const Divider(height: 28),
                _Section('Observaciones'),
                _Value(m.observaciones!),
              ],
              if (r != null) ...[
                const Divider(height: 28),
                _Section('Remesa asociada'),
                _Value('Consecutivo: ${r.consecutivo}'),
                _Value('Cliente: ${r.clienteNombre ?? '—'}'),
                _Value('Peso: ${r.pesoKg} kg'),
                _Value('Origen DANE: ${r.remitenteMunicipioDane}'),
                _Value('Destino DANE: ${r.destinatarioMunicipioDane}'),
              ],
              const SizedBox(height: 24),
              if (m.estado == 'generated')
                _CumplirButton(
                  cumpliendo: cumpliendo,
                  onCumplir: onCumplir,
                  firmaStatus: firmaStatus,
                  requiereFirma: requiereFirma,
                ),
              if (m.estado == 'completado')
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
                      Text(
                        'Viaje completado',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _tipoLabel(String t) {
    return switch (t) {
      'B' => 'Por viaje',
      'K' => 'Por kilo',
      'G' => 'Por galón',
      _ => t,
    };
  }

  String _statusLabel(String s) {
    return switch (s) {
      'draft' => 'Borrador',
      'generated' => 'Activo',
      'completado' => 'Completado',
      'anulado' => 'Anulado',
      _ => s,
    };
  }

  String _firmaEstadoLabel(String? estado) {
    return switch (estado) {
      'completo' => 'Firmado (completo)',
      'pendiente_conductor' => 'Pendiente firma del Conductor',
      'pendiente_titular' => 'Pendiente firma del Titular',
      'pendiente_ambos' => 'Pendiente firma del Conductor y Titular',
      'desconocido' => 'No disponible',
      _ => 'Sin datos',
    };
  }
}

class _FirmaStatusBadge extends StatelessWidget {
  final ManifiestoFirmaStatus? firmaStatus;
  const _FirmaStatusBadge({this.firmaStatus});

  @override
  Widget build(BuildContext context) {
    if (firmaStatus == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Text(
              'Estado de firma: consultando...',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final fs = firmaStatus!;
    final isComplete = fs.estaCompleto;
    final color = isComplete ? Colors.green : Colors.orange;
    final icon = isComplete ? Icons.check_circle : Icons.pending;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                isComplete
                    ? 'Firmado — Aceptación completa'
                    : 'Firma: ${_estadoLabel(fs.estado)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color[800],
                ),
              ),
            ],
          ),
          if (fs.firmaConductor != null) ...[
            const SizedBox(height: 6),
            Text(
              'FIRMA CONDUCTOR: ${DateFormat('dd/MM/yyyy HH:mm').format(fs.firmaConductor!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          if (fs.firmaTitular != null) ...[
            const SizedBox(height: 2),
            Text(
              'FIRMA TITULAR: ${DateFormat('dd/MM/yyyy HH:mm').format(fs.firmaTitular!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  String _estadoLabel(String estado) {
    return switch (estado) {
      'pendiente_conductor' => 'Pendiente del Conductor',
      'pendiente_titular' => 'Pendiente del Titular',
      'pendiente_ambos' => 'Pendiente del Conductor y Titular',
      _ => estado,
    };
  }
}

class _FirmaActionBanner extends StatelessWidget {
  final ManifiestoFirmaStatus firmaStatus;
  const _FirmaActionBanner({required this.firmaStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este manifiesto requiere aceptación electrónica del Conductor y/o Titular. '
            'Deben firmarlo desde la app oficial RNDC Transportador (disponible en Play Store).',
            style: TextStyle(fontSize: 12, color: Colors.blue[800]),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.rndc.transportador',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text(
                'Abrir Play Store',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CumplirButton extends StatelessWidget {
  final bool cumpliendo;
  final VoidCallback onCumplir;
  final ManifiestoFirmaStatus? firmaStatus;
  final bool requiereFirma;

  const _CumplirButton({
    required this.cumpliendo,
    required this.onCumplir,
    this.firmaStatus,
    required this.requiereFirma,
  });

  @override
  Widget build(BuildContext context) {
    final String? disabledReason = _getDisabledReason();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (cumpliendo || disabledReason != null)
                ? null
                : onCumplir,
            icon: cumpliendo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle),
            label: Text(cumpliendo ? 'Cumpliendo...' : 'Cumplir Manifiesto'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              disabledBackgroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.red[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  disabledReason,
                  style: TextStyle(fontSize: 11, color: Colors.red[400]),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String? _getDisabledReason() {
    if (!requiereFirma) return null;
    if (firmaStatus == null) return 'Consultando estado de firma...';
    if (firmaStatus!.estaCompleto) return null;
    return firmaStatus!.resumenFalta;
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
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
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
      ),
    );
  }
}
