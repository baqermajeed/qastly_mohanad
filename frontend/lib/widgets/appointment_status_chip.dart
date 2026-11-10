import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/customer.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final CustomerStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CustomerStatus.completed => ('مكتملة', AppTheme.statusCompleted),
      CustomerStatus.active => ('نشطة', AppTheme.statusWaiting),
      CustomerStatus.inactive => ('غير نشطة', AppTheme.statusCanceled),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Opacity(
        opacity: 0.9,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.text(
            color: AppTheme.basic,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
