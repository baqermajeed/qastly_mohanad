import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../models/merchant.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/format.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/customers_table.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/home_header.dart';
import 'add_merchant_screen.dart';
import 'customer_detail_screen.dart';
import 'merchant_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.api, required this.auth});

  final ApiService api;
  final AuthSession auth;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _query = '';
  SidebarNav _active = SidebarNav.home;

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
      if (mounted && showFullLoading) setState(() => _loading = false);
    }
  }

  Future<void> _openAddMerchant({Merchant? merchant}) async {
    final changed = await showAddMerchantDialog(
      context,
      api: widget.api,
      merchant: merchant,
    );
    if (changed == true) await _load(silent: true);
  }

  Future<void> _openCustomer(Customer c) async {
    await showCustomerDetailDialog(
      context,
      api: widget.api,
      customerId: c.id,
      isAdmin: true,
    );
    if (!mounted) return;
    await _load(silent: true);
  }

  Future<void> _openMerchant(Merchant m) async {
    final changed = await showMerchantDetailDialog(
      context,
      api: widget.api,
      merchant: m,
    );
    if (!mounted) return;
    if (changed == true) await _load(silent: true);
  }

  List<Merchant> get _filteredMerchants {
    final q = _query.trim().toLowerCase();
    return (_data?.merchants ?? const <Merchant>[])
        .where((m) {
          if (q.isEmpty) return true;
          return m.fullName.toLowerCase().contains(q) ||
              m.username.toLowerCase().contains(q) ||
              m.phone.contains(q) ||
              m.governorate.toLowerCase().contains(q);
        })
        .toList();
  }

  List<Customer> get _filteredCustomers {
    final q = _query.trim().toLowerCase();
    return (_data?.customers ?? const <Customer>[])
        .where((c) {
          if (c.status == CustomerStatus.pending) return false;
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              (c.merchantName ?? '').toLowerCase().contains(q);
        })
        .toList();
  }

  List<Customer> get _pendingCustomers {
    final q = _query.trim().toLowerCase();
    return (_data?.customers ?? const <Customer>[])
        .where((c) => c.status == CustomerStatus.pending)
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              (c.merchantName ?? '').toLowerCase().contains(q);
        })
        .toList();
  }

  Future<void> _approve(Customer c) async {
    try {
      await widget.api.approveCustomer(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم اعتماد خطة ${c.name}')),
      );
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _reject(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Text('رفض طلب خطة الزبون ${c.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.late),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.rejectCustomer(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رفض طلب ${c.name}')),
      );
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
                    active: _active,
                    isAdmin: true,
                    overdueCount: 0,
                    pendingCount: _data?.stats.pendingCount ?? 0,
                    onSelect: (nav) => setState(() => _active = nav),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.soft),
                          )
                        : _error != null
                            ? Center(
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
                                      onQueryChanged: (q) =>
                                          setState(() => _query = q),
                                      onSearch: () => setState(
                                        () => _query = _searchController.text,
                                      ),
                                      onSelectCustomer: _openCustomer,
                                    ),
                                    const SizedBox(height: 22),
                                    _statsSection(),
                                    const SizedBox(height: 22),
                                    _sectionHeader(),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: RefreshIndicator(
                                        color: AppTheme.soft,
                                        onRefresh: () => _load(silent: true),
                                        child: switch (_active) {
                                          SidebarNav.customers => CustomersTable(
                                              customers: _filteredCustomers,
                                              onOpen: _openCustomer,
                                              showMerchant: true,
                                            ),
                                          SidebarNav.pending => _PendingPlansTable(
                                              customers: _pendingCustomers,
                                              onOpen: _openCustomer,
                                              onApprove: _approve,
                                              onReject: _reject,
                                            ),
                                          _ => _MerchantsTable(
                                              merchants: _filteredMerchants,
                                              onEdit: (m) =>
                                                  _openAddMerchant(merchant: m),
                                              onOpen: _openMerchant,
                                            ),
                                        },
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
            title: 'عدد التجار',
            value: '${stats.merchantsCount}',
            background: AppTheme.cardNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'عدد الزبائن',
            value: '${stats.totalCustomers}',
            background: AppTheme.cardTeal,
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
            title: 'إجمالي الخطط',
            value: money(stats.totalAmounts),
            background: AppTheme.cardNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'المتبقي على الزبائن',
            value: money(stats.remainingAmounts),
            background: AppTheme.cardGold,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader() {
    final title = switch (_active) {
      SidebarNav.customers => 'زبائن التجار',
      SidebarNav.pending => 'طلبات خطط بانتظار الموافقة',
      _ => 'التجار المشتركين',
    };
    final showAddMerchant = _active == SidebarNav.home;
    return Row(
      children: [
        Text(
          title,
          style: AppTheme.text(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        if (_active == SidebarNav.pending) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC38508).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_pendingCustomers.length}',
              style: AppTheme.text(
                color: const Color(0xFFC38508),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (showAddMerchant)
          Material(
            color: AppTheme.soft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _openAddMerchant,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'إضافة تاجر',
                      style: AppTheme.text(
                        color: AppTheme.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SvgPicture.asset(AppAssets.plus, width: 23, height: 23),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MerchantsTable extends StatelessWidget {
  const _MerchantsTable({
    required this.merchants,
    required this.onEdit,
    required this.onOpen,
  });

  final List<Merchant> merchants;
  final ValueChanged<Merchant> onEdit;
  final ValueChanged<Merchant> onOpen;

  static const _headers = <(int, String)>[
    (5, '#'),
    (8, ''),
    (14, 'اسم التاجر'),
    (12, 'رقم هاتف'),
    (10, 'محافظة'),
    (10, 'المستخدم'),
    (9, 'نسبة المصرف'),
    (9, 'نسبة المنصة'),
    (8, 'الزبائن'),
    (11, 'عمولة المنصة'),
    (12, 'واتساب'),
    (10, 'تعديل'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softGlow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        color: AppTheme.basic,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softGlow,
            ),
            child: merchants.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          'لا يوجد تجار بعد — أضف أول تاجر من الزر أعلاه',
                          style: AppTheme.text(
                            color: AppTheme.basic.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: merchants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _MerchantRow(
                      index: i + 1,
                      merchant: merchants[i],
                      onEdit: () => onEdit(merchants[i]),
                      onOpen: () => onOpen(merchants[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.index,
    required this.merchant,
    required this.onEdit,
    required this.onOpen,
  });

  final int index;
  final Merchant merchant;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  Future<void> _openWhatsApp() async {
    final url = whatsappUrl(merchant.phone);
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cellStyle = AppTheme.text(
      color: AppTheme.basic,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                _cell(
                  flex: 5,
                  child: Opacity(
                    opacity: 0.4,
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      textAlign: TextAlign.center,
                      style: AppTheme.text(
                        color: AppTheme.basic,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _cell(
                  flex: 8,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.userAvatar,
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
                _cell(
                  flex: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          merchant.fullName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cellStyle,
                        ),
                      ),
                      if (!merchant.dueConfirmedThisMonth &&
                          merchant.dueThisMonthAmount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE53935).withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            'غير مسدد',
                            style: AppTheme.text(
                              color: const Color(0xFFE53935),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _cell(
                  flex: 12,
                  child: Text(
                    merchant.phone.isEmpty ? '—' : merchant.phone,
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      color: AppTheme.phone,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.phone,
                    ),
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    merchant.governorate.isEmpty ? '—' : merchant.governorate,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    merchant.username,
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 9,
                  child: Text(
                    '${merchant.bankPercent}%',
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 9,
                  child: Text(
                    '${merchant.platformPercent}%',
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 8,
                  child: Text(
                    '${merchant.customersCount}',
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 11,
                  child: Text(
                    money(merchant.platformAmounts),
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 12,
                  child: Center(
                    child: SizedBox(
                      height: 34,
                      child: FilledButton.icon(
                        onPressed:
                            merchant.phone.isEmpty ? null : _openWhatsApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF25D366).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 14),
                        label: Text(
                          'واتساب',
                          style: AppTheme.text(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Center(
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.soft,
                          side: const BorderSide(color: Color(0xFFB7D7EA)),
                          backgroundColor: const Color(0xFFEAF6FB),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'تعديل',
                          style: AppTheme.text(
                            color: AppTheme.soft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _cell({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: child,
      ),
    );
  }
}

class _PendingPlansTable extends StatelessWidget {
  const _PendingPlansTable({
    required this.customers,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onOpen;
  final ValueChanged<Customer> onApprove;
  final ValueChanged<Customer> onReject;

  static const _headers = <(int, String)>[
    (4, '#'),
    (14, 'الزبون'),
    (12, 'التاجر'),
    (11, 'الهاتف'),
    (10, 'المحافظة'),
    (11, 'المبلغ'),
    (8, 'الأشهر'),
    (11, 'القسط الشهري'),
    (19, 'الإجراء'),
  ];

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'لا توجد طلبات بانتظار الموافقة',
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.55),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          height: 56,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final h in _headers)
                Expanded(
                  flex: h.$1,
                  child: Text(
                    h.$2,
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final c = customers[index];
              final cellStyle = AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              );
              return Material(
                color: const Color(0xFFC38508).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onOpen(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _pCell(
                          flex: 4,
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 14,
                          child: Text(
                            c.name,
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 12,
                          child: Text(
                            c.merchantName ?? '—',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 11,
                          child: Text(
                            c.phone,
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 10,
                          child: Text(
                            c.governorate,
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 11,
                          child: Text(
                            money(c.totalAmount),
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 8,
                          child: Text(
                            '${c.monthsCount}',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 11,
                          child: Text(
                            money(c.monthlyPayment),
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        _pCell(
                          flex: 19,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 34,
                                child: FilledButton(
                                  onPressed: () => onApprove(c),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.completed,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'اعتماد',
                                    style: AppTheme.text(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 34,
                                child: OutlinedButton(
                                  onPressed: () => onReject(c),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.late,
                                    side: BorderSide(
                                      color: AppTheme.late.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'رفض',
                                    style: AppTheme.text(
                                      color: AppTheme.late,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pCell({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: child,
      ),
    );
  }
}
