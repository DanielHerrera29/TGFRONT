class AppSettings {
  final String id;

  // Empresa
  final String? empresaNombre;
  final String empresaNit;
  final String? empresaDv;
  final String? empresaDireccion;
  final String? empresaTelefono;
  final String? empresaCiudad;
  final String empresaMunicipioDane;

  // Póliza por defecto
  final String? polizaNumero;
  final DateTime? polizaVencimiento;
  final String? polizaAseguradora;
  final String? polizaAseguradoraNit;

  // Generador por defecto
  final String generadorTipoId;
  final String? generadorNit;
  final String? generadorDv;
  final String? generadorNombre;
  final String generadorSede;

  // Modo RNDC: 'S' = simulación, 'R' = real
  final String simulacion;

  // Consecutivos
  final int consecutivoRemesa;
  final int consecutivoManifiesto;

  AppSettings({
    required this.id,
    this.empresaNombre,
    required this.empresaNit,
    this.empresaDv,
    this.empresaDireccion,
    this.empresaTelefono,
    this.empresaCiudad,
    this.empresaMunicipioDane = '11001000',
    this.polizaNumero,
    this.polizaVencimiento,
    this.polizaAseguradora,
    this.polizaAseguradoraNit,
    this.generadorTipoId = 'N',
    this.generadorNit,
    this.generadorDv,
    this.generadorNombre,
    this.generadorSede = '00',
    this.simulacion = 'S',
    this.consecutivoRemesa = 1,
    this.consecutivoManifiesto = 1,
  });

  bool get esModoSimulacion => simulacion == 'S';

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    id: map['id']?.toString() ?? '',
    empresaNombre: map['empresa_nombre']?.toString(),
    empresaNit: map['empresa_nit']?.toString() ?? '',
    empresaDv: map['empresa_dv']?.toString(),
    empresaDireccion: map['empresa_direccion']?.toString(),
    empresaTelefono: map['empresa_telefono']?.toString(),
    empresaCiudad: map['empresa_ciudad']?.toString(),
    empresaMunicipioDane:
        map['empresa_municipio_dane']?.toString() ?? '11001000',
    polizaNumero: map['poliza_numero']?.toString(),
    polizaVencimiento: map['poliza_vencimiento'] != null
        ? DateTime.tryParse(map['poliza_vencimiento'].toString())
        : null,
    polizaAseguradora: map['poliza_aseguradora']?.toString(),
    polizaAseguradoraNit: map['poliza_aseguradora_nit']?.toString(),
    generadorTipoId: map['generador_tipo_id']?.toString() ?? 'N',
    generadorNit: map['generador_nit']?.toString(),
    generadorDv: map['generador_dv']?.toString(),
    generadorNombre: map['generador_nombre']?.toString(),
    generadorSede: map['generador_sede']?.toString() ?? '00',
    simulacion: map['simulacion']?.toString() ?? 'S',
    consecutivoRemesa: map['consecutivo_remesa'] ?? 1,
    consecutivoManifiesto: map['consecutivo_manifiesto'] ?? 1,
  );

  Map<String, dynamic> toUpdateMap() => {
    'empresa_nombre': empresaNombre,
    'empresa_nit': empresaNit,
    'empresa_dv': empresaDv,
    'empresa_direccion': empresaDireccion,
    'empresa_telefono': empresaTelefono,
    'empresa_ciudad': empresaCiudad,
    'empresa_municipio_dane': empresaMunicipioDane,
    'poliza_numero': polizaNumero,
    'poliza_vencimiento': polizaVencimiento?.toIso8601String(),
    'poliza_aseguradora': polizaAseguradora,
    'poliza_aseguradora_nit': polizaAseguradoraNit,
    'generador_tipo_id': generadorTipoId,
    'generador_nit': generadorNit,
    'generador_dv': generadorDv,
    'generador_nombre': generadorNombre,
    'generador_sede': generadorSede,
    'simulacion': simulacion,
  };
}
