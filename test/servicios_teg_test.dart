import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportegutierrez/modules/modelo_teg/servicios_teg_screen.dart';

void main() {
  testWidgets(
    'el rango se aplica a consulta y exportación y Todos lo elimina',
    (tester) async {
      final queries = <List<String?>>[];
      List<String?>? exported;
      await tester.pumpWidget(
        MaterialApp(
          home: ServiciosTegScreen(
            cargar: ({desde, hasta, cursor, corte}) async {
              queries.add([desde, hasta]);
              return {
                'rows': [
                  {'id': 'fixture', 'folio': 1},
                ],
                'next': null,
                'corte': '2026-09-21T00:00:00Z',
              };
            },
            exportar: ({desde, hasta, corte}) async {
              exported = [desde, hasta];
              return Uint8List.fromList([80, 75]);
            },
            guardar: (_, _, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filtrar por fechas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '2026-09-01');
      await tester.enterText(find.byType(TextFormField).last, '2026-09-20');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(queries.last, ['2026-09-01', '2026-09-20']);
      await tester.tap(find.text('Generar Excel'));
      await tester.pumpAndSettle();
      expect(exported, ['2026-09-01', '2026-09-20']);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(queries.last, [null, null]);
    },
  );
  final first = {
    'id': '1',
    'folio': 1,
    'cliente': 'Cliente prueba',
    'estado': 'BORRADOR',
    'maquina': 'Máquina',
    'fechaRegistro': '2026-09-20T04:30:00Z',
  };
  testWidgets(
    'exportar Todos incluye alcance completo sin depender de páginas visibles',
    (tester) async {
      var exports = 0;
      String? fileName;
      final pending = Completer<Uint8List>();
      await tester.pumpWidget(
        MaterialApp(
          home: ServiciosTegScreen(
            cargar: ({desde, hasta, cursor, corte}) async => {
              'rows': [first],
              'next': '1',
              'corte': '2026-09-21T00:00:00Z',
            },
            exportar: ({desde, hasta, corte}) {
              expect(desde, isNull);
              expect(hasta, isNull);
              expect(corte, '2026-09-21T00:00:00Z');
              exports++;
              return pending.future;
            },
            guardar: (bytes, name, rect) async {
              expect(bytes, [80, 75, 1, 2]);
              fileName = name;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('1 servicios cargados · Hay más resultados'),
        findsOneWidget,
      );
      await tester.tap(find.text('Generar Excel'));
      await tester.pump();
      expect(find.text('Generando Excel…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(Uint8List.fromList([80, 75, 1, 2]));
      await tester.pumpAndSettle();
      expect(exports, 1);
      expect(fileName, 'MODELO_BASE_DATOS_TEG_todos.xlsx');
    },
  );

  testWidgets(
    'consulta vacía y error permiten reintentar sin exportar datos anteriores',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ServiciosTegScreen(
            cargar: ({desde, hasta, cursor, corte}) async {
              if (attempts++ == 0) throw Exception('fallo simulado');
              return {
                'rows': [],
                'next': null,
                'corte': '2026-09-21T00:00:00Z',
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar consulta'), findsOneWidget);
      await tester.tap(find.text('Reintentar consulta'));
      await tester.pumpAndSettle();
      expect(find.text('No hay servicios para este filtro.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('pantalla compacta con texto ampliado y selector de fechas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ServiciosTegScreen(
          cargar: ({desde, hasta, cursor, corte}) async => {
            'rows': [first],
            'next': null,
            'corte': '2026-09-21T00:00:00Z',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Filtrar por fechas'));
    await tester.tap(find.text('Filtrar por fechas'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
