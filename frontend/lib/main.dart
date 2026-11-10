import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'screens/admin_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  final auth = AuthSession(api: api);
  await auth.bootstrap();
  runApp(QasatlyMohanadApp(api: api, auth: auth));
}

class QasatlyMohanadApp extends StatelessWidget {
  const QasatlyMohanadApp({super.key, required this.api, required this.auth});

  final ApiService api;
  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'قساطي مهند',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          if (!auth.ready) {
            return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.soft),
              ),
            );
          }
          if (!auth.isAuthenticated) {
            return LoginScreen(auth: auth);
          }
          if (auth.user?.isAdmin == true) {
            return AdminHomeScreen(api: api, auth: auth);
          }
          return HomeScreen(api: api, auth: auth);
        },
      ),
    );
  }
}
