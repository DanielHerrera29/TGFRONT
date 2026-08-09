class Remesa {
  final String id;
  final String consecutivo;

  // Generador
  final String generadorTipoId;
  final String generadorNit;
  final String? generadorDv;
  final String? generadorNombre;
  final String generadorSede;

  // Remitente (cargue)
  final String remitenteTipoId;
  final String remitenteNit;
  final String? remitenteNombre;
  final String remitenteSede;
  final String? remitenteDireccion;
  final String remitenteMunicipioDane;

  // Destinatario (descargue)
  final String destinatarioTipoId;
  final String destinatarioNit;
  final String? destinatarioNombre;
  final String destinatarioSede;
  final String? destinatarioDireccion;
  final String destinatarioMunicipioDane;

  // Mercancía
  final String naturalezaCarga;
  final String? codigoProducto;
  final String? descripcionProducto;
  final String? tipoEmpaque;
  final double? cantidad;
  final String unidadMedida;
  final double pesoKg;

  // Operación
  final String tipoOperacion;
  final double valorMercancia;
  final double valorFlete;

  // Póliza
  final String? polizaNumero;
  final DateTime? polizaVencimiento;
  final String? polizaAseguradora;
  final String? polizaAseguradoraNit;

  // Campos del mensaje WhatsApp (solo para UI/parser — no van a DB directo)
  final String? rawMessage;
  final String? clienteNombre;
  final String? obra;
  final String? programa;
  final String? observaciones;

  // Campos extraídos del WhatsApp para pre-cargar Manifiesto (no van a DB)
  final String? conductorNombre;
  final String? conductorDocumento;
  final String? placa;
  final String? fechaCargue;
  final String? horaCargue;
  final String? tipoCarga;
  final String? origen;
  final String? destino;

  // Respuesta RNDC
  final String? radicadoRndc;
  final String? xmlEnviado;
  final String? xmlRespuesta;

  // Estado
  final String estado;
  final String? errorDetalle;

  // Auditoría
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Remesa({
    String? id,
    required this.consecutivo,
    this.generadorTipoId = 'N',
    required this.generadorNit,
    this.generadorDv,
    this.generadorNombre,
    this.generadorSede = '00',
    this.remitenteTipoId = 'N',
    required this.remitenteNit,
    this.remitenteNombre,
    this.remitenteSede = '00',
    this.remitenteDireccion,
    this.remitenteMunicipioDane = '11001000',
    this.destinatarioTipoId = 'N',
    required this.destinatarioNit,
    this.destinatarioNombre,
    this.destinatarioSede = '00',
    this.destinatarioDireccion,
    this.destinatarioMunicipioDane = '11001000',
    this.naturalezaCarga = '1',
    this.codigoProducto,
    this.descripcionProducto,
    this.tipoEmpaque,
    this.cantidad,
    this.unidadMedida = '1',
    required this.pesoKg,
    this.tipoOperacion = 'G',
    this.valorMercancia = 0,
    this.valorFlete = 0,
    this.polizaNumero,
    this.polizaVencimiento,
    this.polizaAseguradora,
    this.polizaAseguradoraNit,
    this.rawMessage,
    this.clienteNombre,
    this.obra,
    this.programa,
    this.observaciones,
    this.conductorNombre,
    this.conductorDocumento,
    this.placa,
    this.fechaCargue,
    this.horaCargue,
    this.tipoCarga,
    this.origen,
    this.destino,
    this.radicadoRndc,
    this.xmlEnviado,
    this.xmlRespuesta,
    this.estado = 'draft',
    this.errorDetalle,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Remesa.fromMap(Map<String, dynamic> map) => Remesa(
    id: map['id'],
    consecutivo: map['consecutivo']?.toString() ?? '',
    generadorTipoId: map['generador_tipo_id'] ?? 'N',
    generadorNit: map['generador_nit'] ?? '',
    generadorDv: map['generador_dv']?.toString(),
    generadorNombre: map['generador_nombre']?.toString(),
    generadorSede: map['generador_sede'] ?? '00',
    remitenteTipoId: map['remitente_tipo_id'] ?? 'N',
    remitenteNit: map['remitente_nit'] ?? '',
    remitenteNombre: map['remitente_nombre']?.toString(),
    remitenteSede: map['remitente_sede'] ?? '00',
    remitenteDireccion: map['remitente_direccion']?.toString(),
    remitenteMunicipioDane: map['remitente_municipio_dane'] ?? '11001000',
    destinatarioTipoId: map['destinatario_tipo_id'] ?? 'N',
    destinatarioNit: map['destinatario_nit'] ?? '',
    destinatarioNombre: map['destinatario_nombre']?.toString(),
    destinatarioSede: map['destinatario_sede'] ?? '00',
    destinatarioDireccion: map['destinatario_direccion']?.toString(),
    destinatarioMunicipioDane: map['destinatario_municipio_dane'] ?? '11001000',
    naturalezaCarga: map['naturaleza_carga'] ?? '1',
    codigoProducto: map['codigo_producto']?.toString(),
    descripcionProducto: map['descripcion_producto']?.toString(),
    tipoEmpaque: map['tipo_empaque']?.toString(),
    cantidad: (map['cantidad'] as num?)?.toDouble(),
    unidadMedida: map['unidad_medida'] ?? '1',
    pesoKg: (map['peso_kg'] ?? 0).toDouble(),
    tipoOperacion: map['tipo_operacion'] ?? 'G',
    valorMercancia: (map['valor_mercancia'] ?? 0).toDouble(),
    valorFlete: (map['valor_flete'] ?? 0).toDouble(),
    polizaNumero: map['poliza_numero']?.toString(),
    polizaVencimiento: map['poliza_vencimiento'] != null
        ? DateTime.tryParse(map['poliza_vencimiento'].toString())
        : null,
    polizaAseguradora: map['poliza_aseguradora']?.toString(),
    polizaAseguradoraNit: map['poliza_aseguradora_nit']?.toString(),
    rawMessage: map['raw_message']?.toString(),
    clienteNombre: map['cliente_nombre']?.toString(),
    obra: map['obra']?.toString(),
    programa: map['programa']?.toString(),
    observaciones: map['observaciones']?.toString(),
    conductorNombre: map['conductor_nombre']?.toString(),
    conductorDocumento: map['conductor_documento']?.toString(),
    placa: map['placa']?.toString(),
    fechaCargue: map['fecha_cargue']?.toString(),
    horaCargue: map['hora_cargue']?.toString(),
    tipoCarga: map['tipo_carga']?.toString(),
    origen: map['origen']?.toString(),
    destino: map['destino']?.toString(),
    radicadoRndc: map['radicado_rndc']?.toString(),
    xmlEnviado: map['xml_enviado']?.toString(),
    xmlRespuesta: map['xml_respuesta']?.toString(),
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

  Remesa copyWith({
    String? id,
    String? consecutivo,
    String? generadorTipoId,
    String? generadorNit,
    String? generadorDv,
    String? generadorNombre,
    String? generadorSede,
    String? remitenteTipoId,
    String? remitenteNit,
    String? remitenteNombre,
    String? remitenteSede,
    String? remitenteDireccion,
    String? remitenteMunicipioDane,
    String? destinatarioTipoId,
    String? destinatarioNit,
    String? destinatarioNombre,
    String? destinatarioSede,
    String? destinatarioDireccion,
    String? destinatarioMunicipioDane,
    String? naturalezaCarga,
    String? codigoProducto,
    String? descripcionProducto,
    String? tipoEmpaque,
    double? cantidad,
    String? unidadMedida,
    double? pesoKg,
    String? tipoOperacion,
    double? valorMercancia,
    double? valorFlete,
    String? polizaNumero,
    DateTime? polizaVencimiento,
    String? polizaAseguradora,
    String? polizaAseguradoraNit,
    String? rawMessage,
    String? clienteNombre,
    String? obra,
    String? programa,
    String? observaciones,
    String? conductorNombre,
    String? conductorDocumento,
    String? placa,
    String? fechaCargue,
    String? horaCargue,
    String? tipoCarga,
    String? origen,
    String? destino,
    String? radicadoRndc,
    String? xmlEnviado,
    String? xmlRespuesta,
    String? estado,
    String? errorDetalle,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Remesa(
      id: id ?? this.id,
      consecutivo: consecutivo ?? this.consecutivo,
      generadorTipoId: generadorTipoId ?? this.generadorTipoId,
      generadorNit: generadorNit ?? this.generadorNit,
      generadorDv: generadorDv ?? this.generadorDv,
      generadorNombre: generadorNombre ?? this.generadorNombre,
      generadorSede: generadorSede ?? this.generadorSede,
      remitenteTipoId: remitenteTipoId ?? this.remitenteTipoId,
      remitenteNit: remitenteNit ?? this.remitenteNit,
      remitenteNombre: remitenteNombre ?? this.remitenteNombre,
      remitenteSede: remitenteSede ?? this.remitenteSede,
      remitenteDireccion: remitenteDireccion ?? this.remitenteDireccion,
      remitenteMunicipioDane:
          remitenteMunicipioDane ?? this.remitenteMunicipioDane,
      destinatarioTipoId: destinatarioTipoId ?? this.destinatarioTipoId,
      destinatarioNit: destinatarioNit ?? this.destinatarioNit,
      destinatarioNombre: destinatarioNombre ?? this.destinatarioNombre,
      destinatarioSede: destinatarioSede ?? this.destinatarioSede,
      destinatarioDireccion:
          destinatarioDireccion ?? this.destinatarioDireccion,
      destinatarioMunicipioDane:
          destinatarioMunicipioDane ?? this.destinatarioMunicipioDane,
      naturalezaCarga: naturalezaCarga ?? this.naturalezaCarga,
      codigoProducto: codigoProducto ?? this.codigoProducto,
      descripcionProducto: descripcionProducto ?? this.descripcionProducto,
      tipoEmpaque: tipoEmpaque ?? this.tipoEmpaque,
      cantidad: cantidad ?? this.cantidad,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      pesoKg: pesoKg ?? this.pesoKg,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      valorMercancia: valorMercancia ?? this.valorMercancia,
      valorFlete: valorFlete ?? this.valorFlete,
      polizaNumero: polizaNumero ?? this.polizaNumero,
      polizaVencimiento: polizaVencimiento ?? this.polizaVencimiento,
      polizaAseguradora: polizaAseguradora ?? this.polizaAseguradora,
      polizaAseguradoraNit: polizaAseguradoraNit ?? this.polizaAseguradoraNit,
      rawMessage: rawMessage ?? this.rawMessage,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      obra: obra ?? this.obra,
      programa: programa ?? this.programa,
      observaciones: observaciones ?? this.observaciones,
      conductorNombre: conductorNombre ?? this.conductorNombre,
      conductorDocumento: conductorDocumento ?? this.conductorDocumento,
      placa: placa ?? this.placa,
      fechaCargue: fechaCargue ?? this.fechaCargue,
      horaCargue: horaCargue ?? this.horaCargue,
      tipoCarga: tipoCarga ?? this.tipoCarga,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      radicadoRndc: radicadoRndc ?? this.radicadoRndc,
      xmlEnviado: xmlEnviado ?? this.xmlEnviado,
      xmlRespuesta: xmlRespuesta ?? this.xmlRespuesta,
      estado: estado ?? this.estado,
      errorDetalle: errorDetalle ?? this.errorDetalle,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'consecutivo': consecutivo,
    'generador_tipo_id': generadorTipoId,
    'generador_nit': generadorNit,
    'generador_dv': generadorDv,
    'generador_nombre': generadorNombre,
    'generador_sede': generadorSede,
    'remitente_tipo_id': remitenteTipoId,
    'remitente_nit': remitenteNit,
    'remitente_nombre': remitenteNombre,
    'remitente_sede': remitenteSede,
    'remitente_direccion': remitenteDireccion,
    'remitente_municipio_dane': remitenteMunicipioDane,
    'destinatario_tipo_id': destinatarioTipoId,
    'destinatario_nit': destinatarioNit,
    'destinatario_nombre': destinatarioNombre,
    'destinatario_sede': destinatarioSede,
    'destinatario_direccion': destinatarioDireccion,
    'destinatario_municipio_dane': destinatarioMunicipioDane,
    'naturaleza_carga': naturalezaCarga,
    'codigo_producto': codigoProducto,
    'descripcion_producto': descripcionProducto,
    'tipo_empaque': tipoEmpaque,
    'cantidad': cantidad,
    'unidad_medida': unidadMedida,
    'peso_kg': pesoKg,
    'tipo_operacion': tipoOperacion,
    'valor_mercancia': valorMercancia,
    'valor_flete': valorFlete,
    'poliza_numero': polizaNumero,
    'poliza_vencimiento': polizaVencimiento?.toIso8601String(),
    'poliza_aseguradora': polizaAseguradora,
    'poliza_aseguradora_nit': polizaAseguradoraNit,
    'raw_message': rawMessage,
    'cliente_nombre': clienteNombre,
    'obra': obra,
    'programa': programa,
    'observaciones': observaciones,
    'estado': estado,
    'created_by': createdBy,
  };
}
