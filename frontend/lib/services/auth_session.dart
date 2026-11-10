import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';

/// جلسة داخل الذاكرة فقط — عند كل فتح للتطبيق يُطلب تسجيل الدخول.
class AuthSession extends ChangeNotifier {
  AuthSession({required ApiService api}) : _api = api;

  static const _tokenKey = 'qasatly_mohanad_auth_token';
  static const _userKey = 'qasatly_mohanad_auth_user';

  final ApiService _api;

  AppUser? _user;
  String? _token;
  bool _ready = false;
  bool _busy = false;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get ready => _ready;
  bool get busy => _busy;

  Future<void> bootstrap() async {
    // امسح أي جلسة محفوظة سابقاً واطلب الدخول دائماً عند فتح التطبيق.
    await _wipeStoredSession();
    _token = null;
    _user = null;
    _api.authToken = null;
    _ready = true;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.login(username: username, password: password);
      _token = result.token;
      _user = result.user;
      _api.authToken = result.token;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _busy = true;
    notifyListeners();
    try {
      await _api.logout();
    } catch (_) {
      // Local logout should always succeed.
    } finally {
      await clear();
    }
  }

  Future<void> clear({bool notify = true}) async {
    _token = null;
    _user = null;
    _api.authToken = null;
    _busy = false;
    await _wipeStoredSession();
    if (notify) notifyListeners();
  }

  Future<void> _wipeStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
