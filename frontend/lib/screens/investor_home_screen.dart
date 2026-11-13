import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/investor.dart';
import '../models/page_result.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/format.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/home_header.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 18),
              Text(
                'لوحة المستثمر',
                style: AppTheme.text(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'كل عقد استثماري مستقل — الرصيد الظاهر مجموع عقودك.',
                style: AppTheme.text(
                  fontSize: 13,
                  color: AppTheme.basic.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
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
                        : RefreshIndicator(
                            color: AppTheme.soft,
                            onRefresh: () => _load(silent: true),
                            child: ListView(
                              children: [
                                _stats(),
                                const SizedBox(height: 22),
                                Text(
                                  'عقودي الاستثمارية',
                                  style: AppTheme.text(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_investments.items.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      'لا توجد عقود استثمار بعد. عند إضافة عقد من الإدارة سيظهر هنا.',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.text(
                                        color: AppTheme.basic
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  )
                                else
                                  ..._investments.items.map(_contractCard),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats() {
    final inv = _investor;
    if (inv == null) return const SizedBox.shrink();
    return Row(
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
            title: 'قسط هذا الشهر',
            value: money(inv.dueThisMonthAmount),
            background: AppTheme.cardMint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DashboardStatCard(
            title: 'المتبقي',
            value: money(inv.remainingAmount),
            background: AppTheme.cardGold,
          ),
        ),
      ],
    );
  }

  Widget _contractCard(Investment item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openInvestment(item),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        money(item.principal),
                        style: AppTheme.text(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      investmentStatusLabel(item.status),
                      style: AppTheme.text(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.soft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'فائدة ${item.interestPercent}% → بعد الفائدة ${money(item.totalWithInterest)}',
                  style: AppTheme.text(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'القسط الشهري ${money(item.monthlyPayout)} · ${item.monthsCount} أشهر · متبقي ${item.remainingMonths}',
                  style: AppTheme.text(
                    fontSize: 12,
                    color: AppTheme.basic.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'من ${formatDate(item.startDate)} · أول قسط ${formatDate(item.firstDueDate)}',
                  style: AppTheme.text(
                    fontSize: 12,
                    color: AppTheme.basic.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
