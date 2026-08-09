import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/datasource/local_store.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/screens/login_screen.dart';
import 'modules/auth/screens/register_user_screen.dart';
import 'modules/auth/screens/forgot_password_screen.dart';
import 'modules/auth/screens/manage_users_screen.dart';
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/dispatch/screens/new_dispatch_screen.dart';
import 'modules/history/screens/history_screen.dart';
import 'modules/history/screens/remesa_detail_screen.dart' as history;
import 'modules/settings/screens/settings_screen.dart';
import 'modules/remesas/screens/remesas_screen.dart';
import 'modules/remesas/screens/remesa_detail_screen.dart';
import 'modules/manifiestos/screens/manifiestos_screen.dart';
import 'modules/manifiestos/screens/manifiesto_detail_screen.dart';
import 'modules/manifiestos/screens/nuevo_manifiesto_screen.dart';
import 'modules/manifiestos/screens/pendientes_firma_screen.dart';
import 'modules/vehiculos/screens/vehiculos_screen.dart';
import 'modules/ordenes_escolta/screens/nueva_orden_escolta_screen.dart';
import 'modules/ordenes_escolta/screens/ordenes_escolta_screen.dart';

class CargoDespachoApp extends StatefulWidget {
  final LocalStore store;

  const CargoDespachoApp({super.key, required this.store});

  @override
  State<CargoDespachoApp> createState() => _CargoDespachoAppState();
}

class _CargoDespachoAppState extends State<CargoDespachoApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CargoDespacho',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: widget.store,
      redirect: (context, state) {
        final loggedIn = widget.store.isLoggedIn;
        final onLogin = state.matchedLocation == '/login';
        final onForgotPassword = state.matchedLocation == '/forgot-password';
        if (!loggedIn && !onLogin && !onForgotPassword) return '/login';
        if (loggedIn && onLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => const ForgotPasswordScreen(),
        ),
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        GoRoute(
          path: '/dispatch',
          builder: (_, _) => const NewDispatchScreen(),
        ),
        GoRoute(
          path: '/ordenes-escolta',
          builder: (_, _) => const OrdenesEscoltaScreen(),
        ),
        GoRoute(
          path: '/ordenes-escolta/nueva',
          builder: (_, _) => const NuevaOrdenEscoltaScreen(),
        ),
        GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        GoRoute(
          path: '/history/:id',
          builder: (_, state) =>
              history.RemesaDetailScreen(remesaId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/register-user',
          builder: (_, _) => const RegisterUserScreen(),
        ),
        GoRoute(
          path: '/manage-users',
          builder: (_, _) => const ManageUsersScreen(),
        ),
        GoRoute(path: '/remesas', builder: (_, _) => const RemesasScreen()),
        GoRoute(
          path: '/remesas/nueva',
          builder: (_, _) => const NewDispatchScreen(),
        ),
        GoRoute(
          path: '/remesas/:id',
          builder: (_, state) =>
              RemesaDetailScreen(remesaId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/manifiestos',
          builder: (_, _) => const ManifiestosScreen(),
        ),
        GoRoute(
          path: '/manifiestos/:id',
          builder: (_, state) =>
              ManifiestoDetailScreen(manifiestoId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/manifiestos/nuevo',
          builder: (_, state) {
            final remesaId = state.extra as String?;
            return NuevoManifiestoScreen(remesaIdPreseleccionada: remesaId);
          },
        ),
        GoRoute(path: '/vehiculos', builder: (_, _) => const VehiculosScreen()),
        GoRoute(
          path: '/manifiestos/pendientes-firma',
          builder: (_, _) => const PendientesDeFirmaScreen(),
        ),
      ],
    );
  }
}
