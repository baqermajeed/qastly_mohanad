import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/connectivity_monitor.dart';

class NetworkStatusHost extends StatelessWidget {
  const NetworkStatusHost({
    super.key,
    required this.monitor,
    required this.child,
  });

  final ConnectivityMonitor monitor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        return Column(
          children: [
            NetworkStatusBanner(state: monitor.state),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key, required this.state});

  final NetworkBannerState state;

  @override
  Widget build(BuildContext context) {
    final visible = state != NetworkBannerState.none;
    final offline = state == NetworkBannerState.offline;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: visible
            ? Material(
                color: offline ? const Color(0xFFB42318) : AppTheme.basic,
                elevation: 2,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          offline
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            offline
                                ? 'لا يوجد اتصال بالإنترنت'
                                : 'تعذر الاتصال بالخادم، تحقق من الشبكة وحاول مرة أخرى',
                            style: AppTheme.text(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}
