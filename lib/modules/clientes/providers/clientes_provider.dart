import 'package:flutter/foundation.dart';
import '../../ordenes_escolta/borrador_orden.dart';
import '../../../data/models/cliente.dart';

class ClientesProvider extends ChangeNotifier {
  final String token;
  bool _disposed = false;
  ClientesProvider({required this.token});
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Cliente> _clientes = [];
  bool loading = false;
  String? error;
  List<Cliente> get clientes => _clientes;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await BorradorOrden.clients(token);
      _clientes = rows.map(Cliente.fromMap).toList();
    } catch (e) {
      error = 'No fue posible cargar los clientes: $e';
      _clientes = [];
    }
    loading = false;
    if (!_disposed) notifyListeners();
  }
}
