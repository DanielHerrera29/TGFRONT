import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FirmaCompletaScreen extends StatelessWidget {
  const FirmaCompletaScreen({super.key, required this.controller});

  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma autorizada'),
        actions: [
          Tooltip(
            message: 'Borrar y volver a firmar',
            child: IconButton(
              onPressed: controller.clear,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Firme dentro del recuadro',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text('Use un dedo o lapiz digital. Esta firma se incluirá en el PDF.'),
              const SizedBox(height: 16),
              Expanded(
                child: Semantics(
                  label: 'Area para firma autorizada',
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.primary, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Signature(
                      controller: controller,
                      backgroundColor: colors.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: controller.clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpiar firma'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  if (controller.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La firma es obligatoria.')),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('Usar esta firma'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FirmaCard extends StatelessWidget {
  const FirmaCard({
    required this.firmada,
    required this.enabled,
    required this.onPressed,
  });

  final bool firmada;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: firmada ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(firmada ? Icons.draw_outlined : Icons.border_color_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Firma autorizada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                firmada ? Icons.check_circle : Icons.error_outline,
                color: firmada ? colors.primary : colors.error,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            firmada
                ? 'Firma registrada. Puede modificarla antes de enviar.'
                : 'Obligatoria para generar y enviar la orden.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: Icon(firmada ? Icons.edit_outlined : Icons.draw_outlined),
              label: Text(firmada ? 'Modificar firma' : 'Firmar ahora'),
            ),
          ),
        ],
      ),
    );
  }
}
