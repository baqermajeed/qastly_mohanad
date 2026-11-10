import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/customer.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final CustomerStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CustomerStatus.pending => const Color(0xFFC38508),
      CustomerStatus.rejected => AppTheme.late,
      CustomerStatus.inactive => AppTheme.late,
      CustomerStatus.active => AppTheme.paid,
      CustomerStatus.completed => AppTheme.completed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
