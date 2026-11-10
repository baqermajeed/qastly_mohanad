import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkBannerState {
  none,
  offline,
  serverUnreachable,
}

/// مراقبة مركزية للاتصال: انقطاع الإنترنت أو تعذر الوصول للخادم.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;

  bool _hasLink = true;
  bool _serverDown = false;
  NetworkBannerState _state = NetworkBannerState.none;
  bool _started = false;

  NetworkBannerState get state => _state;
  bool get hasIssue => _state != NetworkBannerState.none;
  bool get isOffline => _state == NetworkBannerState.offline;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      _setLink(_hasNetworkLink(initial), immediate: true);
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) => _setLink(_hasNetworkLink(results)),
      );
    } catch (_) {
      // في الاختبارات أو غياب قناة المنصة نفترض وجود اتصال.
      _setLink(true, immediate: true);
    }
  }

  void markServerUnreachable() {
    if (!_hasLink || _serverDown) return;
    _serverDown = true;
    _syncState();
  }

  void markServerReachable() {
    if (!_serverDown) return;
    _serverDown = false;
    _syncState();
  }

  void _setLink(bool hasLink, {bool immediate = false}) {
    void apply() {
      if (_hasLink == hasLink) return;
      _hasLink = hasLink;
      if (!hasLink) {
        // أولوية لانقطاع الشبكة؛ نُبقي حالة السيرفر كما هي حتى يعود الرابط.
      } else if (_serverDown) {
        // عند عودة الشبكة نخفف تنبيه السيرفر حتى يُؤكد الطلب التالي.
        _serverDown = false;
      }
      _syncState();
    }

    _debounce?.cancel();
    if (immediate) {
      apply();
      return;
    }
    // منع الوميض عند تذبذب الشبكة القصير.
    _debounce = Timer(const Duration(milliseconds: 450), apply);
  }

  void _syncState() {
    final next = !_hasLink
        ? NetworkBannerState.offline
        : (_serverDown
            ? NetworkBannerState.serverUnreachable
            : NetworkBannerState.none);
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  static bool _hasNetworkLink(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
