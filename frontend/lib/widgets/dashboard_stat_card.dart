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
    this.subtitle,
    this.onIconTap,
    this.actionIcon,
    this.actionTooltip,
  });

  final String title;
  final String value;
  final Color background;
  final bool valueFirst;
  final String? subtitle;
  final VoidCallback? onIconTap;
  final IconData? actionIcon;
  final String? actionTooltip;

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

    final icon = actionIcon != null
        ? Icon(actionIcon, size: 20, color: AppTheme.soft)
        : Image.asset(
            AppAssets.statIcon,
            width: 22,
            height: 22,
            fit: BoxFit.cover,
          );

    Widget iconBox = SizedBox(
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
          icon,
        ],
      ),
    );

    if (onIconTap != null) {
      iconBox = Tooltip(
        message: actionTooltip ?? 'اختيار الشهر',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onIconTap,
            borderRadius: BorderRadius.circular(14),
            child: iconBox,
          ),
        ),
      );
    }

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          iconBox,
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.soft,
                          ),
                        ),
                      ],
                    ]
                  : [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.soft,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
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
