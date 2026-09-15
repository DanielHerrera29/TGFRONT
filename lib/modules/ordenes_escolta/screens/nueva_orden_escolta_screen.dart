import 'package:uuid/uuid.dart';
import '../borrador_orden.dart';
import '../compartir_orden_whatsapp.dart';
import '../../../services/contacto_escolta.dart';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../services/api_service.dart';
import '../../../data/models/cliente.dart';
import '../../../core/config/module_access.dart';
import '../../clientes/providers/clientes_provider.dart';
import '../../clientes/crear_cliente_dialog.dart';
import '../../clientes/vincular_vehiculo_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import 'firma_completa_screen.dart';

class NuevaOrdenEscoltaScreen extends StatefulWidget {
  final String? clientOrderId;
  const NuevaOrdenEscoltaScreen({super.key, this.clientOrderId});

  @override
  State<NuevaOrdenEscoltaScreen> createState() =>
      _NuevaOrdenEscoltaScreenState();
}

class _NuevaOrdenEscoltaScreenState extends State<NuevaOrdenEscoltaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empresa = TextEditingController();
  final _placaCamabaja = TextEditingController();
  final _placaEscolta = TextEditingController();
  final _escolta = TextEditingController();
  final _observaciones = TextEditingController();
  final _firma = SignatureController(
    penStrokeWidth: 2.5,
    penColor: const Color(0xFF0B3D66),
  );
  final List<_TrayectoControllers> _viajes = [_TrayectoControllers()];
  DateTime _fecha = DateTime.now();
  bool _enviando = false;
  BorradorOrden? _draft;
  bool _restoring = true;
  bool get _locked =>
      _enviando || _draft?.pending == true || _draft?.confirmed == true;
  String? _draftError;
  String? _restoredClient;
  Uint8List? _savedSignature;
  ContactoEscolta? _contactoEscolta;
  String? _contactoError;

  Future<void> _loadContacto() async {
    try {
      final contacto = await ContactoEscolta.cargar();
      if (!mounted) return;
      setState(() {
        _contactoEscolta = contacto;
        _contactoError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _contactoError =
              'No se pudieron cargar sus vehículos. Administración debe revisar la configuración de usuarios.',
        );
      }
    }
  }

  Future<void> _restoreDraft() async {
    _restoring = true;
    try {
      final userId = context.read<AuthProvider>().user!.id;
      final token = context.read<AuthProvider>().user!.apiToken!;
      final draft = await BorradorOrden.load(
        userId,
        orderId: _draft?.state['clientOrderId'] ?? widget.clientOrderId,
        nueva: _draft == null && widget.clientOrderId == null,
      );
      if (widget.clientOrderId != null && draft.state['fields'] == null) {
        await draft.recover(token);
      }
      if (!mounted) return;
      _draft = draft;
      _savedSignature = draft.state['signature'] == null
          ? null
          : base64Decode(draft.state['signature']);
      final f = Map<String, dynamic>.from(draft.state['fields'] ?? {});
      _empresa.text = f['empresa'] ?? '';
      _placaCamabaja.text = f['placaCamabaja'] ?? '';
      _placaEscolta.text = f['placaEscolta'] ?? '';
      _escolta.text = f['nombreEscolta'] ?? '';
      _observaciones.text = f['observaciones'] ?? '';
      _restoredClient = f['clienteId'];
      _clienteSeleccionado = null;
      _vehiculoSeleccionado = null;
      _fecha = DateTime.tryParse(f['fecha'] ?? '') ?? DateTime.now();
      if (f['viajes'] is List) {
        for (final v in _viajes) {
          v.dispose();
        }
        _viajes.clear();
        for (final raw in f['viajes']) {
          final v = _TrayectoControllers(clientId: raw['clientItemId']);
          v.maquina.text = raw['maquina'] ?? '';
          v.origen.text = raw['origen'] ?? '';
          v.destino.text = raw['destino'] ?? '';
          _viajes.add(v);
        }
      }
      _restoreClient();
      setState(() => _restoring = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _draftError =
              'No se pudo recuperar el borrador local. Vuelva a abrir la pantalla.';
        });
      }
    }
  }

  void _restoreClient() {
    if (!mounted || _restoredClient == null) return;
    for (final c in _clientesProvider.clientes) {
      if (c.id == _restoredClient) {
        setState(() => _clienteSeleccionado = c);
        break;
      }
    }
  }

  Future<void> _captureDraft() async {
    if (_restoring || _draft == null) return;
    try {
      await _draft!.capture({
        'fecha': _fecha.toIso8601String().substring(0, 10),
        'empresa': _empresa.text.trim(),
        'placaCamabaja': _placaCamabaja.text.trim(),
        'placaEscolta': _placaEscolta.text.trim(),
        'nombreEscolta': _escolta.text.trim(),
        'observaciones': _observaciones.text.trim(),
        'clienteId': _clienteSeleccionado?.id ?? _restoredClient,
        'clienteDocumentoSnapshot': _clienteSeleccionado?.documento,
        'vehiculoPlacaSnapshot': _placaCamabaja.text.trim(),
        'viajes': _viajes.map((v) => v.toMap()).toList(),
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _draftError =
              'No se pudo guardar localmente. No cierre la pantalla.',
        );
      }
      rethrow;
    }
  }

  Future<void> _saveDraft() async {
    if (_draft == null || _enviando) return;
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    setState(() => _enviando = true);
    try {
      await _captureDraft();
      await _draft!.save(token, confirmar: false);
      if (mounted) {
        setState(() => _draftError = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Borrador guardado. El consecutivo por placa se asigna al confirmar. Puede continuarlo desde el historial.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _draftError = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recoverServer() async {
    if (_draft == null || _enviando) return;
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar versión guardada'),
        content: const Text(
          'Se cargarán los datos del servidor. Se conservará una copia local de los cambios actuales para recuperación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recuperar'),
          ),
        ],
      ),
    );
    if (accept != true || !mounted) return;
    setState(() => _enviando = true);
    try {
      await _draft!.recover(token);
      _firma.clear();
      await _restoreDraft();
      if (mounted) setState(() => _draftError = null);
    } catch (e) {
      if (mounted) setState(() => _draftError = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _estadoEnvio = '';
  Cliente? _clienteSeleccionado;
  String? _vehiculoSeleccionado;
  late final ClientesProvider _clientesProvider;

  @override
  void initState() {
    super.initState();
    _clientesProvider = ClientesProvider(
      token: context.read<AuthProvider>().user?.apiToken ?? '',
    )..load();
    _clientesProvider.addListener(_restoreClient);
    _restoreDraft();
    _loadContacto();
  }

  @override
  void dispose() {
    _empresa.dispose();
    _placaCamabaja.dispose();
    _placaEscolta.dispose();
    _escolta.dispose();
    _observaciones.dispose();
    _firma.dispose();
    for (final viaje in _viajes) {
      viaje.dispose();
    }
    _clientesProvider.removeListener(_restoreClient);
    _clientesProvider.dispose();
    super.dispose();
  }

  bool _validar() {
    if (_draft?.confirmed != true &&
        context.read<AuthProvider>().user?.isAdmin != true &&
        (_contactoEscolta == null ||
            !_contactoEscolta!.placas.contains(_placaEscolta.text))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cargue y seleccione uno de sus vehículos escolta antes de confirmar.',
          ),
        ),
      );
      return false;
    }
    if (!_formKey.currentState!.validate()) return false;
    for (var index = 0; index < _viajes.length; index++) {
      if (!_viajes[index].estaCompleto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete maquina, origen y destino del viaje ${index + 1}.',
            ),
          ),
        );
        return false;
      }
    }
    if (_firma.isEmpty && _savedSignature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La firma autorizada es obligatoria.')),
      );
      return false;
    }
    return true;
  }

  Future<void> _confirmar() async {
    if (_draft == null) return;
    if (!_validar()) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined),
        title: const Text('Confirmar orden'),
        content: const Text(
          'La orden se guardará y se enviará por correo. Después podrá compartir el PDF y los detalles por WhatsApp; en el teléfono se abrirá el selector para compartir. Revise los datos y la firma antes de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver a revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y enviar'),
          ),
        ],
      ),
    );
    if (confirma == true) await _generarYEnviar();
  }

  Future<void> _abrirFirma() async {
    if (_draft?.confirmed == true && _savedSignature != null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FirmaCompletaScreen(controller: _firma),
      ),
    );
    if (mounted) {
      _savedSignature = await _firma.toPngBytes();
      if (_draft != null) {
        if (_savedSignature == null) {
          _draft!.state.remove('signature');
        } else {
          _draft!.state['signature'] = base64Encode(_savedSignature!);
        }
        try {
          await _draft!.persist();
        } catch (_) {
          if (mounted) {
            setState(
              () => _draftError =
                  'No se pudo conservar la firma. Vuelva a intentarlo antes de enviar.',
            );
          }
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _generarYEnviar() async {
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La sesion vencio. Inicie sesion nuevamente.'),
        ),
      );
      return;
    }
    setState(() {
      _enviando = true;
      _estadoEnvio = 'Registrando la orden...';
    });
    try {
      await _captureDraft();
      final result = await _draft!.save(token, confirmar: true);
      if (result['estado'] != 'CONFIRMADA') {
        throw StateError('Borrador recuperado. Revise y confirme nuevamente.');
      }
      final creada = OrdenEscoltaCreada(
        id: result['id'],
        consecutivo: result['consecutivo'],
        codigoOrden: result['codigoOrden'],
      );
      if (mounted) setState(() => _estadoEnvio = 'Generando el PDF firmado...');
      final firma = _savedSignature ?? await _firma.toPngBytes();
      if (firma == null) throw Exception('No fue posible generar la firma.');
      final pdf = await _buildPdf(
        consecutivo: creada.numeroVisible,
        firma: firma,
      );
      if (mounted) setState(() => _estadoEnvio = 'Guardando el PDF...');
      await ApiService.enviarOrdenEscolta(
        token: token,
        ordenId: creada.id,
        pdf: pdf,
      );
      if (!mounted) return;
      final resumen = _OrdenResumen(
        consecutivo: creada.consecutivo,
        numeroVisible: creada.numeroVisible,
        fecha: _fecha,
        empresa: _empresa.text.trim(),
        placaCamabaja: _placaCamabaja.text.trim(),
        placaEscolta: _placaEscolta.text.trim(),
        escolta: _escolta.text.trim(),
        viajes: _viajes.map((viaje) => viaje.toMap()).toList(),
        firma: firma,
        pdf: pdf,
      );
      await _draft!.finish();
      if (!mounted) return;
      _limpiarFormulario();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _OrdenEnviadaScreen(resumen: resumen),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _draftError = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la orden: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
          _estadoEnvio = '';
        });
      }
    }
  }

  void _limpiarFormulario() {
    _savedSignature = null;
    _restoredClient = null;
    _clienteSeleccionado = null;
    _vehiculoSeleccionado = null;
    _empresa.clear();
    _placaCamabaja.clear();
    _placaEscolta.clear();
    _escolta.clear();
    _observaciones.clear();
    _firma.clear();
    for (final viaje in _viajes) {
      viaje.dispose();
    }
    setState(() {
      _viajes
        ..clear()
        ..add(_TrayectoControllers());
      _fecha = DateTime.now();
    });
  }

  Future<Uint8List> _buildPdf({
    required String consecutivo,
    required Uint8List firma,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/arial.ttf'),
    );
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/arialbd.ttf'));
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final signature = pw.MemoryImage(firma);
    final logoImage = pw.MemoryImage(
      (await rootBundle.load(
        'assets/images/teg_logo.png',
      )).buffer.asUint8List(),
    );
    final rows = _viajes.asMap().entries.map((entry) {
      final viaje = entry.value;
      return [
        '${entry.key + 1}',
        viaje.maquina.text.trim(),
        viaje.origen.text.trim(),
        viaje.destino.text.trim(),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 26, 30, 34),
        header: (_) => _pdfHeader(consecutivo, logoImage),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          _pdfData(
            'Fecha',
            DateFormat('dd/MM/yyyy').format(_fecha),
            'Empresa',
            _empresa.text.trim(),
          ),
          _pdfData(
            'Placa camabaja',
            _placaCamabaja.text.trim(),
            'Placa escolta',
            _placaEscolta.text.trim(),
          ),
          if (_escolta.text.trim().isNotEmpty)
            _pdfData('Escolta', _escolta.text.trim(), '', ''),
          pw.SizedBox(height: 14),
          pw.Text(
            'VIAJES AUTORIZADOS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Maquina', 'Origen', 'Destino'],
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.blueGrey300),
            columnWidths: {0: const pw.FixedColumnWidth(24)},
          ),
          if (_observaciones.text.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Observaciones',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              _observaciones.text.trim(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 28),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Column(
              children: [
                pw.Image(
                  signature,
                  width: 190,
                  height: 58,
                  fit: pw.BoxFit.contain,
                ),
                pw.Container(width: 230, height: 0.7, color: PdfColors.grey700),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Firma autorizada',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _pdfHeader(
    String consecutivo,
    pw.ImageProvider logoImage,
  ) => pw.Column(
    children: [
      pw.SizedBox(
        height: 108,
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              right: 287,
              top: 0,
              child: pw.Column(
                children: [
                  pw.Text(
                    'TRANSPORTES ESPECIALES GUTIERREZ S.A.S.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Image(
                    logoImage,
                    width: 175,
                    height: 52,
                    fit: pw.BoxFit.contain,
                  ),
                  pw.Text(
                    'Transporte de carga extradimensionada y especializada',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ],
              ),
            ),
            pw.Positioned(
              left: 232,
              right: 88,
              top: 38,
              child: pw.Column(
                children: [
                  pw.Text(
                    'Nit 900.344.766-4',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                  pw.Text(
                    'Calle 8B N. 82B - 61 Br. Valladolid - Bogota',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                  pw.Text(
                    'Tel: 412 2036 - 609 8617  |  Cel: 311 809 2301 - 312 305 7705',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                  pw.Text(
                    'e-mail: transgut@hotmail.com  |  www.transgutierrez.com',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ],
              ),
            ),
            pw.Positioned(
              right: 0,
              top: 0,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Orden',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'No. $consecutivo',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      pw.Container(height: 2.5, color: PdfColors.blue800),
    ],
  );

  pw.Widget _pdfData(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            '$leftLabel:',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(leftValue, style: const pw.TextStyle(fontSize: 8)),
        ),
        if (rightLabel.isNotEmpty && rightValue.isNotEmpty) ...[
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              '$rightLabel:',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(rightValue, style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clientOrderId == null
              ? 'Nueva orden de escolta'
              : 'Continuar orden de escolta',
        ),
      ),
      body: _restoring
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                onChanged: () {
                  _captureDraft().catchError((_) {});
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      'Datos de la orden',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _dateField(),
                    _clienteField(),
                    if (_clienteSeleccionado != null) _vehiculoField(),
                    _field(
                      _placaCamabaja,
                      'Placa de camabaja',
                      required: true,
                      upper: true,
                    ),
                    if (context.read<AuthProvider>().user?.isAdmin == true) ...[
                      _field(_placaEscolta, 'Placa de escolta', upper: true),
                      _field(_escolta, 'Nombre del escolta'),
                    ] else ...[
                      if (_locked)
                        Text(
                          'Escolta: ${_escolta.text} · ${_placaEscolta.text}',
                        )
                      else if (_contactoEscolta != null) ...[
                        Text('Escolta: ${_contactoEscolta!.nombre}'),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            '${_contactoEscolta!.placas.join(',')}:${_placaEscolta.text}',
                          ),
                          initialValue:
                              _contactoEscolta!.placas.contains(
                                _placaEscolta.text,
                              )
                              ? _placaEscolta.text
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Su vehículo escolta',
                          ),
                          items: _contactoEscolta!.placas
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          validator: (p) => p == null
                              ? 'Seleccione un vehículo asignado a su usuario.'
                              : null,
                          onChanged: (p) {
                            setState(() {
                              _placaEscolta.text = p ?? '';
                              _escolta.text = _contactoEscolta!.nombre;
                            });
                            _captureDraft();
                          },
                        ),
                        if (_contactoEscolta!.placas.isEmpty)
                          const Text(
                            'Su usuario aún no tiene vehículos asignados. Administración puede agregarlos en Usuarios.',
                          ),
                      ] else if (_contactoError == null)
                        const LinearProgressIndicator(),
                      if (_contactoError != null) ...[
                        Text(_contactoError!),
                        TextButton(
                          onPressed: _loadContacto,
                          child: const Text('Reintentar vehículos'),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Viajes autorizados',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _locked
                              ? null
                              : () => setState(() {
                                  _viajes.add(_TrayectoControllers());
                                  _captureDraft().catchError((_) {});
                                }),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar viaje'),
                        ),
                      ],
                    ),
                    Text(
                      'Agregue un viaje a la vez. La orden puede continuar en nuevas paginas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ..._viajes.asMap().entries.map(
                      (entry) => _viajeEditor(entry.key, entry.value),
                    ),
                    _field(_observaciones, 'Observaciones', maxLines: 3),
                    if (_draftError != null)
                      Text(
                        _draftError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_draft?.pending == true)
                      const Text(
                        'Hay un guardado pendiente. Reintente antes de editar.',
                      ),
                    if (_draft?.confirmed == true)
                      const Text(
                        'Orden confirmada. Se conservan sus datos y firma; puede recuperar el PDF.',
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          _enviando || _draft == null || _draft!.confirmed
                          ? null
                          : _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _draft?.pending == true
                            ? 'Recuperar guardado pendiente'
                            : 'Guardar borrador',
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _enviando || _draft == null
                          ? null
                          : _recoverServer,
                      child: const Text('Recuperar versión del servidor'),
                    ),
                    FirmaCard(
                      firmada: _firma.isNotEmpty || _savedSignature != null,
                      enabled:
                          !_enviando &&
                          !(_draft?.confirmed == true &&
                              _savedSignature != null),
                      onPressed: _abrirFirma,
                    ),
                    const SizedBox(height: 10),
                    Tooltip(
                      message:
                          'Genera el PDF firmado, registra la orden y la envía al correo configurado.',
                      child: FilledButton.icon(
                        onPressed: _enviando || _draft == null
                            ? null
                            : _confirmar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _enviando ? _estadoEnvio : 'Generar y enviar orden',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _dateField() => ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Fecha de la orden'),
    subtitle: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
    trailing: const Icon(Icons.calendar_today_outlined),
    onTap: _locked
        ? null
        : () async {
            final date = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: _fecha,
            );
            if (date != null && mounted) {
              setState(() => _fecha = date);
              await _captureDraft();
            }
          },
  );

  Widget _clienteField() => AnimatedBuilder(
    animation: _clientesProvider,
    builder: (context, _) {
      if (_clientesProvider.loading) return const LinearProgressIndicator();
      if (_clientesProvider.error != null) {
        return Column(
          children: [
            Text(
              _clientesProvider.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _clientesProvider.load,
              child: const Text('Reintentar carga de clientes'),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_clientesProvider.clientes.isEmpty)
            const Text(
              'No hay clientes registrados. Administración debe crear uno para completar la orden.',
            ),
          DropdownButtonFormField<Cliente>(
            key: ValueKey(_clienteSeleccionado?.id),
            initialValue: _clienteSeleccionado,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Empresa o cliente',
              border: OutlineInputBorder(),
            ),
            items: _clientesProvider.clientes
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.nombre} · ${c.documento}'),
                  ),
                )
                .toList(),
            validator: (v) =>
                v == null ? 'Seleccione una empresa o cliente' : null,
            onChanged: _locked
                ? null
                : (c) {
                    setState(() {
                      _clienteSeleccionado = c;
                      _restoredClient = c?.id;
                      _empresa.text = c?.nombre ?? '';
                      _vehiculoSeleccionado = null;
                      _placaCamabaja.clear();
                    });
                    _captureDraft().catchError((_) {});
                  },
          ),
          Wrap(
            children: [
              if (!ModuleAccess.soloOrdenes(context.read<AuthProvider>().user))
                TextButton.icon(
                  onPressed: _locked ? null : _crearCliente,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Crear cliente'),
                ),
              TextButton.icon(
                onPressed: _locked ? null : _clientesProvider.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar clientes'),
              ),
              if (_clienteSeleccionado != null &&
                  !ModuleAccess.soloOrdenes(context.read<AuthProvider>().user))
                TextButton.icon(
                  onPressed: _locked ? null : _vincularVehiculo,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Vincular vehículo al cliente'),
                ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _crearCliente() async {
    final token = context.read<AuthProvider>().user?.apiToken;
    if (token == null) return;
    final cliente = await showDialog<Cliente>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CrearClienteDialog(token: token),
    );
    if (cliente == null || !mounted) return;
    _restoredClient = cliente.id;
    _empresa.text = cliente.nombre;
    _vehiculoSeleccionado = null;
    await _clientesProvider.load();
    if (!mounted) return;
    _restoreClient();
    await _captureDraft();
  }

  Future<void> _vincularVehiculo() async {
    final cliente = _clienteSeleccionado;
    final token = context.read<AuthProvider>().user?.apiToken;
    if (cliente == null || token == null) return;
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (_) => VincularVehiculoDialog(
        token: token,
        clienteId: cliente.id,
        nombre: cliente.nombre,
      ),
    );
    if (actualizado != true || !mounted) return;
    _restoredClient = cliente.id;
    await _clientesProvider.load();
    if (mounted) _restoreClient();
  }

  Widget _vehiculoField() {
    final vehiculos = _clienteSeleccionado!.vehiculos
        .where((v) => v.estado != 'inactive')
        .toList();
    if (vehiculos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Este cliente todavía no tiene vehículos de carga vinculados. La placa escrita en la orden se guarda en esa orden; no crea una asociación permanente con el cliente.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_vehiculoSeleccionado),
        initialValue: _vehiculoSeleccionado,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Vehículo asociado',
          border: OutlineInputBorder(),
        ),
        items: vehiculos
            .map(
              (v) =>
                  DropdownMenuItem(value: v.numPlaca, child: Text(v.numPlaca)),
            )
            .toList(),
        onChanged: _locked
            ? null
            : (v) {
                setState(() {
                  _vehiculoSeleccionado = v;
                  _placaCamabaja.text = v ?? '';
                });
                _captureDraft().catchError((_) {});
              },
        hint: Text(
          vehiculos.isEmpty
              ? 'Este cliente no tiene vehículos asociados'
              : 'Seleccione un vehículo',
        ),
      ),
    );
  }

  Widget _viajeEditor(int index, _TrayectoControllers viaje) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Viaje ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_viajes.length > 1 &&
                  (_draft?.state['version'] ?? 0) == 0 &&
                  _draft?.pending != true)
                IconButton(
                  tooltip: 'Eliminar viaje',
                  onPressed: _locked
                      ? null
                      : () => setState(() {
                          viaje.dispose();
                          _viajes.removeAt(index);
                          _captureDraft().catchError((_) {});
                        }),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
          _field(viaje.maquina, 'Maquina', required: true),
          _field(viaje.origen, 'Origen', required: true),
          _field(viaje.destino, 'Destino', required: true),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool upper = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      enabled: !_locked,
      controller: controller,
      textCapitalization: upper
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label es obligatorio'
                : null
          : null,
    ),
  );
}

class _TrayectoControllers {
  final String clientId;
  _TrayectoControllers({String? clientId})
    : clientId = clientId ?? const Uuid().v4();
  final maquina = TextEditingController();
  final origen = TextEditingController();
  final destino = TextEditingController();
  bool get estaCompleto =>
      maquina.text.trim().isNotEmpty &&
      origen.text.trim().isNotEmpty &&
      destino.text.trim().isNotEmpty;
  Map<String, String> toMap() => {
    'clientItemId': clientId,
    'maquina': maquina.text.trim(),
    'origen': origen.text.trim(),
    'destino': destino.text.trim(),
  };
  void dispose() {
    maquina.dispose();
    origen.dispose();
    destino.dispose();
  }
}

class _OrdenResumen {
  final String numeroVisible;
  final int consecutivo;
  final DateTime fecha;
  final String empresa;
  final String placaCamabaja;
  final String placaEscolta;
  final String escolta;
  final List<Map<String, String>> viajes;
  final Uint8List firma;
  final Uint8List pdf;
  const _OrdenResumen({
    required this.numeroVisible,
    required this.consecutivo,
    required this.fecha,
    required this.empresa,
    required this.placaCamabaja,
    required this.placaEscolta,
    required this.escolta,
    required this.viajes,
    required this.firma,
    required this.pdf,
  });
}

class _OrdenEnviadaScreen extends StatelessWidget {
  final _OrdenResumen resumen;
  const _OrdenEnviadaScreen({required this.resumen});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Orden enviada')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56),
        const SizedBox(height: 12),
        Text(
          'Orden No. ${resumen.numeroVisible}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        const Text(
          'Enviada a transportegutierrezremesas@gmail.com',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        CompartirOrdenWhatsapp(
          pdf: resumen.pdf,
          nombreArchivo: 'orden_escolta_${resumen.numeroVisible}.pdf',
          automatico: true,
          mensaje:
              'Orden de escolta No. ${resumen.numeroVisible}\nFecha: ${DateFormat('dd/MM/yyyy').format(resumen.fecha)}\nCliente: ${resumen.empresa}\nCamabaja: ${resumen.placaCamabaja}\nEscolta: ${resumen.escolta}\nPlaca escolta: ${resumen.placaEscolta}\n${resumen.viajes.asMap().entries.map((e) => 'Viaje ${e.key + 1}: ${e.value['maquina']} · ${e.value['origen']} → ${e.value['destino']}').join('\n')}',
        ),
        const SizedBox(height: 22),
        Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
        Text('Fecha: ${DateFormat('dd/MM/yyyy').format(resumen.fecha)}'),
        Text('Empresa: ${resumen.empresa}'),
        Text('Camabaja: ${resumen.placaCamabaja}'),
        if (resumen.placaEscolta.isNotEmpty)
          Text('Escolta: ${resumen.placaEscolta}'),
        if (resumen.escolta.isNotEmpty)
          Text('Nombre escolta: ${resumen.escolta}'),
        const SizedBox(height: 14),
        ...resumen.viajes.asMap().entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${entry.key + 1}')),
            title: Text(entry.value['maquina'] ?? ''),
            subtitle: Text(
              '${entry.value['origen']}  ->  ${entry.value['destino']}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Image.memory(
            resumen.firma,
            width: 190,
            height: 58,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 4),
        const Center(child: Text('Firma autorizada')),
      ],
    ),
  );
}
