class Manifiesto {
  final String id;
  final String consecutivo;
  final String remesaId;

  // Vehículo
  final String placaVehiculo;
  final String? placaRemolque;

  // Conductor principal
  final String conductorTipoId;
  final String conductorCedula;
  final String? conductorNombre;

  // Segundo conductor
  final String? conductor2Cedula;
  final String? conductor2Nombre;

  // Propietario
  final String? propietarioTipoId;
  final String? propietarioCedula;
  final String? propietarioNombre;

  // Programación
  final DateTime? fechaDespacho;
  final DateTime? fechaLimiteEntrega;

  // Económicas
  final String tipoValorPactado;
  final double valorViaje;
  final double valorAnticipo;

  // Pago saldo
  final String? municipioPagoDane;
  final DateTime? fechaLimitePago;

  // Responsables
  final String respCargue;
  final String respDescargue;

  // Horas espera
  final int horasEsperaCargue;
  final int horasEsperaDescargue;

  final String? observaciones;

  // Aceptación electrónica
  final String? aceptacionElectronica;

  // Respuesta RNDC
  final String? radicadoRndc;
  final String? numeroAutorizacion;
  final String? xmlEnviado;
  final String? xmlRespuesta;
  final String? pdfUrl;

  // Estado
  final String estado;
  final String? errorDetalle;

