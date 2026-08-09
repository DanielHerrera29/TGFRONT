import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/vehiculo.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vehiculos_provider.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VehiculosProvider>();
      vp.load();
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        vp.loadMaestro(
          rndcUsername: auth.user!.email,
          rndcPassword: auth.user!.password,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehiculosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Vehículos'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar vehículo'),
      ),
      body: vp.loading
          ? const Center(child: CircularProgressIndicator())
          : vp.vehiculos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay vehículos registrados',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque + para registrar su primer vehículo',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => vp.load(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: vp.vehiculos.length,
                itemBuilder: (ctx, i) {
                  final v = vp.vehiculos[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          v.numPlaca.substring(
                            0,
                            v.numPlaca.length.clamp(0, 3),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        v.numPlaca,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Carrocería: ${v.codTipoCarroceria}  •  Tenedor: ${v.numIdTenedor}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showFormDialog(context, vehiculo: v),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showFormDialog(BuildContext context, {VehiculoListItem? vehiculo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VehiculoFormSheet(
        vehiculo: vehiculo,
        onSave: (v) async {
          final auth = context.read<AuthProvider>();
          final vp = context.read<VehiculosProvider>();
          final result = await vp.registrar(
            rndcUsername: auth.user!.email,
            rndcPassword: auth.user!.password,
            vehiculo: v,
          );
          if (mounted && context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.exito
                      ? 'Vehículo registrado exitosamente'
                      : (result.error ?? 'Error al registrar vehículo'),
                ),
                backgroundColor: result.exito ? Colors.green : Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

class VehiculoFormSheet extends StatefulWidget {
  final VehiculoListItem? vehiculo;
  final Future<void> Function(Vehiculo) onSave;

  const VehiculoFormSheet({super.key, this.vehiculo, required this.onSave});

  @override
  State<VehiculoFormSheet> createState() => _VehiculoFormSheetState();
}

class _VehiculoFormSheetState extends State<VehiculoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _placaCtrl;
  late final TextEditingController _pesoCtrl;
  late final TextEditingController _tenedorIdCtrl;
  String _configuracion = '';
  String _tipoCarroceria = '';
  String _tipoIdTenedor = '';
  bool _submitting = false;

  bool get _isEdit => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();
    _placaCtrl = TextEditingController(text: widget.vehiculo?.numPlaca ?? '');
    _pesoCtrl = TextEditingController(text: widget.vehiculo != null ? '' : '');
    _tenedorIdCtrl = TextEditingController(
      text: widget.vehiculo?.numIdTenedor ?? '',
    );
    _configuracion = widget.vehiculo?.codConfiguracionUnidadCarga ?? '';
    _tipoCarroceria = widget.vehiculo?.codTipoCarroceria ?? '';
    _tipoIdTenedor = '';
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _pesoCtrl.dispose();
    _tenedorIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehiculosProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit ? 'Editar Vehículo' : 'Registrar Vehículo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (vp.loadingMaestro)
                const LinearProgressIndicator()
              else if (vp.maestroError != null)
                _CatalogoError(
                  message: vp.maestroError!,
                  onRetry: () {
                    final auth = context.read<AuthProvider>();
                    if (auth.user != null) {
                      context.read<VehiculosProvider>().loadMaestro(
                        rndcUsername: auth.user!.email,
                        rndcPassword: auth.user!.password,
                      );
                    }
                  },
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _placaCtrl,
                decoration: _input('Placa (NUMPLACA)', Icons.directions_car),
                textCapitalization: TextCapitalization.characters,
                enabled: !_isEdit,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingrese la placa';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _configuracion.isNotEmpty ? _configuracion : null,
                decoration: _input(
                  'Configuración unidad de carga',
                  Icons.settings_outlined,
                ),
                items: vp.configuraciones
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.codigo,
                        child: Text(
                          '${c.codigo} — ${c.nombre}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _configuracion = v ?? ''),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Seleccione configuración';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pesoCtrl,
                decoration: _input(
                  'Peso vacío kg (PESOVEHICULOVACIO)',
                  Icons.scale,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingrese el peso';
                  if (double.tryParse(v) == null) return 'Peso inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipoCarroceria.isNotEmpty
                    ? _tipoCarroceria
                    : null,
                decoration: _input(
                  'Tipo de carrocería (CODTIPOCARROCERIA)',
                  Icons.local_shipping_outlined,
                ),
                items: vp.tiposCarroceria
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.codigo,
                        child: Text(
                          '${c.codigo} — ${c.nombre}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipoCarroceria = v ?? ''),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Seleccione tipo de carrocería';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipoIdTenedor.isNotEmpty ? _tipoIdTenedor : null,
                decoration: _input(
                  'Tipo ID tenedor (CODTIPOIDTENEDOR)',
                  Icons.badge_outlined,
                ),
                items: vp.tiposIdentificacion
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.codigo,
                        child: Text(
                          '${c.codigo} — ${c.nombre}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipoIdTenedor = v ?? ''),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Seleccione tipo de identificación';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tenedorIdCtrl,
                decoration: _input(
                  'Núm. ID tenedor (NUMIDTENEDOR)',
                  Icons.numbers,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingrese número de identificación';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _submitting
                        ? 'Registrando...'
                        : (_isEdit ? 'Actualizar' : 'Registrar en RNDC'),
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
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final vehiculo = Vehiculo(
      numPlaca: _placaCtrl.text.trim().toUpperCase(),
      codConfiguracionUnidadCarga: _configuracion,
      pesoVehiculoVacio: double.tryParse(_pesoCtrl.text) ?? 0,
      codTipoCarroceria: _tipoCarroceria,
      codTipoIdTenedor: _tipoIdTenedor,
      numIdTenedor: _tenedorIdCtrl.text.trim(),
    );

    await widget.onSave(vehiculo);
    if (mounted) setState(() => _submitting = false);
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

class _CatalogoError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogoError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar catalogos',
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, color: colors.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
