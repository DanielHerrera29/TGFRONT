class Vehiculo {
  final String? id;
  final String numPlaca;
  final String codConfiguracionUnidadCarga;
  final double pesoVehiculoVacio;
  final String codTipoCarroceria;
  final String codTipoIdTenedor;
  final String numIdTenedor;

  final String? estado;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vehiculo({
    this.id,
    required this.numPlaca,
    required this.codConfiguracionUnidadCarga,
    required this.pesoVehiculoVacio,
    required this.codTipoCarroceria,
    required this.codTipoIdTenedor,
    required this.numIdTenedor,
    this.estado,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehiculo.fromMap(Map<String, dynamic> map) => Vehiculo(
        id: map['id']?.toString(),
        numPlaca: map['num_placa']?.toString() ?? '',
        codConfiguracionUnidadCarga:
            map['cod_configuracion_unidad_carga']?.toString() ?? '',
        pesoVehiculoVacio:
            (map['peso_vehiculo_vacio'] ?? 0).toDouble(),
        codTipoCarroceria:
            map['cod_tipo_carroceria']?.toString() ?? '',
        codTipoIdTenedor:
            map['cod_tipo_id_tenedor']?.toString() ?? '',
        numIdTenedor: map['num_id_tenedor']?.toString() ?? '',
        estado: map['estado']?.toString(),
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'num_placa': numPlaca.toUpperCase(),
        'cod_configuracion_unidad_carga': codConfiguracionUnidadCarga,
        'peso_vehiculo_vacio': pesoVehiculoVacio,
        'cod_tipo_carroceria': codTipoCarroceria,
        'cod_tipo_id_tenedor': codTipoIdTenedor,
        'num_id_tenedor': numIdTenedor,
      };

  Vehiculo copyWith({
    String? id,
    String? numPlaca,
    String? codConfiguracionUnidadCarga,
    double? pesoVehiculoVacio,
    String? codTipoCarroceria,
    String? codTipoIdTenedor,
    String? numIdTenedor,
    String? estado,
  }) {
    return Vehiculo(
      id: id ?? this.id,
      numPlaca: numPlaca ?? this.numPlaca,
      codConfiguracionUnidadCarga:
          codConfiguracionUnidadCarga ?? this.codConfiguracionUnidadCarga,
      pesoVehiculoVacio: pesoVehiculoVacio ?? this.pesoVehiculoVacio,
      codTipoCarroceria: codTipoCarroceria ?? this.codTipoCarroceria,
      codTipoIdTenedor: codTipoIdTenedor ?? this.codTipoIdTenedor,
      numIdTenedor: numIdTenedor ?? this.numIdTenedor,
      estado: estado ?? this.estado,
    );
  }
}

class VehiculoListItem {
  final String id;
  final String numPlaca;
  final String codConfiguracionUnidadCarga;
  final String codTipoCarroceria;
  final String numIdTenedor;
  final String? estado;

  VehiculoListItem({
    required this.id,
    required this.numPlaca,
    required this.codConfiguracionUnidadCarga,
    required this.codTipoCarroceria,
    required this.numIdTenedor,
    this.estado,
  });

  factory VehiculoListItem.fromMap(Map<String, dynamic> m) =>
      VehiculoListItem(
        id: m['id']?.toString() ?? '',
        numPlaca: m['num_placa']?.toString() ?? '',
        codConfiguracionUnidadCarga:
            m['cod_configuracion_unidad_carga']?.toString() ?? '',
        codTipoCarroceria: m['cod_tipo_carroceria']?.toString() ?? '',
        numIdTenedor: m['num_id_tenedor']?.toString() ?? '',
        estado: m['estado']?.toString(),
      );
}
