import 'package:flutter/material.dart';
import '../../../data/models/remesa.dart';

class RemesaPreview extends StatelessWidget {
  final Remesa data;

  const RemesaPreview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final fields = <MapEntry<String, String?>>[
      MapEntry('Conductor', data.conductorNombre),
      MapEntry('Cédula', data.conductorDocumento),
      MapEntry('Placa', data.placa),
      MapEntry('Cliente', data.clienteNombre),
      MapEntry('Obra', data.obra),
      MapEntry('Programa', data.programa),
      MapEntry('Fecha', data.fechaCargue),
      MapEntry('Hora cargue', data.horaCargue),
      MapEntry('Tipo carga', data.tipoCarga),
      MapEntry('Peso (kg)', data.pesoKg > 0 ? data.pesoKg.toString() : null),
      MapEntry('Origen', data.origen),
      MapEntry('Destino', data.destino),
      MapEntry('Observaciones', data.observaciones),
    ];

    final parsed =
        fields.where((e) => e.value != null && e.value!.isNotEmpty).toList();
    final missing =
        fields.where((e) => e.value == null || e.value!.isEmpty).toList();
    final coverage = fields.isNotEmpty ? parsed.length * 100 ~/ fields.length : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Datos extraídos',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Chip(
                label: Text('$coverage%',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            coverage > 60 ? Colors.green : Colors.orange)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...parsed.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ),
                    Expanded(
                      child: Text(e.value!,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )),
          if (missing.isNotEmpty) ...[
            const Divider(height: 16),
            Text('No encontrados (${missing.length})',
                style: TextStyle(fontSize: 11, color: Colors.orange[700])),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: missing
                  .where((e) => e.key != 'Observaciones')
                  .map((e) => Chip(
                        label: Text(e.key,
                            style: const TextStyle(fontSize: 10)),
                        backgroundColor:
                            Colors.orange.withValues(alpha: 0.08),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
