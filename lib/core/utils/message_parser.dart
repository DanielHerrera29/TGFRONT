import '../../data/models/app_settings.dart';
import '../../data/models/remesa.dart';

class MessageParser {
  Remesa parseToRemesa(String text, AppSettings? settings) {
    final lines = text.split('\n');

    String extract(String key) {
      for (final line in lines) {
        final cleaned = line.replaceAll(RegExp(r'^[🔘\s]+'), '').trim();
        if (cleaned.startsWith(key)) {
          return cleaned.substring(key.length).trimLeft();
        }
      }
      return '';
    }

    String extractMulti(List<String> keys) {
      for (final k in keys) {
        final v = extract(k);
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? orNull(String v) => v.isNotEmpty ? v : null;

    String? normalizeDate(String? value) {
      if (value == null) return null;
      final match = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})')
          .firstMatch(value.trim());
      if (match == null) return value;

      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      var year = int.tryParse(match.group(3) ?? '');
      if (day == null || month == null || year == null) return value;
      if (year < 100) year += 2000;

      return '${day.toString().padLeft(2, '0')}/'
          '${month.toString().padLeft(2, '0')}/'
          '$year';
    }

    String? normalizeTime(String? value) {
      if (value == null) return null;
      final raw = value.trim().toLowerCase();
      final match = RegExp(r'(\d{1,2})(?::(\d{1,2}))?\s*([ap]\.?m\.?)?')
          .firstMatch(raw);
      if (match == null) return value;

      var hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final meridian = match.group(3)?.replaceAll('.', '');
      if (hour == null) return value;

      if (meridian == 'pm' && hour < 12) hour += 12;
      if (meridian == 'am' && hour == 12) hour = 0;

      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }

    final driverName =
        orNull(extractMulti(['CONDUCTOR CAMABAJA:', 'CONDUCTOR:', 'CONDUCTOR']));
    final driverDocument =
        orNull(extractMulti(['CÉDULA:', 'CEDULA:', 'DOCUMENTO:']));
    final placa = orNull(extractMulti(['PLACA CAMABAJA:', 'PLACA:', 'PLACA']));
    final client = orNull(extractMulti(['CLIENTE:', 'CLIENTE']));
    final obra = orNull(extractMulti(['OBRA:', 'OBRA']));
    final programa = orNull(extractMulti(['PROGRAMA:', 'PROGRAMA']));
    final fecha = orNull(extractMulti(['FECHA:', 'FECHA']));
    final horaCargue =
        orNull(extractMulti(['HORA DE CARGUE:', 'HORA:', 'HORA CARGUE:']));
    final cargoType =
        orNull(extractMulti(['TIPO DE CARGA:', 'TIPO CARGA:', 'CARGA:']));
    final weight = orNull(extractMulti(['PESO:', 'PESO']));
    final origin = orNull(extractMulti(['ORIGEN:', 'ORIGEN']));
    final destination = orNull(extractMulti(['DESTINO:', 'DESTINO']));
    final observations =
        orNull(extractMulti(['OBSERVACION:', 'OBSERVACIONES:', 'OBS:']));

    double pesoKg = 0;
    if (weight != null) {
      final normalizedWeight = weight.toLowerCase().replaceAll(',', '.');
      final parsedWeight = double.tryParse(
            normalizedWeight.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      final isTon =
          normalizedWeight.contains('ton') || normalizedWeight.contains('tn');
      pesoKg = isTon ? parsedWeight * 1000 : parsedWeight;
    }

    return Remesa(
      consecutivo: '',
      generadorTipoId: settings?.generadorTipoId ?? 'N',
      generadorNit: settings?.generadorNit ?? '',
      generadorDv: settings?.generadorDv,
      generadorNombre: settings?.generadorNombre,
      generadorSede: settings?.generadorSede ?? '00',
      remitenteTipoId: settings?.generadorTipoId ?? 'N',
      remitenteNit: settings?.generadorNit ?? settings?.empresaNit ?? '',
      remitenteNombre: settings?.generadorNombre ?? settings?.empresaNombre,
      remitenteSede: settings?.generadorSede ?? '00',
      remitenteDireccion: settings?.empresaDireccion,
      remitenteMunicipioDane:
          settings?.empresaMunicipioDane ?? '11001000',
      destinatarioTipoId: 'N',
      destinatarioNit: '',
      destinatarioNombre: client,
      destinatarioSede: '00',
      destinatarioDireccion: destination,
      destinatarioMunicipioDane:
          settings?.empresaMunicipioDane ?? '11001000',
      naturalezaCarga: '1',
      codigoProducto: '001806',
      descripcionProducto: (cargoType ?? 'MAQUINARIA').toUpperCase(),
      tipoEmpaque: '4',
      cantidad: pesoKg,
      unidadMedida: '1',
      pesoKg: pesoKg,
      tipoOperacion: 'G',
      polizaNumero: settings?.polizaNumero,
      polizaVencimiento: settings?.polizaVencimiento,
      polizaAseguradora: settings?.polizaAseguradora,
      polizaAseguradoraNit: settings?.polizaAseguradoraNit,
      clienteNombre: client,
      obra: obra,
      programa: programa,
      observaciones: observations,
      // Campos para pre-cargar Manifiesto
      conductorNombre: driverName,
      conductorDocumento: driverDocument,
      placa: placa,
      fechaCargue: normalizeDate(fecha),
      horaCargue: normalizeTime(horaCargue),
      tipoCarga: cargoType,
      origen: origin,
      destino: destination,
      rawMessage: text,
      estado: 'draft',
    );
  }
}
