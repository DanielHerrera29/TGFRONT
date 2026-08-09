import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/widgets/municipio_picker_field.dart';
import '../providers/remesa_provider.dart';
import '../providers/manifiesto_provider.dart';
import '../widgets/parse_preview.dart';

class NewDispatchScreen extends StatefulWidget {
  const NewDispatchScreen({super.key});

  @override
  State<NewDispatchScreen> createState() => _NewDispatchScreenState();
}

class _NewDispatchScreenState extends State<NewDispatchScreen> {
  final _msgCtrl = TextEditingController();
  final _nitClienteCtrl = TextEditingController();
  MunicipioDane? _municipioDestino;
  final _placaCtrl = TextEditingController();
  final _conductorCedulaCtrl = TextEditingController();
  final _valorViajeCtrl = TextEditingController();
  final _valorAnticipoCtrl = TextEditingController();

  int _step = 1; // 1=parse, 2=confirm remesa, 3=manifiesto form, 4=done
  bool _despachoInmediato = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _nitClienteCtrl.dispose();
    _placaCtrl.dispose();
    _conductorCedulaCtrl.dispose();
    _valorViajeCtrl.dispose();
    _valorAnticipoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RemesaProvider>();
    final mp = context.watch<ManifiestoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 1
              ? 'Nuevo Despacho'
              : _step == 2
              ? 'Confirmar Remesa'
              : _step == 3
              ? 'Completar Manifiesto'
              : 'Despacho Creado',
        ),
        actions: [
          if (_step > 1 && _step < 4)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                rp.clear();
                mp.clear();
                _msgCtrl.clear();
                _placaCtrl.clear();
                _conductorCedulaCtrl.clear();
                _valorViajeCtrl.clear();
                _valorAnticipoCtrl.clear();
                setState(() => _step = 1);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _step == 1
            ? _buildParseStep(rp)
            : _step == 2
            ? _buildConfirmStep(rp)
            : _step == 3
            ? _buildManifiestoStep(rp, mp)
            : _buildDoneStep(rp, mp),
      ),
    );
  }

  // ---- STEP 1: Paste & Parse ----
  Widget _buildParseStep(RemesaProvider rp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pegar mensaje de WhatsApp',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Pega el mensaje con los datos del despacho.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _msgCtrl,
          maxLines: 8,
          decoration: InputDecoration(
            hintText:
                '🔘CONDUCTOR: Víctor Gonzalez\n🔘PLACA: SWM585\n🔘CLIENTE: INCOMINERIA\n...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: rp.processing ? null : _process,
            icon: rp.processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.preview),
            label: Text(rp.processing ? 'Procesando...' : 'Procesar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (rp.remesaActual != null) ...[
          const SizedBox(height: 20),
          RemesaPreview(data: rp.remesaActual!),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() => _step = 2),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continuar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- STEP 2: Confirm Remesa ----
  Widget _buildConfirmStep(RemesaProvider rp) {
    final r = rp.remesaActual!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Resumen de Remesa'),
        const SizedBox(height: 12),
        _row('Cliente', r.clienteNombre ?? '—'),
        _row('Origen', r.origen ?? r.remitenteDireccion ?? '—'),
        _row('Destino', r.destino ?? r.destinatarioDireccion ?? '—'),
        _row('Peso', '${r.pesoKg} kg'),
        _row('Tipo carga', r.tipoCarga ?? '—'),
        _row('Conductor', r.conductorNombre ?? '—'),
        _row('Placa', r.placa ?? '—'),
        if (r.observaciones != null) _row('Obs', r.observaciones!),
        const Divider(height: 24),
        _row('Generador NIT', r.generadorNit),
        _row('Generador', r.generadorNombre ?? 'N/A'),
        _row('Póliza', r.polizaNumero ?? 'N/A'),
        _row('Modo', r.polizaAseguradora != null ? 'Con póliza' : 'Sin póliza'),
        const SizedBox(height: 16),
        TextField(
          controller: _nitClienteCtrl,
          decoration: _input('NIT del cliente', Icons.badge_outlined),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        MunicipioPickerField(
          label: 'Municipio destino',
          value: _municipioDestino,
          onSelected: (municipio) => setState(() {
            _municipioDestino = municipio;
          }),
        ),
        const SizedBox(height: 20),
        if (rp.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rp.error!,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Despacho inmediato',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            _despachoInmediato
                ? 'Genera remesa + manifiesto automáticamente'
                : 'Solo genera la remesa. Puede crear el manifiesto después.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: _despachoInmediato,
          onChanged: (v) => setState(() => _despachoInmediato = v),
        ),
        if (rp.loading)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _generarRemesa,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(
                    _despachoInmediato
                        ? 'Generar Remesa (RNDC)'
                        : 'Generar Remesa (RNDC)',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- STEP 3: Complete Manifiesto ----
  Widget _buildManifiestoStep(RemesaProvider rp, ManifiestoProvider mp) {
    final r = rp.remesaActual!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Datos del viaje (desde Remesa)'),
        const SizedBox(height: 8),
        _row('Cliente', r.clienteNombre ?? '—'),
        _row('Origen', r.origen ?? r.remitenteDireccion ?? '—'),
        _row('Destino', r.destino ?? r.destinatarioDireccion ?? '—'),
        _row('Peso', '${r.pesoKg} kg'),
        const Divider(height: 20),
        _section('Completar Manifiesto'),
        const SizedBox(height: 12),
        TextField(
          controller: _placaCtrl,
          decoration: _input('Placa vehículo', Icons.directions_car),
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => mp.updatePlaca(v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conductorCedulaCtrl,
          decoration: _input('Cédula conductor', Icons.badge_outlined),
          keyboardType: TextInputType.number,
          onChanged: (v) => mp.updateConductorCedula(v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _valorViajeCtrl,
          decoration: _input('Valor viaje (\$)', Icons.attach_money),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => mp.updateValorViaje(double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _valorAnticipoCtrl,
          decoration: _input('Valor anticipo (\$)', Icons.money_off),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => mp.updateValorAnticipo(double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 20),
        if (mp.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              mp.error!,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
        if (mp.loading)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 2),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _generarManifiesto,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Generar Manifiesto (RNDC)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---- STEP 4: Done ----
  Widget _buildDoneStep(RemesaProvider rp, ManifiestoProvider mp) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle, size: 72, color: Colors.green[400]),
        const SizedBox(height: 16),
        Text(
          _despachoInmediato
              ? 'Despacho creado exitosamente'
              : 'Remesa creada exitosamente',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _RadicadoCard(
          titulo: 'REMESA RNDC',
          numero: rp.ultimoResultado?.radicadoRndc ?? '—',
          consecutivo: rp.ultimoResultado?.consecutivo ?? '—',
        ),
        if (_despachoInmediato) ...[
          const SizedBox(height: 12),
          _RadicadoCard(
            titulo: 'AUTORIZACIÓN MANIFIESTO',
            numero: mp.ultimoResultado?.numeroAutorizacion ?? '—',
            consecutivo: mp.ultimoResultado?.consecutivo ?? '—',
            destacado: true,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _compartir,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Compartir con conductor'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final id = rp.ultimoResultado?.remesaId;
              if (id != null) {
                rp.clear();
                mp.clear();
                _msgCtrl.clear();
                _placaCtrl.clear();
                _conductorCedulaCtrl.clear();
                _valorViajeCtrl.clear();
                _valorAnticipoCtrl.clear();
                setState(() => _step = 1);
                context.push('/remesas/$id');
              }
            },
            icon: const Icon(Icons.visibility),
            label: const Text('Ver remesa y crear manifiesto'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            rp.clear();
            mp.clear();
            _msgCtrl.clear();
            _nitClienteCtrl.clear();
            _placaCtrl.clear();
            _conductorCedulaCtrl.clear();
            _valorViajeCtrl.clear();
            _valorAnticipoCtrl.clear();
            setState(() => _step = 1);
          },
          icon: const Icon(Icons.add),
          label: const Text('Nuevo despacho'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Actions ----
  void _process() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      _snack('Pega el mensaje primero');
      return;
    }
    context.read<RemesaProvider>().setRawMessage(text);
    context.read<RemesaProvider>().parse(context.read<SettingsProvider>());
  }

  Future<void> _generarRemesa() async {
    final nit = _nitClienteCtrl.text.trim();
    final municipioDestino = _municipioDestino?.codigoDane ?? '';
    if (nit.isEmpty) {
      _snack('Ingrese el NIT del cliente');
      return;
    }
    if (nit.length < 6) {
      _snack('Ingrese un NIT completo. Para pruebas use 9001112221.');
      return;
    }
    if (municipioDestino.length != 5) {
      _snack('Seleccione el municipio destino de la lista.');
      return;
    }

    final municipioDestinoRncd = municipioDestino.length == 5
        ? '${municipioDestino}000'
        : municipioDestino;

    final remesaActual = context.read<RemesaProvider>().remesaActual;
    if (remesaActual != null &&
        municipioDestinoRncd == remesaActual.remitenteMunicipioDane) {
      _snack('El municipio destino debe ser diferente al municipio origen.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final remesaProvider = context.read<RemesaProvider>();

    remesaProvider.setDestinatarioNit(nit);
    remesaProvider.setDestinatarioMunicipioDane(municipioDestino);

    final ok = await remesaProvider.enviarARndc(
      rndcUsername: authProvider.user!.email,
      rndcPassword: authProvider.user!.password,
    );

    if (!mounted) return;

    if (ok) {
      if (_despachoInmediato) {
        final remesa = remesaProvider.remesaActual!;
        context.read<ManifiestoProvider>().prepararDesdeRemesa(remesa);
        _placaCtrl.text = remesa.placa ?? '';
        _conductorCedulaCtrl.text = remesa.conductorDocumento ?? '';
        setState(() => _step = 3);
      } else {
        setState(() => _step = 4);
      }
    }
  }

  Future<void> _generarManifiesto() async {
    if (_placaCtrl.text.trim().isEmpty) {
      _snack('Ingrese la placa del vehículo');
      return;
    }
    if (_conductorCedulaCtrl.text.trim().isEmpty) {
      _snack('Ingrese la cédula del conductor');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final manifiestoProvider = context.read<ManifiestoProvider>();

    manifiestoProvider.updatePlaca(_placaCtrl.text.trim().toUpperCase());
    manifiestoProvider.updateConductorCedula(_conductorCedulaCtrl.text.trim());

    final ok = await manifiestoProvider.enviarARndc(
      rndcUsername: authProvider.user!.email,
      rndcPassword: authProvider.user!.password,
    );

    if (mounted && ok) {
      setState(() => _step = 4);
    }
  }

  void _compartir() {
    final rp = context.read<RemesaProvider>();
    final mp = context.read<ManifiestoProvider>();
    final now = DateTime.now();
    final texto =
        '''
📦 Despacho generado en RNDC

Remesa: ${rp.ultimoResultado?.radicadoRndc ?? '—'}
Autorización: ${mp.ultimoResultado?.numeroAutorizacion ?? '—'}
Fecha: ${now.day}/${now.month}/${now.year}
  '''
            .trim();
    Share.share(texto).then((_) {
      rp.clear();
      mp.clear();
      _msgCtrl.clear();
      _placaCtrl.clear();
      _conductorCedulaCtrl.clear();
      _valorViajeCtrl.clear();
      _valorAnticipoCtrl.clear();
      setState(() => _step = 1);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ---- Helpers ----
  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _section(String label) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _row(String label, String value) {
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

class _RadicadoCard extends StatelessWidget {
  final String titulo;
  final String numero;
  final String consecutivo;
  final bool destacado;

  const _RadicadoCard({
    required this.titulo,
    required this.numero,
    required this.consecutivo,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destacado ? Colors.green : null;
    return Card(
      color: color?.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              numero,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87,
              ),
            ),
            Text(
              'Cons: $consecutivo',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
