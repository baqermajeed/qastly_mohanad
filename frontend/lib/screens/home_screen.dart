import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/assets.dart';
import '../core/governorates.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/customers_table.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/home_header.dart';
import '../widgets/promo_banner.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.auth});

  final ApiService api;
  final AuthSession auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _DateFilter { all, today, week, month, custom }

class _HomeScreenState extends State<HomeScreen> {
  static const _pageSize = 20;

  DashboardStats? _stats;
  PageResult<Customer> _customers = PageResult.empty(pageSize: _pageSize);
  bool _loading = true;
  bool _tableLoading = false;
  bool _loadingMore = false;
  String? _error;
  final _searchController = TextEditingController();
  String _query = '';
  String? _governorateFilter;
  CustomerStatus? _statusFilter;
  _DateFilter _dateFilter = _DateFilter.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Timer? _searchDebounce;

  bool get _hasMoreCustomers => _customers.hasNext;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) get _activeDateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
      case _DateFilter.all:
        return (null, null);
      case _DateFilter.today:
        return (today, today);
      case _DateFilter.week:
        return (today.subtract(const Duration(days: 6)), today);
      case _DateFilter.month:
        return (DateTime(today.year, today.month, 1), today);
      case _DateFilter.custom:
        return (_dateFrom, _dateTo);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final showFullLoading = !silent || _stats == null;
    if (showFullLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final statsFuture = widget.api.getDashboard();
      final tableFuture = _fetchCustomers(page: 1);
      final data = await statsFuture;
      final page = await tableFuture;
      if (!mounted) return;
      setState(() {
        _stats = data.stats;
        _customers = page;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && showFullLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<PageResult<Customer>> _fetchCustomers({required int page}) {
    final range = _activeDateRange;
    return widget.api.getCustomers(
      q: _query,
      governorate: _governorateFilter,
      status: _statusFilter,
      dateFrom: range.$1,
      dateTo: range.$2,
      page: page,
      pageSize: _pageSize,
    );
  }

  Future<void> _reloadTable({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _tableLoading = true);
    }
    try {
      final result = await _fetchCustomers(page: 1);
      if (!mounted) return;
      setState(() {
        _customers = result;
        _loadingMore = false;
        _tableLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tableLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_loadingMore || _tableLoading || !_hasMoreCustomers) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetchCustomers(page: _customers.page + 1);
      if (!mounted) return;
      setState(() {
        _customers = _customers.appended(result);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      if (next == _query) return;
      setState(() => _query = next);
      _reloadTable();
    });
  }

  Future<void> _openAdd() async {
    final changed = await showAddCustomerDialog(
      context,
      api: widget.api,
      user: widget.auth.user,
    );
    if (changed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب الخطة للمدير بانتظار الموافقة'),
        ),
      );
      await _load(silent: true);
    }
  }

  Future<void> _openCustomer(Customer c) async {
    await showCustomerDetailDialog(
      context,
      api: widget.api,
      customerId: c.id,
      isAdmin: false,
    );
    if (!mounted) return;
    await _load(silent: true);
  }

  Future<void> _onDateFilterSelected(_DateFilter value) async {
    if (value == _DateFilter.custom) {
      final range = await _showCustomDateRangeDialog(
        context: context,
        initialFrom: _dateFrom,
        initialTo: _dateTo,
      );
      if (!mounted || range == null) return;
      setState(() {
        _dateFilter = _DateFilter.custom;
        _dateFrom = range.$1;
        _dateTo = range.$2;
      });
      await _reloadTable();
      return;
    }

    setState(() {
      _dateFilter = value;
      _dateFrom = null;
      _dateTo = null;
    });
    await _reloadTable();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < 1440 ? 1440 : constraints.maxWidth,
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSidebar(
                    active: SidebarNav.home,
                    overdueCount: 0,
                    onSelect: (_) {},
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.soft),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_error!, textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: _load,
                                        child: const Text('إعادة المحاولة'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(30, 18, 30, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    HomeHeader(
                                      searchController: _searchController,
                                      customers: _customers.items,
                                      user: widget.auth.user,
                                      onLogout: widget.auth.logout,
                                      onQueryChanged: _onSearchChanged,
                                      onSearch: () {
                                        _searchDebounce?.cancel();
                                        final next =
                                            _searchController.text.trim();
                                        setState(() => _query = next);
                                        _reloadTable();
                                      },
                                      onSelectCustomer: _openCustomer,
                                    ),
                                    const SizedBox(height: 23),
                                    const PromoBanner(),
                                    const SizedBox(height: 26),
                                    _statsSection(),
                                    const SizedBox(height: 27),
                                    _appointmentsHeader(),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: RefreshIndicator(
                                        color: AppTheme.soft,
                                        onRefresh: () => _load(silent: true),
                                        child: Stack(
                                          children: [
                                            CustomersTable(
                                              customers: _customers.items,
                                              onOpen: _openCustomer,
                                              hasMore: _hasMoreCustomers,
                                              loadingMore: _loadingMore,
                                              onLoadMore: _loadMoreCustomers,
                                              total: _customers.total,
                                            ),
                                            if (_tableLoading)
                                              const Positioned.fill(
                                                child: ColoredBox(
                                                  color: Color(0x66F6FCFF),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: AppTheme.soft,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statsSection() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: DashboardStatCard(
            title: 'اجمالي المبالغ',
            value: money(stats.totalAmounts),
            background: AppTheme.cardNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'المبالغ المسددة',
            value: money(stats.paidAmounts),
            background: AppTheme.cardMint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'المبالغ المتبقية',
            value: money(stats.remainingAmounts),
            background: AppTheme.cardGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'عدد الزبائن',
            value: '${stats.totalCustomers} زبون',
            background: AppTheme.cardNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'عمولة المنصة',
            value: money(stats.platformAmounts),
            background: AppTheme.cardMint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'عمولة المصرف',
            value: money(stats.bankAmounts),
            background: AppTheme.cardGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'الخطط النشطة',
            value: '${stats.remainingCount}',
            background: AppTheme.cardTeal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'مستحقاتك هذا الشهر',
            value: money(stats.dueThisMonthAmount),
            background: AppTheme.cardGold,
          ),
        ),
      ],
    );
  }

  Widget _appointmentsHeader() {
    final statusLabelText = switch (_statusFilter) {
      CustomerStatus.pending => 'بانتظار الموافقة',
      CustomerStatus.rejected => 'مرفوضة',
      CustomerStatus.inactive => 'غير نشطة',
      CustomerStatus.active => 'نشطة',
      CustomerStatus.completed => 'مكتملة',
      null => 'حالة الخطة',
    };
    final dateLabel = switch (_dateFilter) {
      _DateFilter.all => 'التاريخ',
      _DateFilter.today => 'اليوم',
      _DateFilter.week => 'هذا الأسبوع',
      _DateFilter.month => 'هذا الشهر',
      _DateFilter.custom
          when _dateFrom != null && _dateTo != null =>
        '${formatDayMonth(_dateFrom!)} - ${formatDayMonth(_dateTo!)}',
      _DateFilter.custom => 'من / إلى',
    };

    return Row(
      children: [
        Text(
          'زبائن التاجر',
          style: AppTheme.text(
            color: AppTheme.basic,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _FilterMenu<String?>(
          width: 130,
          label: _governorateFilter ?? 'المحافظة',
          active: _governorateFilter != null,
          items: [
            const PopupMenuItem<String?>(
              value: null,
              child: Text('الكل'),
            ),
            for (final g in iraqiGovernorates)
              PopupMenuItem<String?>(
                value: g,
                child: Text(g),
              ),
          ],
          onSelected: (v) {
            setState(() => _governorateFilter = v);
            _reloadTable();
          },
        ),
        const SizedBox(width: 15),
        _FilterMenu<CustomerStatus?>(
          width: 145,
          label: statusLabelText,
          active: _statusFilter != null,
          items: const [
            PopupMenuItem<CustomerStatus?>(
              value: null,
              child: Text('الكل'),
            ),
            PopupMenuItem<CustomerStatus?>(
              value: CustomerStatus.pending,
              child: Text('بانتظار الموافقة'),
            ),
            PopupMenuItem<CustomerStatus?>(
              value: CustomerStatus.active,
              child: Text('نشطة'),
            ),
            PopupMenuItem<CustomerStatus?>(
              value: CustomerStatus.inactive,
              child: Text('غير نشطة'),
            ),
            PopupMenuItem<CustomerStatus?>(
              value: CustomerStatus.completed,
              child: Text('مكتملة'),
            ),
            PopupMenuItem<CustomerStatus?>(
              value: CustomerStatus.rejected,
              child: Text('مرفوضة'),
            ),
          ],
          onSelected: (v) {
            setState(() => _statusFilter = v);
            _reloadTable();
          },
        ),
        const SizedBox(width: 15),
        _FilterMenu<_DateFilter>(
          width: _dateFilter == _DateFilter.custom ? 210 : 139,
          label: dateLabel,
          active: _dateFilter != _DateFilter.all,
          items: const [
            PopupMenuItem<_DateFilter>(
              value: _DateFilter.all,
              child: Text('الكل'),
            ),
            PopupMenuItem<_DateFilter>(
              value: _DateFilter.today,
              child: Text('اليوم'),
            ),
            PopupMenuItem<_DateFilter>(
              value: _DateFilter.week,
              child: Text('هذا الأسبوع'),
            ),
            PopupMenuItem<_DateFilter>(
              value: _DateFilter.month,
              child: Text('هذا الشهر'),
            ),
            PopupMenuItem<_DateFilter>(
              value: _DateFilter.custom,
              child: Text('من / إلى'),
            ),
          ],
          onSelected: _onDateFilterSelected,
        ),
        const SizedBox(width: 15),
        Material(
          color: AppTheme.soft,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _openAdd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 10, right: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.softGlow,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Text(
                      'إضافة زبون جديد',
                      style: AppTheme.text(
                        color: AppTheme.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SvgPicture.asset(
                      AppAssets.plus,
                      width: 23,
                      height: 23,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<(DateTime, DateTime)?> _showCustomDateRangeDialog({
  required BuildContext context,
  DateTime? initialFrom,
  DateTime? initialTo,
}) {
  return showAppDialog<(DateTime, DateTime)>(
    context: context,
    builder: (ctx) => _CustomDateRangeDialog(
      initialFrom: initialFrom,
      initialTo: initialTo,
    ),
  );
}

class _CustomDateRangeDialog extends StatefulWidget {
  const _CustomDateRangeDialog({
    this.initialFrom,
    this.initialTo,
  });

  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _from;
  late DateTime _to;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _from = widget.initialFrom ?? today.subtract(const Duration(days: 7));
    _to = widget.initialTo ?? today;
    if (_from.isAfter(_to)) {
      _from = _to;
    }
  }

  Future<void> _pick({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.soft,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.basic,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _error = null;
      if (isFrom) {
        _from = day;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = day;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  void _apply() {
    if (_from.isAfter(_to)) {
      setState(() => _error = 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية');
      return;
    }
    Navigator.of(context).pop((_from, _to));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'فلترة زمنية',
                  textAlign: TextAlign.center,
                  style: AppTheme.text(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر تاريخ البداية والنهاية حسب تسجيل الزبون',
                  textAlign: TextAlign.center,
                  style: AppTheme.text(
                    fontSize: 13,
                    color: AppTheme.basic.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DateFieldButton(
                        label: 'من',
                        value: formatDayMonth(_from),
                        onTap: () => _pick(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateFieldButton(
                        label: 'إلى',
                        value: formatDayMonth(_to),
                        onTap: () => _pick(isFrom: false),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      color: AppTheme.late,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.basic,
                          side: const BorderSide(color: Color(0xFFD5E4EC)),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _apply,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.soft,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3FAFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD7E8F1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.text(
                fontSize: 12,
                color: AppTheme.basic.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTheme.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppTheme.soft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.items,
    required this.onSelected,
    this.width = 120,
    this.active = false,
  });

  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final double width;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      offset: const Offset(0, 8),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        width: width,
        height: 50,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF6FB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? Border.all(color: const Color(0xFFB7D7EA))
              : null,
          boxShadow: AppTheme.softGlow,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.angleDown,
                width: 23,
                height: 23,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.text(
                    color: active ? AppTheme.soft : AppTheme.basic,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
