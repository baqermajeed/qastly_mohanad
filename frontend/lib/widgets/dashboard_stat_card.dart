import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/theme.dart';

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.background,
    this.valueFirst = false,
  });

  final String title;
  final String value;
  final Color background;
  final bool valueFirst;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTheme.text(
      color: AppTheme.basic,
      fontSize: 13,
      fontWeight: valueFirst ? FontWeight.w600 : FontWeight.w700,
    );
    final valueStyle = AppTheme.text(
      color: AppTheme.basic,
      fontSize: 15,
      fontWeight: valueFirst ? FontWeight.w700 : FontWeight.w600,
    );

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.soft.withValues(alpha: 0.23),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Image.asset(
                  AppAssets.statIcon,
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: valueFirst
                  ? [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: valueStyle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: 0.7,
                        child: Text(
                          title,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: valueStyle,
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
