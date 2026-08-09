import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/firma_provider.dart';

class PendientesDeFirmaScreen extends StatefulWidget {
  const PendientesDeFirmaScreen({super.key});

  @override
  State<PendientesDeFirmaScreen> createState() =>
      _PendientesDeFirmaScreenState();
}

class _PendientesDeFirmaScreenState extends State<PendientesDeFirmaScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final fp = context.read<FirmaProvider>();
    if (auth.user != null) {
      await fp.loadPendientes(
        rndcUsername: auth.user!.email,
        rndcPassword: auth.user!.password,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FirmaProvider>();
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes de Firma'),
        centerTitle: true,
      ),
      body: fp.loadingPendientes
          ? const Center(child: CircularProgressIndicator())
          : fp.pendientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No hay manifiestos pendientes de firma',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fp.pendientes.length,
                    itemBuilder: (ctx, i) {
                      final p = fp.pendientes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.pending_actions,
                                      size: 20,
                                      color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Manifiesto #${p.consecutivo}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                  label: 'Placa',
                                  value: p.placa ?? '—'),
                              _InfoRow(
                                  label: 'Conductor',
                                  value: p.conductorNombre ?? '—'),
                              _InfoRow(
                                  label: 'Titular',
                                  value: p.titularNombre ?? '—'),
                              if (p.fechaExpedicion != null)
                                _InfoRow(
                                    label: 'Expedición',
                                    value: df.format(p.fechaExpedicion!)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
