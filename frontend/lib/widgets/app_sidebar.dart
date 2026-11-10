import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/theme.dart';

enum SidebarNav { home, customers, pay, overdue }

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.active,
    required this.onSelect,
    this.overdueCount = 0,
    this.isAdmin = false,
  });

  final SidebarNav active;
  final ValueChanged<SidebarNav> onSelect;
  final int overdueCount;
  final bool isAdmin;

  static const _neon = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.sidebarBg,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // تدرج خفيف لقراءة أوضح فوق الموجات
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66001A33),
                  Color(0x33001A33),
                  Color(0x66001A33),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
            child: Column(
              children: [
                _buildBrand(),
                const SizedBox(height: 36),
                _buildSectionTitle(),
                const SizedBox(height: 18),
                _NavItem(
                  label: isAdmin ? 'التجار' : 'الصفحة الرئيسية',
                  icon: AppAssets.navHome,
                  selected: active == SidebarNav.home,
                  onTap: () => onSelect(SidebarNav.home),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 14),
                  _NavItem(
                    label: 'كل الزبائن',
                    icon: AppAssets.navOverdue,
                    selected: active == SidebarNav.customers,
                    onTap: () => onSelect(SidebarNav.customers),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              AppAssets.appIcon,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Dashboard System',
          textAlign: TextAlign.center,
          style: AppTheme.text(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'نظام إدارة الأقساط',
          textAlign: TextAlign.center,
          style: AppTheme.text(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _neon.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'القائمة الرئيسية',
          textAlign: TextAlign.right,
          style: AppTheme.text(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  static const _neon = Color(0xFF00D4FF);
  static const _glassBorder = Color(0x665DB8E8);
  static const _activeText = Color(0xFF0A2F4A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF4FCFF),
                      Color(0xFFD7F0FB),
                      Color(0xFFBFE6F6),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
            border: Border.all(
              color: selected ? Colors.white.withValues(alpha: 0.9) : _glassBorder,
              width: selected ? 1.2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  right: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: _neon,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _neon.withValues(alpha: 0.9),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // LTR صريح: يمين = أيقونة + نص | يسار = شارة
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    if (badgeCount > 0) ...[
                      _Badge(count: badgeCount),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTheme.text(
                          color: selected ? _activeText : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _NavIcon(path: icon),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTheme.text(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
