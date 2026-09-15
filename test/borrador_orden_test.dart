import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transportegutierrez/modules/ordenes_escolta/borrador_orden.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'nueva orden vacía conserva y permite abrir cada borrador anterior',
    () async {
      final first = await BorradorOrden.load('a', nueva: true);
      await first.capture({
        'empresa': 'Primera',
        'viajes': [
          {'clientItemId': 'viaje-1'},
        ],
      });
      final second = await BorradorOrden.load('a', nueva: true);
      expect(
        second.state['clientOrderId'],
        isNot(first.state['clientOrderId']),
      );
      expect(second.state['fields'], isNull);
      await second.capture({'empresa': 'Segunda'});
      final restored = await BorradorOrden.load(
        'a',
        orderId: first.state['clientOrderId'],
      );
      expect(restored.state['fields']['empresa'], 'Primera');
      expect((await BorradorOrden.locales('a')).length, 2);
      expect(await BorradorOrden.locales('b'), isEmpty);
    },
  );
  test('otra orden no reemplaza una operación de resultado incierto', () async {
    final first = await BorradorOrden.load('a', nueva: true);
    await first.capture({'empresa': 'Pendiente'});
    await expectLater(
      first.save(
        'token',
        confirmar: false,
        send: (_) async => throw TimeoutException('timeout'),
      ),
      throwsA(isA<TimeoutException>()),
    );
    final operation = first.state['pending'];
    final next = await BorradorOrden.load('a', nueva: true);
    await next.capture({'empresa': 'Nueva'});
    final restored = await BorradorOrden.load(
      'a',
      orderId: first.state['clientOrderId'],
    );
    expect(restored.state['pending'], operation);
  });
  test('rechazo explícito permite corregir sin perder identidad', () async {
    final draft = await BorradorOrden.load('a');
    final id = draft.state['clientOrderId'];
    await draft.capture({'empresa': 'Original'});
    await expectLater(
      draft.save(
        'token',
        confirmar: false,
        send: (_) async => throw BorradorApiException(400),
      ),
      throwsA(isA<BorradorApiException>()),
    );
    expect(draft.pending, false);
    await draft.capture({'empresa': 'Corregida'});
    expect(draft.state['clientOrderId'], id);
    expect(draft.state['fields']['empresa'], 'Corregida');
  });
  test('doble guardado concurrente no emite segunda solicitud', () async {
    final draft = await BorradorOrden.load('a');
    final completed = Completer<Map<String, dynamic>>();
    final entered = Completer<void>();
    var calls = 0;
    final first = draft.save(
      'token',
      confirmar: false,
      send: (_) {
        calls++;
        entered.complete();
        return completed.future;
      },
    );
    await entered.future;
    await expectLater(
      draft.save(
        'token',
        confirmar: false,
        send: (_) async {
          calls++;
          return {};
        },
      ),
      throwsStateError,
    );
    completed.complete({'version': 1, 'estado': 'BORRADOR'});
    await first;
    expect(calls, 1);
  });
  test(
    'recuperar servidor conserva respaldo y limpia solicitud en conflicto',
    () async {
      final draft = await BorradorOrden.load('a');
      await draft.capture({'empresa': 'Local'});
      await expectLater(
        draft.save(
          'token',
          confirmar: false,
          send: (_) async => throw BorradorApiException(409),
        ),
        throwsA(isA<BorradorApiException>()),
      );
      expect(draft.pending, true);
      await draft.recover(
        'token',
        fetch: () async => {
          'clientOrderId': draft.state['clientOrderId'],
          'version': 2,
          'fields': {'empresa': 'Servidor'},
          'result': {'estado': 'BORRADOR'},
        },
      );
      expect(draft.pending, false);
      expect(draft.state['fields']['empresa'], 'Servidor');
      expect(
        draft.prefs.getString('orden_draft_backup_v1_a'),
        contains('Local'),
      );
    },
  );
  test(
    'timeout y reinicio conservan solicitud exacta e identidad del viaje',
    () async {
      final draft = await BorradorOrden.load('escolta-a');
      await draft.capture({
        'viajes': [
          {'clientItemId': 'viaje-a', 'maquina': ''},
        ],
      });
      Map<String, dynamic>? request;
      await expectLater(
        draft.save(
          'token',
          confirmar: false,
          send: (body) async {
            request = body;
            throw Exception('respuesta perdida tras commit');
          },
        ),
        throwsException,
      );
      final recovered = await BorradorOrden.load('escolta-a');
      expect(recovered.pending, isTrue);
      await recovered.save(
        'token',
        confirmar: false,
        send: (body) async {
          expect(body, request);
          return {
            'id': 'orden-a',
            'version': 1,
            'estado': 'BORRADOR',
            'items': [
              {'clientItemId': 'viaje-a', 'servicioId': 'servicio-a'},
            ],
          };
        },
      );
      expect(recovered.pending, isFalse);
      final reopened = await BorradorOrden.load('escolta-a');
      expect(reopened.state['result']['items'][0]['servicioId'], 'servicio-a');
    },
  );
  test(
    'completar borrador mantiene clientItemId y usa nueva operación/version',
    () async {
      final draft = await BorradorOrden.load('escolta-a');
      await draft.capture({
        'viajes': [
          {'clientItemId': 'viaje-a', 'maquina': ''},
        ],
      });
      String? firstKey;
      await draft.save(
        'token',
        confirmar: false,
        send: (body) async {
          firstKey = body['clave'];
          return {'version': 1, 'estado': 'BORRADOR'};
        },
      );
      await draft.capture({
        'viajes': [
          {'clientItemId': 'viaje-a', 'maquina': 'Máquina completa'},
          {'clientItemId': 'viaje-b'},
        ],
      });
      await draft.save(
        'token',
        confirmar: false,
        send: (body) async {
          expect(body['clave'], isNot(firstKey));
          expect(body['datos']['version'], 1);
          expect(body['datos']['viajes'][0]['clientItemId'], 'viaje-a');
          return {'version': 2, 'estado': 'BORRADOR'};
        },
      );
    },
  );
  test('reinicio antes de enviar conserva campos y separa usuarios', () async {
    final a = await BorradorOrden.load('a');
    await a.capture({'empresa': 'Cliente A', 'viajes': []});
    expect(
      (await BorradorOrden.load('a')).state['fields']['empresa'],
      'Cliente A',
    );
    expect((await BorradorOrden.load('b')).state['fields'], isNull);
  });
}
