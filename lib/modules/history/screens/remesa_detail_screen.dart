import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      if (!mounted) return;
      setState(() {
        _remesa = remesa;
        _manifiesto = manifiesto;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No fue posible cargar la informacion de esta remesa.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de remesa')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_remesa == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de remesa')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 44),
                const SizedBox(height: 12),
                Text(_error ?? 'Remesa no encontrada.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _DetailBody(remesa: _remesa!, manifiesto: _manifiesto);
  }
}

class _DetailBody extends StatelessWidget {
  final Remesa remesa;
  final Manifiesto? manifiesto;

  const _DetailBody({required this.remesa, this.manifiesto});

  @override
  Widget build(BuildContext context) {
    final r = remesa;
    final df = DateFormat('dd/MM/yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de remesa')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroSummary(remesa: r),
            if (r.errorDetalle?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _ErrorMessage(message: r.errorDetalle!),
            ],
            const SizedBox(height: 16),
            _InfoSection(
              title: 'Seguimiento',
              icon: Icons.track_changes_outlined,
              children: [
                _DetailRow('Estado RNDC', _statusLabel(r.estado)),
                _DetailRow('Creada', df.format(r.createdAt)),
                if (r.updatedAt != r.createdAt)
                  _DetailRow('Ultima actualizacion', df.format(r.updatedAt)),
                if (_notEmpty(r.radicadoRndc))
                  _DetailRow('Radicado RNDC', r.radicadoRndc!),
              ],
            ),
            const SizedBox(height: 12),
            _InfoSection(
              title: 'Ruta y participantes',
              icon: Icons.route_outlined,
              children: [
                _DetailRow(
                  'Generador',
                  _person(r.generadorNombre, r.generadorNit),
                ),
                _DetailRow(
                  'Origen',
                  _place(
                    r.remitenteNombre,
                    r.remitenteNit,
                    r.remitenteMunicipioDane,
                  ),
                ),
                if (_notEmpty(r.remitenteDireccion))
                  _DetailRow('Direccion de cargue', r.remitenteDireccion!),
                _DetailRow(
                  'Destino',
                  _place(
                    r.destinatarioNombre,
                    r.destinatarioNit,
                    r.destinatarioMunicipioDane,
                  ),
                ),
                if (_notEmpty(r.destinatarioDireccion))
                  _DetailRow(
                    'Direccion de descargue',
                    r.destinatarioDireccion!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoSection(
              title: 'Mercancia',
              icon: Icons.inventory_2_outlined,
              children: [
                _DetailRow(
                  'Producto',
                  r.descripcionProducto ?? 'Sin descripcion',
                ),
                _DetailRow('Peso', '${r.pesoKg} kg'),
                if (r.cantidad != null && r.cantidad! > 0)
                  _DetailRow(
                    'Cantidad',
                    '${r.cantidad} ${r.unidadMedida}'.trim(),
                  ),
                _DetailRow('Operacion', r.tipoOperacion),
                _DetailRow('Naturaleza de carga', r.naturalezaCarga),
                _DetailRow('Valor mercancia', _money(r.valorMercancia)),
                _DetailRow('Valor flete', _money(r.valorFlete)),
              ],
            ),
            if (_notEmpty(r.polizaNumero)) ...[
              const SizedBox(height: 12),
              _InfoSection(
                title: 'Poliza',
                icon: Icons.verified_user_outlined,
                children: [
                  _DetailRow('Numero', r.polizaNumero!),
                  if (_notEmpty(r.polizaAseguradora))
                    _DetailRow('Aseguradora', r.polizaAseguradora!),
                  if (r.polizaVencimiento != null)
                    _DetailRow(
                      'Vencimiento',
                      DateFormat('dd/MM/yyyy').format(r.polizaVencimiento!),
                    ),
                ],
              ),
            ],
            if (manifiesto != null) ...[
              const SizedBox(height: 12),
              _ManifiestoSection(manifiesto: manifiesto!),
            ],
            if (_notEmpty(r.observaciones)) ...[
              const SizedBox(height: 12),
              _InfoSection(
                title: 'Observaciones',
                icon: Icons.notes_outlined,
                children: [_DetailRow('Nota', r.observaciones!)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _notEmpty(String? value) => value?.trim().isNotEmpty == true;

  static String _person(String? name, String id) =>
      _notEmpty(name) ? '$name ($id)' : id;

  static String _place(String? name, String id, String municipality) {
    final party = _person(name, id);
    return municipality.isEmpty ? party : '$party - Municipio $municipality';
  }

  static String _money(num value) => NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  ).format(value);

  static String _statusLabel(String status) => switch (status) {
    'draft' => 'Borrador',
    'pending_rndc' => 'Pendiente de envio al RNDC',
    'sent_rndc' => 'Enviada al RNDC',
    'error_rndc' => 'Requiere correccion',
    'generated' => 'Generada',
    'cumplido' => 'Cumplida',
    'anulado' => 'Anulada',
    _ => status,
  };
}

class _HeroSummary extends StatelessWidget {
  final Remesa remesa;
  const _HeroSummary({required this.remesa});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = remesa.estado == 'error_rndc';
    final color = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.description_outlined,
            color: color,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remesa ${remesa.consecutivo}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _DetailBody._statusLabel(remesa.estado),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth < 390
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context),
                const SizedBox(height: 2),
                Text(value),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 145, child: _label(context)),
                Expanded(child: Text(value)),
              ],
            ),
    ),
  );

  Widget _label(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
  );
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage({required this.message});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManifiestoSection extends StatelessWidget {
  final Manifiesto manifiesto;
  const _ManifiestoSection({required this.manifiesto});
  @override
  Widget build(BuildContext context) => _InfoSection(
    title: 'Manifiesto ${manifiesto.consecutivo}',
    icon: Icons.local_shipping_outlined,
    children: [
      _DetailRow('Estado', _DetailBody._statusLabel(manifiesto.estado)),
      _DetailRow('Placa', manifiesto.placaVehiculo),
      _DetailRow(
        'Conductor',
        manifiesto.conductorNombre ?? manifiesto.conductorCedula,
      ),
      _DetailRow('Valor del viaje', _DetailBody._money(manifiesto.valorViaje)),
      _DetailRow('Anticipo', _DetailBody._money(manifiesto.valorAnticipo)),
      _DetailRow('Saldo', _DetailBody._money(manifiesto.valorSaldo)),
      if (_DetailBody._notEmpty(manifiesto.radicadoRndc))
        _DetailRow('Radicado RNDC', manifiesto.radicadoRndc!),
    ],
  );
}
