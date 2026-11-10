import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../models/user.dart';
import 'appointment_status_chip.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.searchController,
    this.customers = const [],
    this.user,
    this.onLogout,
    this.onSearch,
    this.onQueryChanged,
    this.onSelectCustomer,
  });

  final TextEditingController searchController;
  final List<Customer> customers;
  final AppUser? user;
  final Future<void> Function()? onLogout;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<Customer>? onSelectCustomer;

  static const _searchShadow = [
    BoxShadow(
      color: Color(0x3B069BAF),
      blurRadius: 5,
      offset: Offset.zero,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SearchBar(
            controller: searchController,
            customers: customers,
            onSearch: onSearch,
            onQueryChanged: onQueryChanged,
            onSelectCustomer: onSelectCustomer,
            shadow: _searchShadow,
          ),
        ),
        const SizedBox(width: 16),
        _UserAccountChip(
          shadow: _searchShadow,
          user: user,
          onLogout: onLogout,
        ),
        const SizedBox(width: 10),
        _IconChip(
          shadow: _searchShadow,
          child: SvgPicture.asset(AppAssets.bell, width: 24, height: 24),
        ),
      ],
    );
  }
}

class _UserAccountChip extends StatelessWidget {
  const _UserAccountChip({
    required this.shadow,
    this.user,
    this.onLogout,
  });

  final List<BoxShadow> shadow;
  final AppUser? user;
  final Future<void> Function()? onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'تسجيل الخروج',
              style: AppTheme.text(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: Text(
              'هل تريد تسجيل الخروج من النظام؟',
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'إلغاء',
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.late,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'تسجيل الخروج',
                  style: AppTheme.text(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && onLogout != null) {
      await onLogout!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountName = user?.fullName ?? 'مستخدم';
    final username = user?.isAdmin == true
        ? 'مدير المنصة'
        : (user?.username ?? 'تاجر');

    return PopupMenuButton<String>(
      tooltip: 'حساب المستخدم',
      offset: const Offset(0, 12),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 8,
      onSelected: (value) {
        if (value == 'logout') _confirmLogout(context);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 20, color: AppTheme.late),
              const SizedBox(width: 10),
              Text(
                'تسجيل الخروج',
                style: AppTheme.text(
                  color: AppTheme.late,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppAssets.angleDownDark,
                      width: 12,
                      height: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      accountName,
                      style: AppTheme.text(
                        color: AppTheme.basic,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6.5),
            ClipOval(
              child: Image.asset(
                AppAssets.userProfileAvatar,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.customers,
    required this.shadow,
    this.onSearch,
    this.onQueryChanged,
    this.onSelectCustomer,
  });

  final TextEditingController controller;
  final List<Customer> customers;
  final List<BoxShadow> shadow;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<Customer>? onSelectCustomer;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text == _query) return;
    _query = text;
    widget.onQueryChanged?.call(text);
    _syncOverlay();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _syncOverlay();
    } else {
      // Delay so tap on suggestion can register first.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  List<Customer> get _suggestions {
    final q = _query.trim().toLowerCase();
    final all = widget.customers;
    if (q.isEmpty) return all.take(8).toList();
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.governorate.toLowerCase().contains(q),
        )
        .take(8)
        .toList();
  }

  void _syncOverlay() {
    if (!_focusNode.hasFocus && _query.trim().isEmpty) {
      _removeOverlay();
      return;
    }
    if (!_focusNode.hasFocus && _overlay == null) return;

    if (_overlay == null) {
      _overlay = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context).insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _applySearch() {
    widget.onSearch?.call();
    _syncOverlay();
  }

  void _select(Customer c) {
    widget.controller.text = c.name;
    _query = c.name;
    widget.onQueryChanged?.call(c.name);
    widget.onSearch?.call();
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelectCustomer?.call(c);
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    String firstChar(String s) => String.fromCharCodes(s.runes.take(1));
    if (parts.length == 1) return firstChar(parts.first);
    return '${firstChar(parts.first)}${firstChar(parts[1])}';
  }

  Widget _buildOverlay(BuildContext context) {
    final suggestions = _suggestions;
    final width = _layerLink.leaderSize?.width ?? 400;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 66),
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3F0F7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33002E45),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          'اقتراحات المرضى',
                          style: AppTheme.text(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.person_search_rounded,
                          size: 18,
                          color: AppTheme.soft,
                        ),
                        const Spacer(),
                        Text(
                          '${suggestions.length} نتيجة',
                          style: AppTheme.text(
                            color: AppTheme.basic.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8F1F6)),
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 34,
                            color: AppTheme.basic.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد نتائج',
                            style: AppTheme.text(
                              color: AppTheme.basic.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final c = suggestions[i];
                          return Material(
                            color: const Color(0xFFF4F8FB),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _select(c),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                          colors: [
                                            Color(0xFF1E88C8),
                                            Color(0xFF069BAF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _initials(c.name),
                                        style: AppTheme.text(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTheme.text(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${c.phone}  •  ${c.governorate}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTheme.text(
                                              color: AppTheme.basic
                                                  .withValues(alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AppointmentStatusChip(status: c.status),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        height: 58,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: widget.shadow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 70),
                alignment: Alignment.centerRight,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.right,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppTheme.soft,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: 'ابحث عن زبون',
                    hintStyle: AppTheme.text(
                      color: AppTheme.basic.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _syncOverlay,
                  onChanged: (_) => _syncOverlay(),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                  _applySearch();
                },
                child: Container(
                  width: 56,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.soft,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: widget.shadow,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    AppAssets.search,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.child, required this.shadow});

  final Widget child;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow,
      ),
      child: Center(child: child),
    );
  }
}
