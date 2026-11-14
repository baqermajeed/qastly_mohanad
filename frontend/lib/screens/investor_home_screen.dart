import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/investor.dart';
import '../models/page_result.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/format.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/home_header.dart';
import '../widgets/promo_banner.dart';
import 'investor_detail_screen.dart';

class InvestorHomeScreen extends StatefulWidget {
  const InvestorHomeScreen({super.key, required this.api, required this.auth});

  final ApiService api;
  final AuthSession auth;

  @override
  State<InvestorHomeScreen> createState() => _InvestorHomeScreenState();
}

class _InvestorHomeScreenState extends State<InvestorHomeScreen> {
  Investor? _investor;
  PageResult<Investment> _investments = PageResult.empty(pageSize: 50);
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  late DateTime _dueMonth;

  DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _headers = <(int, String)>[
    (4, '#'),
    (10, 'المبلغ'),
    (7, 'الفائدة'),
    (10, 'بعد الفائدة'),
    (9, 'القسط الشهري'),
    (10, 'المستلم'),
    (10, 'المتبقي'),
    (7, 'الأشهر'),
    (8, 'البداية'),
    (8, 'أول قسط'),
    (8, 'آخر قسط'),
    (7, 'الحالة'),
  ];

  @override
  void initState() {
    super.initState();
    _dueMonth = _currentMonth;
    _load();
  }

  bool get _isCurrentDueMonth =>
      _dueMonth.year == _currentMonth.year &&
      _dueMonth.month == _currentMonth.month;

  double get _dueForSelectedMonth {
    var total = 0.0;
    for (final item in _investments.items) {
      if (item.status != InvestmentStatus.active) continue;
      total += installmentDueInMonth(
        firstDue: item.firstDueDate,
        monthsCount: item.monthsCount,
        monthlyPayment: item.monthlyPayout,
        financedAmount: item.totalWithInterest,
        month: _dueMonth,
      );
    }
    return double.parse(total.toStringAsFixed(2));
  }

