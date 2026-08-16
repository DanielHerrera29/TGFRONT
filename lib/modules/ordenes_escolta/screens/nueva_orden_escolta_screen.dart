import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../../services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class NuevaOrdenEscoltaScreen extends StatefulWidget {
  const NuevaOrdenEscoltaScreen({super.key});

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
  String _estadoEnvio = '';

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
    super.dispose();
  }

  bool _validar() {
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
    if (_firma.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La firma autorizada es obligatoria.')),
      );
      return false;
    }
    return true;
  }

  Future<void> _confirmar() async {
    if (!_validar()) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined),
        title: const Text('Confirmar orden'),
        content: const Text(
          'La orden se guardara, se enviara inmediatamente a transportegutierrezremesas@gmail.com y no podra modificarse. Revise los datos y la firma antes de confirmar.',
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
      final creada = await ApiService.reservarOrdenEscolta(
        token: token,
        fecha: _fecha,
        empresa: _empresa.text.trim(),
        placaCamabaja: _placaCamabaja.text.trim(),
        placaEscolta: _placaEscolta.text.trim(),
        nombreEscolta: _escolta.text.trim(),
        observaciones: _observaciones.text.trim(),
        viajes: _viajes.map((viaje) => viaje.toMap()).toList(),
      );
      if (mounted) setState(() => _estadoEnvio = 'Generando el PDF firmado...');
      final firma = await _firma.toPngBytes();
      if (firma == null) throw Exception('No fue posible generar la firma.');
      final pdf = await _buildPdf(
        consecutivo: creada.consecutivo,
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
        fecha: _fecha,
        empresa: _empresa.text.trim(),
        placaCamabaja: _placaCamabaja.text.trim(),
        placaEscolta: _placaEscolta.text.trim(),
        escolta: _escolta.text.trim(),
        viajes: _viajes.map((viaje) => viaje.toMap()).toList(),
        firma: firma,
        pdf: pdf,
      );
      _limpiarFormulario();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _OrdenEnviadaScreen(resumen: resumen),
        ),
      );
    } catch (error) {
      if (mounted) {
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
    required int consecutivo,
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
    int consecutivo,
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
                    width: 150,
                    height: 63,
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
                      'No. ${consecutivo.toString().padLeft(5, '0')}',
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden de escolta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Datos de la orden',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _dateField(),
              _field(_empresa, 'Empresa o cliente', required: true),
              _field(
                _placaCamabaja,
                'Placa de camabaja',
                required: true,
                upper: true,
              ),
              _field(_placaEscolta, 'Placa de escolta', upper: true),
              _field(_escolta, 'Nombre del escolta'),
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
                    onPressed: _enviando
                        ? null
                        : () => setState(
                            () => _viajes.add(_TrayectoControllers()),
                          ),
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
              const SizedBox(height: 4),
              Text(
                'Firma autorizada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Signature(
                  controller: _firma,
                  backgroundColor: colors.surface,
                  height: 150,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _firma.clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpiar firma'),
                ),
              ),
              const SizedBox(height: 10),
              Tooltip(
                message:
                    'Genera el PDF firmado, registra la orden y la envía al correo configurado.',
                child: FilledButton.icon(
                  onPressed: _enviando ? null : _confirmar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: _fecha,
      );
      if (date != null) setState(() => _fecha = date);
    },
  );

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
              if (_viajes.length > 1)
                IconButton(
                  tooltip: 'Eliminar viaje',
                  onPressed: _enviando
                      ? null
                      : () => setState(() {
                          viaje.dispose();
                          _viajes.removeAt(index);
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
  final maquina = TextEditingController();
  final origen = TextEditingController();
  final destino = TextEditingController();
  bool get estaCompleto =>
      maquina.text.trim().isNotEmpty &&
      origen.text.trim().isNotEmpty &&
      destino.text.trim().isNotEmpty;
  Map<String, String> toMap() => {
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
          'Orden No. ${resumen.consecutivo.toString().padLeft(5, '0')}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        const Text(
          'Enviada a transportegutierrezremesas@gmail.com',
          textAlign: TextAlign.center,
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
