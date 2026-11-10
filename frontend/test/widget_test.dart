import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qasatly_mohanad/main.dart';
import 'package:qasatly_mohanad/services/api_service.dart';
import 'package:qasatly_mohanad/services/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen boots when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiService();
    final auth = AuthSession(api: api);
    await auth.bootstrap();

    await tester.pumpWidget(QasatlyMohanadApp(api: api, auth: auth));
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });
}
