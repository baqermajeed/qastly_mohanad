import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
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

enum _DateFilter { all, today, week, month }

class _HomeScreenState extends State<HomeScreen> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _query = '';
  String? _governorateFilter;
  CustomerStatus? _statusFilter;
  _DateFilter _dateFilter = _DateFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // التحميل الكامل فقط بأول فتح؛ بعد الدايلوكات نحدّث بصمت
    // حتى لا تختفي الصفحة وتظهر ومضة سوداء مع الحاجز الداكن.
    final showFullLoading = !silent || _data == null;
    if (showFullLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.api.getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  List<String> get _governorateOptions {
    final set = <String>{};
    for (final c in _data?.customers ?? const <Customer>[]) {
      if (c.governorate.trim().isNotEmpty) set.add(c.governorate.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _matchesDate(Customer c) {
    final d = DateTime(
      c.registrationDate.year,
      c.registrationDate.month,
      c.registrationDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
      case _DateFilter.all:
        return true;
      case _DateFilter.today:
        return d == today;
      case _DateFilter.week:
        final start = today.subtract(const Duration(days: 6));
        return !d.isBefore(start) && !d.isAfter(today);
      case _DateFilter.month:
        return d.year == today.year && d.month == today.month;
    }
  }

  List<Customer> get _filteredCustomers {
    final q = _query.trim().toLowerCase();
    return (_data?.customers ?? const <Customer>[])
        .where((c) {
          if (_governorateFilter != null &&
              c.governorate.trim() != _governorateFilter) {
            return false;
          }
          if (_statusFilter != null && c.status != _statusFilter) {
            return false;
          }
          if (!_matchesDate(c)) return false;
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.governorate.toLowerCase().contains(q);
        })
        .toList();
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
                                      customers: _data?.customers ?? [],
                                      user: widget.auth.user,
                                      onLogout: widget.auth.logout,
                                      onQueryChanged: (q) => setState(
                                        () => _query = q,
                                      ),
                                      onSearch: () => setState(
                                        () => _query = _searchController.text,
                                      ),
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
                                        child: CustomersTable(
                                          customers: _filteredCustomers,
                                          onOpen: _openCustomer,
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
    final stats = _data?.stats;
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
            for (final g in _governorateOptions)
              PopupMenuItem<String?>(
                value: g,
                child: Text(g),
              ),
          ],
          onSelected: (v) => setState(() => _governorateFilter = v),
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
          onSelected: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(width: 15),
        _FilterMenu<_DateFilter>(
          width: 139,
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
          ],
          onSelected: (v) => setState(() => _dateFilter = v),
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