  Future<void> _pickDueMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 8, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'اختر الشهر',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      fieldLabelText: 'الشهر',
    );
    if (picked == null || !mounted) return;
    setState(() => _dueMonth = DateTime(picked.year, picked.month));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final id = widget.auth.user?.id;
    if (id == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final investor = await widget.api.getInvestor(id);
      final investments = await widget.api.getInvestments(
        investorId: id,
        page: 1,
        pageSize: 50,
      );
      if (!mounted) return;
      setState(() {
        _investor = investor;
        _investments = investments;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openInvestment(Investment item) async {
    final investor = _investor;
    if (investor == null) return;
    await showInvestorDetailDialog(
      context,
      api: widget.api,
      investor: investor,
      isAdmin: false,
      initialInvestmentId: item.id,
    );
    if (!mounted) return;
    await _load(silent: true);
  }

  Color _statusColor(InvestmentStatus status) {
    return switch (status) {
      InvestmentStatus.active => AppTheme.paid,
      InvestmentStatus.completed => AppTheme.completed,
      InvestmentStatus.cancelled => AppTheme.late,
    };
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
                            child: CircularProgressIndicator(
                              color: AppTheme.soft,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                      ),
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
                                padding: const EdgeInsets.fromLTRB(
                                  30,
                                  18,
                                  30,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    HomeHeader(
                                      searchController: _searchController,
                                      customers: const [],
                                      user: widget.auth.user,
                                      onLogout: widget.auth.logout,
                                      onQueryChanged: (_) {},
                                      onSearch: () {},
                                      onSelectCustomer: (_) {},
                                    ),
                                    const SizedBox(height: 23),
                                    const PromoBanner(
                                      title: 'مرحبا بك في نظام قسطلي💸',
                                      subtitle:
                                          'عقودك الاستثمارية مستقلة، وأقساطك تُحتسب حسب كل عقد',
                                    ),
                                    const SizedBox(height: 26),
                                    _stats(),
                                    const SizedBox(height: 22),
                                    Row(
                                      children: [
                                        Text(
                                          'عقودي الاستثمارية',
                                          style: AppTheme.text(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.soft
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_investments.items.length}',
                                            style: AppTheme.text(
                                              color: AppTheme.soft,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: RefreshIndicator(
                                        color: AppTheme.soft,
                                        onRefresh: () => _load(silent: true),
                                        child: SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: _contractsTable(),
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

  Widget _stats() {
    final inv = _investor;
    if (inv == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                title: 'أصل الرصيد',
                value: money(inv.principalTotal),
                background: AppTheme.cardNavy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardStatCard(
                title: 'بعد الفائدة',
                value: money(inv.totalWithInterest),
                background: AppTheme.cardTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardStatCard(
                title: 'مستحقاتك هذا الشهر',
                subtitle: _isCurrentDueMonth
                    ? null
                    : '${_dueMonth.month.toString().padLeft(2, '0')}/${_dueMonth.year}',
                value: money(
                  _isCurrentDueMonth
                      ? (_investments.items.isEmpty
                          ? inv.dueThisMonthAmount
                          : _dueForSelectedMonth)
                      : _dueForSelectedMonth,
                ),
                background: AppTheme.cardMint,
                actionIcon: Icons.calendar_month_rounded,
                actionTooltip: 'اختيار شهر',
                onIconTap: _pickDueMonth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                title: 'المبالغ المستلمة (كل العقود)',
                value: money(inv.paidAmount),
                background: AppTheme.cardTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardStatCard(
                title: 'المبالغ المتبقية (كل العقود)',
                value: money(inv.remainingAmount),
                background: AppTheme.cardGold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _contractsTable() {
    final items = _investments.items;
    return Column(
      children: [
        Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softGlow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                for (final h in _headers)
                  Expanded(
                    flex: h.$1,
                    child: Text(
                      h.$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.text(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softGlow,
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'لا توجد عقود استثمار بعد. عند إضافة عقد من الإدارة سيظهر هنا.',
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      color: AppTheme.basic.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _contractRow(index: i + 1, item: items[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _contractRow({required int index, required Investment item}) {
    final statusColor = _statusColor(item.status);
    final lastDue = lastDueDate(
      firstDue: item.firstDueDate,
      monthsCount: item.monthsCount,
    );
    return Material(
      color: const Color(0xFFF8FCFE),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openInvestment(item),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _fieldBorder),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                _cell(4, Text('$index', textAlign: TextAlign.center)),
                _cell(
                  10,
                  Text(
                    money(item.principal),
                    textAlign: TextAlign.center,
                    style: AppTheme.text(fontWeight: FontWeight.w800),
                  ),
                ),
                _cell(
                  7,
                  Text(
                    '${item.interestPercent}%',
                    textAlign: TextAlign.center,
                    style: AppTheme.text(fontWeight: FontWeight.w700),
                  ),
                ),
                _cell(
                  10,
                  Text(
                    money(item.totalWithInterest),
                    textAlign: TextAlign.center,
                    style: AppTheme.text(fontWeight: FontWeight.w700),
                  ),
                ),
                _cell(
                  9,
                  Text(
                    money(item.monthlyPayout),
                    textAlign: TextAlign.center,
                    style: AppTheme.text(fontWeight: FontWeight.w700),
                  ),
                ),
                _cell(
                  10,
                  Text(
                    money(item.paidAmount),
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.completed,
                    ),
                  ),
                ),
                _cell(
                  10,
                  Text(
                    money(item.remainingAmount),
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC38508),
                    ),
                  ),
                ),
                _cell(
                  7,
                  Text(
                    '${item.remainingMonths}/${item.monthsCount}',
                    textAlign: TextAlign.center,
                  ),
                ),
                _cell(
                  8,
                  Text(formatDate(item.startDate), textAlign: TextAlign.center),
                ),
                _cell(
                  8,
                  Text(
                    formatDate(item.firstDueDate),
                    textAlign: TextAlign.center,
                  ),
                ),
                _cell(
                  8,
                  Text(
                    lastDue == null ? '—' : formatDate(lastDue),
                    textAlign: TextAlign.center,
                  ),
                ),
                _cell(
                  7,
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        investmentStatusLabel(item.status),
                        style: AppTheme.text(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(int flex, Widget child) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: child,
      ),
    );
  }
}
