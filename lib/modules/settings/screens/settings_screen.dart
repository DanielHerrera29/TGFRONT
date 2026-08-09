import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;

  // Empresa
  final _empresaNombreCtrl = TextEditingController();
  final _empresaNitCtrl = TextEditingController();
  final _empresaDvCtrl = TextEditingController();
  final _empresaDireccionCtrl = TextEditingController();
  final _empresaTelefonoCtrl = TextEditingController();
  final _empresaCiudadCtrl = TextEditingController();
  final _empresaMunicipioDaneCtrl = TextEditingController();

  // Generador
  final _generadorNitCtrl = TextEditingController();
  final _generadorDvCtrl = TextEditingController();
  final _generadorNombreCtrl = TextEditingController();
  final _generadorSedeCtrl = TextEditingController();

  // Póliza
  final _polizaNumeroCtrl = TextEditingController();
  final _polizaVencimientoCtrl = TextEditingController();
  final _polizaAseguradoraCtrl = TextEditingController();
  final _polizaAseguradoraNitCtrl = TextEditingController();

  bool _simulacion = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load().then((_) => _loadFields());
    });
  }

  void _loadFields() {
    final s = context.read<SettingsProvider>().settings;
    if (s == null) return;
    _empresaNombreCtrl.text = s.empresaNombre ?? '';
    _empresaNitCtrl.text = s.empresaNit;
    _empresaDvCtrl.text = s.empresaDv ?? '';
    _empresaDireccionCtrl.text = s.empresaDireccion ?? '';
    _empresaTelefonoCtrl.text = s.empresaTelefono ?? '';
    _empresaCiudadCtrl.text = s.empresaCiudad ?? '';
    _empresaMunicipioDaneCtrl.text = s.empresaMunicipioDane;
    _generadorNitCtrl.text = s.generadorNit ?? '';
    _generadorDvCtrl.text = s.generadorDv ?? '';
    _generadorNombreCtrl.text = s.generadorNombre ?? '';
    _generadorSedeCtrl.text = s.generadorSede;
    _polizaNumeroCtrl.text = s.polizaNumero ?? '';
    _polizaVencimientoCtrl.text = s.polizaVencimiento != null
        ? '${s.polizaVencimiento!.day.toString().padLeft(2, '0')}/${s.polizaVencimiento!.month.toString().padLeft(2, '0')}/${s.polizaVencimiento!.year}'
        : '';
    _polizaAseguradoraCtrl.text = s.polizaAseguradora ?? '';
    _polizaAseguradoraNitCtrl.text = s.polizaAseguradoraNit ?? '';
    _simulacion = s.esModoSimulacion;
    setState(() {});
  }

  @override
  void dispose() {
    _empresaNombreCtrl.dispose();
    _empresaNitCtrl.dispose();
    _empresaDvCtrl.dispose();
    _empresaDireccionCtrl.dispose();
    _empresaTelefonoCtrl.dispose();
    _empresaCiudadCtrl.dispose();
    _empresaMunicipioDaneCtrl.dispose();
    _generadorNitCtrl.dispose();
    _generadorDvCtrl.dispose();
    _generadorNombreCtrl.dispose();
    _generadorSedeCtrl.dispose();
    _polizaNumeroCtrl.dispose();
    _polizaVencimientoCtrl.dispose();
    _polizaAseguradoraCtrl.dispose();
    _polizaAseguradoraNitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    DateTime? polizaVenc;
    if (_polizaVencimientoCtrl.text.isNotEmpty) {
      final parts = _polizaVencimientoCtrl.text.split('/');
      if (parts.length == 3) {
        polizaVenc = DateTime.tryParse(
            '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
      }
    }

    final sp = context.read<SettingsProvider>();
    await sp.saveAll(
      empresaNombre: _empresaNombreCtrl.text.trim().isEmpty
          ? null
          : _empresaNombreCtrl.text.trim(),
      empresaNit: _empresaNitCtrl.text.trim(),
      empresaDv: _empresaDvCtrl.text.trim().isEmpty
          ? null
          : _empresaDvCtrl.text.trim(),
      empresaDireccion: _empresaDireccionCtrl.text.trim().isEmpty
          ? null
          : _empresaDireccionCtrl.text.trim(),
      empresaTelefono: _empresaTelefonoCtrl.text.trim().isEmpty
          ? null
          : _empresaTelefonoCtrl.text.trim(),
      empresaCiudad: _empresaCiudadCtrl.text.trim().isEmpty
          ? null
          : _empresaCiudadCtrl.text.trim(),
      empresaMunicipioDane: _empresaMunicipioDaneCtrl.text.trim().isEmpty
          ? '11001000'
          : _empresaMunicipioDaneCtrl.text.trim(),
      generadorNit: _generadorNitCtrl.text.trim().isEmpty
          ? null
          : _generadorNitCtrl.text.trim(),
      generadorDv: _generadorDvCtrl.text.trim().isEmpty
          ? null
          : _generadorDvCtrl.text.trim(),
      generadorNombre: _generadorNombreCtrl.text.trim().isEmpty
          ? null
          : _generadorNombreCtrl.text.trim(),
      generadorSede: _generadorSedeCtrl.text.trim().isEmpty
          ? '00'
          : _generadorSedeCtrl.text.trim(),
      polizaNumero: _polizaNumeroCtrl.text.trim().isEmpty
          ? null
          : _polizaNumeroCtrl.text.trim(),
      polizaVencimiento: polizaVenc,
      polizaAseguradora: _polizaAseguradoraCtrl.text.trim().isEmpty
          ? null
          : _polizaAseguradoraCtrl.text.trim(),
      polizaAseguradoraNit: _polizaAseguradoraNitCtrl.text.trim().isEmpty
          ? null
          : _polizaAseguradoraNitCtrl.text.trim(),
      simulacion: _simulacion ? 'S' : 'R',
    );

    if (mounted) {
      setState(() => _saving = false);
      _editing = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configuración guardada'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _editing = false;
                        _loadFields();
                      }),
              child: const Text('Cancelar'),
            ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- EMPRESA ----
              _cardHeader(Icons.business, 'Empresa', Colors.teal[700]!),
              const SizedBox(height: 10),
              _editing
                  ? Column(children: [
                      _field('Nombre empresa', _empresaNombreCtrl),
                      _field('NIT', _empresaNitCtrl,
                          keyboard: TextInputType.number),
                      _field('DV', _empresaDvCtrl,
                          keyboard: TextInputType.number, maxLen: 1),
                      _field('Dirección', _empresaDireccionCtrl),
                      _field('Teléfono', _empresaTelefonoCtrl,
                          keyboard: TextInputType.phone),
                      _field('Ciudad', _empresaCiudadCtrl),
                      _field('Código DANE municipio (8 dígitos)',
                          _empresaMunicipioDaneCtrl,
                          keyboard: TextInputType.number, maxLen: 8),
                    ])
                  : Column(children: [
                      if (s?.empresaNombre != null)
                        _infoRow('Nombre', s!.empresaNombre!),
                      _infoRow('NIT', s?.empresaNit ?? '—'),
                      if (s?.empresaDv != null) _infoRow('DV', s!.empresaDv!),
                      if (s?.empresaDireccion != null)
                        _infoRow('Dirección', s!.empresaDireccion!),
                      if (s?.empresaTelefono != null)
                        _infoRow('Teléfono', s!.empresaTelefono!),
                      if (s?.empresaCiudad != null)
                        _infoRow('Ciudad', s!.empresaCiudad!),
                      _infoRow('DANE', s?.empresaMunicipioDane ?? '—'),
                    ]),

              const SizedBox(height: 20),

              // ---- GENERADOR ----
              _cardHeader(Icons.shield, 'Generador', Colors.amber[700]!),
              const SizedBox(height: 10),
              _editing
                  ? Column(children: [
                      _field('NIT Generador', _generadorNitCtrl,
                          keyboard: TextInputType.number),
                      _field('DV Generador', _generadorDvCtrl,
                          keyboard: TextInputType.number, maxLen: 1),
                      _field('Nombre Generador', _generadorNombreCtrl),
                      _field('Sede Generador', _generadorSedeCtrl,
                          maxLen: 6),
                    ])
                  : Column(children: [
                      _infoRow('NIT', s?.generadorNit ?? '—'),
                      if (s?.generadorDv != null)
                        _infoRow('DV', s!.generadorDv!),
                      if (s?.generadorNombre != null)
                        _infoRow('Nombre', s!.generadorNombre!),
                      _infoRow('Sede', s?.generadorSede ?? '00'),
                    ]),

              const SizedBox(height: 20),

              // ---- PÓLIZA ----
              _cardHeader(Icons.security, 'Póliza de Carga', Colors.blue[700]!),
              const SizedBox(height: 10),
              _editing
                  ? Column(children: [
                      _field('Número de póliza', _polizaNumeroCtrl),
                      _field('Vencimiento (dd/mm/yyyy)',
                          _polizaVencimientoCtrl,
                          keyboard: TextInputType.datetime),
                      _field('Aseguradora', _polizaAseguradoraCtrl),
                      _field('NIT Aseguradora', _polizaAseguradoraNitCtrl,
                          keyboard: TextInputType.number),
                    ])
                  : Column(children: [
                      _infoRow('Número', s?.polizaNumero ?? '—'),
                      _infoRow(
                          'Vencimiento',
                          s?.polizaVencimiento != null
                              ? '${s!.polizaVencimiento!.day.toString().padLeft(2, '0')}/${s.polizaVencimiento!.month.toString().padLeft(2, '0')}/${s.polizaVencimiento!.year}'
                              : '—'),
                      _infoRow('Aseguradora', s?.polizaAseguradora ?? '—'),
                      _infoRow(
                          'NIT Aseguradora',
                          s?.polizaAseguradoraNit ?? '—'),
                    ]),

              const SizedBox(height: 20),

              // ---- MODO ----
              Card(
                child: SwitchListTile(
                  title: const Text('Modo simulación'),
                  subtitle: Text(
                    _simulacion
                        ? 'Usando modo S (pruebas)'
                        : 'Modo R (producción)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _simulacion,
                  onChanged: _editing
                      ? (v) => setState(() => _simulacion = v)
                      : null,
                ),
              ),

              const SizedBox(height: 14),

              // ---- INFO ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text('Web Service RNDC',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las credenciales RNDC se envían desde el login de la app.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text('Acerca de',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _infoRow('Versión', '2.0.0'),
                      _infoRow('Sprint', '2 — Remesa + Manifiesto'),
                      _infoRow('RNDC', 'Sprint 3 vía API .NET'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Helpers ----

  Widget _cardHeader(IconData icon, String label, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, int? maxLen}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLength: maxLen,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterText: '',
        ),
        validator: (v) {
          if (label == 'NIT' && (v == null || v.trim().isEmpty)) {
            return 'El NIT es obligatorio';
          }
          return null;
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