  // Auditoría
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Manifiesto({
    String? id,
    required this.consecutivo,
    required this.remesaId,
    required this.placaVehiculo,
    this.placaRemolque,
    this.conductorTipoId = 'C',
    required this.conductorCedula,
    this.conductorNombre,
    this.conductor2Cedula,
    this.conductor2Nombre,
    this.propietarioTipoId,
    this.propietarioCedula,
    this.propietarioNombre,
    this.fechaDespacho,
    this.fechaLimiteEntrega,
    this.tipoValorPactado = 'B',
    required this.valorViaje,
    required this.valorAnticipo,
    this.municipioPagoDane,
    this.fechaLimitePago,
    this.respCargue = 'D',
    this.respDescargue = 'D',
    this.horasEsperaCargue = 0,
    this.horasEsperaDescargue = 0,
    this.observaciones,
    this.aceptacionElectronica,
    this.radicadoRndc,
    this.numeroAutorizacion,
    this.xmlEnviado,
    this.xmlRespuesta,
    this.pdfUrl,
    this.estado = 'draft',
    this.errorDetalle,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get valorSaldo => valorViaje - valorAnticipo;

  factory Manifiesto.fromMap(Map<String, dynamic> map) => Manifiesto(
        id: map['id'],
        consecutivo: map['consecutivo']?.toString() ?? '',
        remesaId: map['remesa_id']?.toString() ?? '',
        placaVehiculo: map['placa_vehiculo']?.toString() ?? '',
        placaRemolque: map['placa_remolque']?.toString(),
        conductorTipoId: map['conductor_tipo_id'] ?? 'C',
        conductorCedula: map['conductor_cedula']?.toString() ?? '',
        conductorNombre: map['conductor_nombre']?.toString(),
        conductor2Cedula: map['conductor2_cedula']?.toString(),
        conductor2Nombre: map['conductor2_nombre']?.toString(),
        propietarioTipoId: map['propietario_tipo_id']?.toString(),
        propietarioCedula: map['propietario_cedula']?.toString(),
        propietarioNombre: map['propietario_nombre']?.toString(),
        fechaDespacho: map['fecha_despacho'] != null
            ? DateTime.tryParse(map['fecha_despacho'].toString())
            : null,
        fechaLimiteEntrega: map['fecha_limite_entrega'] != null
            ? DateTime.tryParse(map['fecha_limite_entrega'].toString())
            : null,
        tipoValorPactado: map['tipo_valor_pactado'] ?? 'B',
        valorViaje: (map['valor_viaje'] ?? 0).toDouble(),
        valorAnticipo: (map['valor_anticipo'] ?? 0).toDouble(),
        municipioPagoDane: map['municipio_pago_dane']?.toString(),
        fechaLimitePago: map['fecha_limite_pago'] != null
            ? DateTime.tryParse(map['fecha_limite_pago'].toString())
            : null,
        respCargue: map['resp_cargue'] ?? 'D',
        respDescargue: map['resp_descargue'] ?? 'D',
        horasEsperaCargue: map['horas_espera_cargue'] ?? 0,
        horasEsperaDescargue: map['horas_espera_descargue'] ?? 0,
        observaciones: map['observaciones']?.toString(),
        aceptacionElectronica: map['aceptacion_electronica']?.toString(),
        radicadoRndc: map['radicado_rndc']?.toString(),
        numeroAutorizacion: map['numero_autorizacion']?.toString(),
        xmlEnviado: map['xml_enviado']?.toString(),
        xmlRespuesta: map['xml_respuesta']?.toString(),
        pdfUrl: map['pdf_url']?.toString(),
        estado: map['estado'] ?? 'draft',
        errorDetalle: map['error_detalle']?.toString(),
        createdBy: map['created_by']?.toString(),
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
      );

  Manifiesto copyWith({
    String? id,
    String? consecutivo,
    String? remesaId,
    String? placaVehiculo,
    String? placaRemolque,
    String? conductorTipoId,
    String? conductorCedula,
    String? conductorNombre,
    String? conductor2Cedula,
    String? conductor2Nombre,
    String? propietarioTipoId,
    String? propietarioCedula,
    String? propietarioNombre,
    DateTime? fechaDespacho,
    DateTime? fechaLimiteEntrega,
    String? tipoValorPactado,
    double? valorViaje,
    double? valorAnticipo,
    String? municipioPagoDane,
    DateTime? fechaLimitePago,
    String? respCargue,
    String? respDescargue,
    int? horasEsperaCargue,
    int? horasEsperaDescargue,
    String? observaciones,
    String? aceptacionElectronica,
    String? radicadoRndc,
    String? numeroAutorizacion,
    String? xmlEnviado,
    String? xmlRespuesta,
    String? pdfUrl,
    String? estado,
    String? errorDetalle,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Manifiesto(
      id: id ?? this.id,
      consecutivo: consecutivo ?? this.consecutivo,
      remesaId: remesaId ?? this.remesaId,
      placaVehiculo: placaVehiculo ?? this.placaVehiculo,
      placaRemolque: placaRemolque ?? this.placaRemolque,
      conductorTipoId: conductorTipoId ?? this.conductorTipoId,
      conductorCedula: conductorCedula ?? this.conductorCedula,
      conductorNombre: conductorNombre ?? this.conductorNombre,
      conductor2Cedula: conductor2Cedula ?? this.conductor2Cedula,
      conductor2Nombre: conductor2Nombre ?? this.conductor2Nombre,
      propietarioTipoId: propietarioTipoId ?? this.propietarioTipoId,
      propietarioCedula: propietarioCedula ?? this.propietarioCedula,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      fechaDespacho: fechaDespacho ?? this.fechaDespacho,
      fechaLimiteEntrega: fechaLimiteEntrega ?? this.fechaLimiteEntrega,
      tipoValorPactado: tipoValorPactado ?? this.tipoValorPactado,
      valorViaje: valorViaje ?? this.valorViaje,
      valorAnticipo: valorAnticipo ?? this.valorAnticipo,
      municipioPagoDane: municipioPagoDane ?? this.municipioPagoDane,
      fechaLimitePago: fechaLimitePago ?? this.fechaLimitePago,
      respCargue: respCargue ?? this.respCargue,
      respDescargue: respDescargue ?? this.respDescargue,
      horasEsperaCargue: horasEsperaCargue ?? this.horasEsperaCargue,
      horasEsperaDescargue: horasEsperaDescargue ?? this.horasEsperaDescargue,
      observaciones: observaciones ?? this.observaciones,
      aceptacionElectronica:
          aceptacionElectronica ?? this.aceptacionElectronica,
      radicadoRndc: radicadoRndc ?? this.radicadoRndc,
      numeroAutorizacion: numeroAutorizacion ?? this.numeroAutorizacion,
      xmlEnviado: xmlEnviado ?? this.xmlEnviado,
      xmlRespuesta: xmlRespuesta ?? this.xmlRespuesta,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      estado: estado ?? this.estado,
      errorDetalle: errorDetalle ?? this.errorDetalle,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'consecutivo': consecutivo,
        'remesa_id': remesaId,
        'placa_vehiculo': placaVehiculo,
        'placa_remolque': placaRemolque,
        'conductor_tipo_id': conductorTipoId,
        'conductor_cedula': conductorCedula,
        'conductor_nombre': conductorNombre,
        'conductor2_cedula': conductor2Cedula,
        'conductor2_nombre': conductor2Nombre,
        'propietario_tipo_id': propietarioTipoId,
        'propietario_cedula': propietarioCedula,
        'propietario_nombre': propietarioNombre,
        'fecha_despacho': fechaDespacho?.toIso8601String(),
        'fecha_limite_entrega': fechaLimiteEntrega?.toIso8601String(),
        'tipo_valor_pactado': tipoValorPactado,
        'valor_viaje': valorViaje,
        'valor_anticipo': valorAnticipo,
        'municipio_pago_dane': municipioPagoDane,
        'fecha_limite_pago': fechaLimitePago?.toIso8601String(),
        'resp_cargue': respCargue,
        'resp_descargue': respDescargue,
        'horas_espera_cargue': horasEsperaCargue,
        'horas_espera_descargue': horasEsperaDescargue,
        'observaciones': observaciones,
        'aceptacion_electronica': aceptacionElectronica,
        'estado': estado,
        'created_by': createdBy,
      };
}
