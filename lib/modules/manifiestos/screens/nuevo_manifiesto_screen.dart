import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/vehiculo.dart';
import '../../../services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vehiculos/providers/vehiculos_provider.dart';
import '../providers/nuevo_manifiesto_provider.dart';

class NuevoManifiestoScreen extends StatefulWidget {
  final String? remesaIdPreseleccionada;

  const NuevoManifiestoScreen({super.key, this.remesaIdPreseleccionada});

  @override
  State<NuevoManifiestoScreen> createState() => _NuevoManifiestoScreenState();
}

class _NuevoManifiestoScreenState extends State<NuevoManifiestoScreen> {
  final _placaCtrl = TextEditingController();
  final _conductorCedulaCtrl = TextEditingController();
  final _valorViajeCtrl = TextEditingController();
  final _valorAnticipoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = context.read<AuthProvider>().user?.email ?? '';
      final np = context.read<NuevoManifiestoProvider>();
      await np.loadRemesasPendientes(token);
      if (widget.remesaIdPreseleccionada != null) {
        final found = np.remesasPendientes
            .where((r) => r.id == widget.remesaIdPreseleccionada)
            .toList();
        if (found.isNotEmpty) {
          np.preselectRemesa(found.first);
          np.goToStep(2);
        }
      }
    });
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _conductorCedulaCtrl.dispose();
    _valorViajeCtrl.dispose();
    _valorAnticipoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NuevoManifiestoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForStep(np.step)),
        actions: [
          if (np.step > 1 && np.step < 3)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                np.reset();
                _clearCtrls();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: np.step == 1
            ? _buildStep1(np)
            : np.step == 2
            ? _buildStep2(np)
            : _buildStep3(np),
      ),
    );
  }

  String _titleForStep(int s) {
    return switch (s) {
      1 => 'Seleccionar Remesa',
      2 => 'Datos del Viaje',
      3 => 'Manifiesto Creado',
      _ => 'Nuevo Manifiesto',
    };
  }

  Widget _buildStep1(NuevoManifiestoProvider np) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleccionar remesa pendiente',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Remesas en estado "Completada" sin manifiesto asociado.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (np.loadingRemesas)
          const Center(child: CircularProgressIndicator())
        else if (np.remesasPendientes.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  'No hay remesas pendientes',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          RadioGroup<RemesaResumen>(
            groupValue: np.remesaSeleccionada,
            onChanged: (v) {
              if (v != null) np.selectRemesa(v);
            },
            child: Column(
              children: np.remesasPendientes
                  .map(
                    (r) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => np.selectRemesa(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Radio<RemesaResumen>(value: r),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.consecutivo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${r.clienteNombre}  •  ${r.pesoKg} kg',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: np.remesaSeleccionada == null
                ? null
                : () => np.goToStep(2),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(NuevoManifiestoProvider np) {
    final r = np.remesaSeleccionada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r != null) ...[
          Text(
            'Remesa: ${r.consecutivo}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cliente: ${r.clienteNombre}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
        ],
        Text('Datos del viaje', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),

        if (np.vehiculoNoRegistrado) ...[
          _InlineVehicleRegistration(np: np),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _placaCtrl,
          decoration: _input('Placa vehículo *', Icons.directions_car),
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => np.updatePlaca(v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conductorCedulaCtrl,
          decoration: _input('Cédula conductor *', Icons.badge_outlined),
          keyboardType: TextInputType.number,
          onChanged: (v) => np.updateConductorCedula(v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _valorViajeCtrl,
          decoration: _input('Valor viaje (\$)', Icons.attach_money),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => np.updateValorViaje(double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _valorAnticipoCtrl,
          decoration: _input('Valor anticipo (\$)', Icons.money_off),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => np.updateValorAnticipo(double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: np.tipoValorPactado,
          decoration: _input('Tipo valor pactado', Icons.description_outlined),
          items: const [
            DropdownMenuItem(value: 'B', child: Text('B — Por viaje')),
            DropdownMenuItem(value: 'K', child: Text('K — Por kilo')),
            DropdownMenuItem(value: 'G', child: Text('G — Por galón')),
          ],
          onChanged: (v) {
            if (v != null) np.updateTipoValorPactado(v);
          },
        ),
        const SizedBox(height: 12),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Requiere aceptación electrónica'),
          subtitle: Text(
            'El manifiesto quedará pendiente de firma en la app RNDC Transportador',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: np.aceptacionElectronica,
          onChanged: (v) => np.updateAceptacionElectronica(v),
        ),

        const SizedBox(height: 12),
        TextField(
          controller: _observacionesCtrl,
          decoration: _input('Observaciones (opcional)', Icons.notes),
          maxLines: 3,
          onChanged: (v) => np.updateObservaciones(v),
        ),
        const SizedBox(height: 20),
        if (np.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              np.error!,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
        if (np.submitting)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => np.goToStep(1),
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

  Widget _buildStep3(NuevoManifiestoProvider np) {
    final r = np.resultado;
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle, size: 72, color: Colors.green[400]),
        const SizedBox(height: 16),
        const Text(
          'Manifiesto creado exitosamente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'MANIFIESTO RNDC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r?.numeroAutorizacion ?? '—',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cons: ${r?.consecutivo ?? '—'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            final texto =
                '''
Manifiesto generado en RNDC
Autorización: ${r?.numeroAutorizacion ?? '—'}
Consecutivo: ${r?.consecutivo ?? '—'}
'''
                    .trim();
            Share.share(texto);
          },
          icon: const Icon(Icons.share_rounded),
          label: const Text('Compartir con conductor'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            np.reset();
            _clearCtrls();
            context.go('/manifiestos');
          },
          icon: const Icon(Icons.list),
          label: const Text('Ir al historial'),
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

  Future<void> _generarManifiesto() async {
    final np = context.read<NuevoManifiestoProvider>();
    final auth = context.read<AuthProvider>();

    final ok = await np.generarManifiesto(
      rndcUsername: auth.user!.email,
      rndcPassword: auth.user!.password,
    );

    if (!mounted) return;
    if (!ok) {
      _snack(np.error ?? 'Error al generar manifiesto');
    }
  }

  void _clearCtrls() {
    _placaCtrl.clear();
    _conductorCedulaCtrl.clear();
    _valorViajeCtrl.clear();
    _valorAnticipoCtrl.clear();
    _observacionesCtrl.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _InlineVehicleRegistration extends StatefulWidget {
  final NuevoManifiestoProvider np;
  const _InlineVehicleRegistration({required this.np});

  @override
  State<_InlineVehicleRegistration> createState() =>
      _InlineVehicleRegistrationState();
}

class _InlineVehicleRegistrationState
    extends State<_InlineVehicleRegistration> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pesoCtrl;
  late final TextEditingController _tenedorIdCtrl;
  String _configuracion = '';
  String _tipoCarroceria = '';
  String _tipoIdTenedor = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _pesoCtrl = TextEditingController();
    _tenedorIdCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final vp = context.read<VehiculosProvider>();
      if (auth.user != null) {
        vp.loadMaestro(
          rndcUsername: auth.user!.email,
          rndcPassword: auth.user!.password,
        );
      }
    });
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _tenedorIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehiculosProvider>();
    final np = widget.np;

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[800],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este vehículo no está registrado en RNDC. Complete los datos para registrarlo antes de continuar.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Placa: ${np.placa.toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              if (vp.loadingMaestro)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _configuracion.isNotEmpty
                      ? _configuracion
                      : null,
                  decoration: _smallInput('Config. unidad de carga'),
                  items: vp.configuraciones
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.codigo,
                          child: Text(
                            '${c.codigo} — ${c.nombre}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _configuracion = v ?? ''),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _pesoCtrl,
                  decoration: _smallInput('Peso vacío (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (double.tryParse(v) == null) return 'Inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _tipoCarroceria.isNotEmpty
                      ? _tipoCarroceria
                      : null,
                  decoration: _smallInput('Tipo de carrocería'),
                  items: vp.tiposCarroceria
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.codigo,
                          child: Text(
                            '${c.codigo} — ${c.nombre}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _tipoCarroceria = v ?? ''),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _tipoIdTenedor.isNotEmpty
                      ? _tipoIdTenedor
                      : null,
                  decoration: _smallInput('Tipo ID tenedor'),
                  items: vp.tiposIdentificacion
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.codigo,
                          child: Text(
                            '${c.codigo} — ${c.nombre}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _tipoIdTenedor = v ?? ''),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tenedorIdCtrl,
                  decoration: _smallInput('Núm. ID tenedor'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _registrarYContinuar,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    _submitting
                        ? 'Registrando...'
                        : 'Registrar vehículo y continuar',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registrarYContinuar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final np = widget.np;
    final auth = context.read<AuthProvider>();
    final vp = context.read<VehiculosProvider>();

    final vehiculo = Vehiculo(
      numPlaca: np.placa.toUpperCase(),
      codConfiguracionUnidadCarga: _configuracion,
      pesoVehiculoVacio: double.tryParse(_pesoCtrl.text) ?? 0,
      codTipoCarroceria: _tipoCarroceria,
      codTipoIdTenedor: _tipoIdTenedor,
      numIdTenedor: _tenedorIdCtrl.text.trim(),
    );

    final result = await vp.registrar(
      rndcUsername: auth.user!.email,
      rndcPassword: auth.user!.password,
      vehiculo: vehiculo,
    );

    if (!mounted) return;

    if (result.exito) {
      np.clearVehiculoNoRegistrado();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehículo registrado. Reenviando manifiesto...'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final ok = await np.generarManifiesto(
        rndcUsername: auth.user!.email,
        rndcPassword: auth.user!.password,
      );

      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(np.error ?? 'Error al generar manifiesto'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Error al registrar vehículo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => _submitting = false);
  }

  InputDecoration _smallInput(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
