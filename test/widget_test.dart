import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transportegutierrez/core/theme/app_theme.dart';
import 'package:transportegutierrez/data/datasource/local_store.dart';
import 'package:transportegutierrez/data/models/app_user.dart';
import 'package:transportegutierrez/modules/auth/providers/auth_provider.dart';
import 'package:transportegutierrez/modules/dashboard/screens/dashboard_screen.dart';
import 'package:transportegutierrez/modules/manifiestos/providers/manifiestos_list_provider.dart';
import 'package:transportegutierrez/modules/remesas/providers/remesas_list_provider.dart';
import 'package:transportegutierrez/modules/settings/providers/settings_provider.dart';

void main() {
  testWidgets('dashboard renders on a compact screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_dashboard(textScale: 1.5));

    expect(find.text('CargoDespacho'), findsOneWidget);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.byKey(const Key('new-dispatch-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard exposes admin actions on a wide screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_dashboard());

    expect(find.text('Gestión de usuarios'), findsOneWidget);
    expect(find.text('Remesas pendientes'), findsOneWidget);
    expect(find.text('Manifiestos activos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _dashboard({double textScale = 1}) {
  final store = LocalStore()
    ..setSession(
      AppUser(
        id: 'test-user',
        name: 'Ana',
        email: 'ana@example.com',
        password: '',
        role: UserRole.admin,
        createdAt: DateTime(2026),
      ),
    );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => AuthProvider(store)),
      ChangeNotifierProvider(create: (_) => RemesasListProvider()),
      ChangeNotifierProvider(create: (_) => ManifiestosListProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const DashboardScreen(autoLoad: false),
        ),
      ),
    ),
  );
}
