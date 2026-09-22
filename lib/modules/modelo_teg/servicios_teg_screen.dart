import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';

typedef CargarTeg =
    Future<Map<String, dynamic>> Function({
      String? desde,
      String? hasta,
      String? cursor,
      String? corte,
    });
typedef ExportarTeg =
    Future<Uint8List> Function({String? desde, String? hasta, String? corte});

class ServiciosTegScreen extends StatefulWidget {
  final CargarTeg? cargar;
  final ExportarTeg? exportar;
  final Future<void> Function(Uint8List, String, Rect)? guardar;
  const ServiciosTegScreen({
    super.key,
    this.cargar,
    this.exportar,
    this.guardar,
  });
  @override
  State<ServiciosTegScreen> createState() => _ServiciosTegScreenState();
}

class _ServiciosTegScreenState extends State<ServiciosTegScreen> {
  final _rows = <Map<String, dynamic>>[];
  final _exportKey = GlobalKey();
  DateTimeRange? _rango;
  String? _cursor, _corte, _error;
  bool _loading = false, _exporting = false;
  final _date = DateFormat('yyyy-MM-dd');
  bool get _busy => _loading || _exporting;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _rows.clear();
        _cursor = null;
        _corte = null;
      }
    });
    try {
      final page = await (widget.cargar ?? ApiService.serviciosTeg)(
        desde: _rango == null ? null : _date.format(_rango!.start),
        hasta: _rango == null ? null : _date.format(_rango!.end),
        cursor: more ? _cursor : null,
        corte: more ? _corte : null,
      );
      if (!mounted) return;
      setState(() {
        final ids = _rows.map((r) => r['id']).toSet();
        for (final row in (page['rows'] as List)) {
          final r = Map<String, dynamic>.from(row as Map);
          if (ids.add(r['id'])) _rows.add(r);
        }
        _cursor = page['next'] as String?;
        _corte = page['corte'] as String?;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los servicios. $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fechas() async {
    final now = DateTime.now();
    var desde = _date.format(_rango?.start ?? DateTime(now.year, now.month));
    var hasta = _date.format(_rango?.end ?? now);
    final form = GlobalKey<FormState>();
    String? validate(String? value) {
      try {
        final date = _date.parseStrict(value ?? '');
        if (_date.format(date) != value) return 'Use AAAA-MM-DD';
        return null;
      } catch (_) {
        return 'Use una fecha válida: AAAA-MM-DD';
      }
    }

    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Filtrar por fechas'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Fecha de registro del servicio · Colombia'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: desde,
                decoration: const InputDecoration(
                  labelText: 'Desde',
                  helperText: 'AAAA-MM-DD',
                ),
                onChanged: (v) => desde = v,
                validator: validate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: hasta,
                decoration: const InputDecoration(
                  labelText: 'Hasta',
                  helperText: 'AAAA-MM-DD',
                ),
                onChanged: (v) => hasta = v,
                validator: (v) {
                  final error = validate(v);
                  if (error != null) return error;
                  if (validate(desde) == null &&
                      _date
                          .parseStrict(v!)
                          .isBefore(_date.parseStrict(desde))) {
                    return 'Debe ser igual o posterior a Desde';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  ctx,
                  DateTimeRange(
                    start: _date.parseStrict(desde),
                    end: _date.parseStrict(hasta),
                  ),
                );
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (range == null || !mounted) return;
    setState(() => _rango = range);
    await _load();
  }

  Future<void> _export() async {
    if (_busy || _rows.isEmpty) return;
    final box = _exportKey.currentContext!.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final desde = _rango == null ? null : _date.format(_rango!.start);
      final hasta = _rango == null ? null : _date.format(_rango!.end);
      final bytes = await (widget.exportar ?? ApiService.excelTeg)(
        desde: desde,
        hasta: hasta,
        corte: _corte,
      );
      if (!mounted) return;
      final name =
          'MODELO_BASE_DATOS_TEG_${desde == null ? 'todos' : '${desde}_$hasta'}.xlsx';
      if (widget.guardar != null) {
        await widget.guardar!(bytes, name, origin);
      } else {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo generar o guardar el Excel. $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar reporte general'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Actualizar servicios',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Generar reporte general',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Consulta los servicios y genera el Excel de 44 columnas. Incluye borradores; los datos pendientes quedan vacíos.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _rango == null,
                          onSelected: _busy
                              ? null
                              : (_) {
                                  setState(() => _rango = null);
                                  _load();
                                },
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _fechas,
                          icon: const Icon(Icons.date_range),
                          label: const Text('Filtrar por fechas'),
                        ),
                        FilledButton.icon(
                          key: _exportKey,
                          onPressed: _busy || _rows.isEmpty ? null : _export,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(
                            _exporting ? 'Generando Excel…' : 'Generar Excel',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _rango == null
                          ? 'Sin filtro de fechas'
                          : '${_date.format(_rango!.start)} — ${_date.format(_rango!.end)}',
                    ),
                    Text(
                      'Filtro por fecha de registro · Hora de Colombia',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El Excel incluye todos los servicios del filtro, aunque no hayas cargado todas las páginas. En iPhone puedes elegir “Guardar en Archivos”.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colors.error)),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _load(
                                more: _rows.isNotEmpty && _cursor != null,
                              ),
                        child: const Text('Reintentar consulta'),
                      ),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      ),
                    if (!_loading && _rows.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No hay servicios para este filtro.'),
                      ),
                    if (_rows.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          '${_rows.length} servicios cargados${_cursor == null ? '' : ' · Hay más resultados'}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final r = _rows[index];
                final fecha = DateTime.tryParse(
                  r['fechaRegistro']?.toString() ?? '',
                )?.toUtc().subtract(const Duration(hours: 5));
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Servicio ${r['folio'] ?? '—'} · ${r['cliente'] ?? 'Cliente pendiente'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${r['origen'] ?? 'Origen pendiente'} → ${r['destino'] ?? 'Destino pendiente'}',
                          ),
                          Text('Máquina: ${r['maquina'] ?? 'Pendiente'}'),
                          Text(
                            'Orden: ${r['orden'] ?? 'Sin vínculo'} · ${r['estado'] ?? 'Pendiente'}',
                          ),
                          Text(
                            'Registro: ${fecha == null ? 'Pendiente' : _date.format(fecha)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_cursor != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: const Text('Cargar más servicios'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
