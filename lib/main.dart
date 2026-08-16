import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'data/datasource/local_store.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/dispatch/providers/remesa_provider.dart';
import 'modules/dispatch/providers/manifiesto_provider.dart';
import 'modules/history/providers/history_provider.dart';
import 'modules/remesas/providers/remesas_list_provider.dart';
import 'modules/manifiestos/providers/manifiestos_list_provider.dart';
import 'modules/manifiestos/providers/nuevo_manifiesto_provider.dart';
import 'modules/manifiestos/providers/firma_provider.dart';
import 'modules/vehiculos/providers/vehiculos_provider.dart';
import 'modules/settings/providers/settings_provider.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final store = LocalStore();
  final settingsProvider = SettingsProvider(store);
  await settingsProvider.load();

  runApp(MainApp(store: store, settingsProvider: settingsProvider));
  FlutterNativeSplash.remove();
}

class MainApp extends StatelessWidget {
  final LocalStore store;
  final SettingsProvider settingsProvider;

  const MainApp({
    super.key,
    required this.store,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalStore>.value(value: store),
        ChangeNotifierProvider(create: (_) => AuthProvider(store)),
        ChangeNotifierProvider(create: (_) => RemesaProvider(store)),
        ChangeNotifierProvider(create: (_) => ManifiestoProvider(store)),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => RemesasListProvider()),
        ChangeNotifierProvider(create: (_) => ManifiestosListProvider()),
        ChangeNotifierProvider(create: (_) => NuevoManifiestoProvider()),
        ChangeNotifierProvider(create: (_) => FirmaProvider()),
        ChangeNotifierProvider(create: (_) => VehiculosProvider()),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: CargoDespachoApp(store: store),
    );
  }
}
