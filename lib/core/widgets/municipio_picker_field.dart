import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MunicipioDane {
  final String codigoDane;
  final String departamento;
  final String municipio;

  const MunicipioDane({
    required this.codigoDane,
    required this.departamento,
    required this.municipio,
  });

  factory MunicipioDane.fromMap(Map<String, dynamic> map) => MunicipioDane(
        codigoDane: map['codigo_dane']?.toString() ?? '',
        departamento: map['departamento']?.toString() ?? '',
        municipio: map['municipio']?.toString() ?? '',
      );

  String get label => '$municipio, $departamento';
}

class MunicipioPickerField extends StatefulWidget {
  final MunicipioDane? value;
  final ValueChanged<MunicipioDane> onSelected;
  final String label;

  const MunicipioPickerField({
    super.key,
    required this.value,
    required this.onSelected,
    required this.label,
  });

  @override
  State<MunicipioPickerField> createState() => _MunicipioPickerFieldState();
}

class _MunicipioPickerFieldState extends State<MunicipioPickerField> {
  late final Future<List<MunicipioDane>> _municipios;

  @override
  void initState() {
    super.initState();
    _municipios = _loadMunicipios();
  }

  Future<List<MunicipioDane>> _loadMunicipios() async {
    final raw = await rootBundle.loadString('assets/data/municipios_dane.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((item) => MunicipioDane.fromMap(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MunicipioDane>>(
      future: _municipios,
      builder: (context, snapshot) {
        final ready = snapshot.hasData;
        return TextFormField(
          key: ValueKey(widget.value?.codigoDane),
          initialValue: widget.value == null
              ? ''
              : '${widget.value!.label} (${widget.value!.codigoDane})',
          readOnly: true,
          enabled: ready,
          onTap: ready ? () => _openPicker(snapshot.data!) : null,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
            suffixIcon: ready
                ? const Icon(Icons.search)
                : const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: (value) => widget.value == null
              ? 'Seleccione el municipio destino'
              : null,
        );
      },
    );
  }

  Future<void> _openPicker(List<MunicipioDane> municipios) async {
    final selected = await showModalBottomSheet<MunicipioDane>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normalized = query.trim().toUpperCase();
            final matches = normalized.isEmpty
                ? municipios
                : municipios.where((item) {
                    return item.municipio.contains(normalized) ||
                        item.departamento.contains(normalized) ||
                        item.codigoDane.contains(normalized);
                  }).toList(growable: false);

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        autofocus: true,
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar municipio o departamento',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          return ListTile(
                            title: Text(item.municipio),
                            subtitle: Text(item.departamento),
                            trailing: Text(item.codigoDane),
                            onTap: () => Navigator.pop(sheetContext, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) widget.onSelected(selected);
  }
}
