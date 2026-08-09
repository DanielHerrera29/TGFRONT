import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transportegutierrez/core/theme/app_theme.dart';
import 'package:transportegutierrez/modules/history/providers/history_provider.dart';
import 'package:transportegutierrez/modules/history/screens/history_screen.dart';

void main() {
  testWidgets(
    'history explains error, source and next action on compact screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = HistoryProvider(loader: () async => [_errorItem]);
      await provider.load();

      await tester.pumpWidget(_history(provider, textScale: 1.35));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
      await tester.pump();

      expect(find.text('Requiere atención'), findsOneWidget);
      expect(find.text('Error en Manifiesto RNDC'), findsOneWidget);
      expect(
        find.textContaining('La placa no está registrada'),
        findsOneWidget,
      );
      expect(find.text('Qué sigue'), findsOneWidget);
      expect(find.text('Supabase: remesas + manifiestos'), findsOneWidget);
      expect(find.text('Estado de remesa'), findsOneWidget);
      expect(find.text('Estado de manifiesto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history shows a retryable data-source error', (tester) async {
    final provider = HistoryProvider(
      loader: () async => throw Exception('connection refused'),
    );
    await provider.load();

    await tester.pumpWidget(_history(provider));

    expect(find.text('No se pudo cargar el historial'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('No hay remesas registradas'), findsNothing);
  });

  test('history searches identifiers and error details', () async {
    final provider = HistoryProvider(loader: () async => [_errorItem]);
    await provider.load();

    provider.setSearch('MAN-009');
    expect(provider.items, hasLength(1));

    provider.setSearch('placa no está');
    expect(provider.items, hasLength(1));

    provider.setSearch('sin coincidencia');
    expect(provider.items, isEmpty);
  });
}

Widget _history(HistoryProvider provider, {double textScale = 1}) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const HistoryScreen(autoLoad: false),
        ),
      ),
    ),
  );
}

final _errorItem = DispatchesViewItem(
  remesaId: 'remesa-1',
  remesaConsecutivo: 'REM-014',
  manifiestoId: 'manifiesto-1',
  manifiestoConsecutivo: 'MAN-009',
  remesaEstado: 'sent_rndc',
  manifiestoEstado: 'error_rndc',
  clienteNombre: 'Constructora Central',
  conductorNombre: 'Carlos Pérez',
  placaVehiculo: 'ABC123',
  errorDetalle: 'La placa no está registrada en RNDC.',
  errorOrigen: 'Manifiesto RNDC',
  createdAt: DateTime(2026, 8, 4, 8, 30),
  updatedAt: DateTime(2026, 8, 4, 9, 15),
);
