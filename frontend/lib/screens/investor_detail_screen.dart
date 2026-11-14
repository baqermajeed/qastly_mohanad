import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/investor.dart';
import '../models/page_result.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';
import 'add_investment_screen.dart';
import 'add_investor_screen.dart';

Future<bool?> showInvestorDetailDialog(
  BuildContext context, {
  required ApiService api,
  required Investor investor,
  bool isAdmin = true,
  String? initialInvestmentId,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => InvestorDetailDialog(
      api: api,
      investor: investor,
      isAdmin: isAdmin,
      initialInvestmentId: initialInvestmentId,
    ),
  );
}

class InvestorDetailDialog extends StatefulWidget {
  const InvestorDetailDialog({
    super.key,
    required this.api,
    required this.investor,
    this.isAdmin = true,
    this.initialInvestmentId,
  });

  final ApiService api;
  final Investor investor;
  final bool isAdmin;
  final String? initialInvestmentId;

  @override
  State<InvestorDetailDialog> createState() => _InvestorDetailDialogState();
}

class _InvestorDetailDialogState extends State<InvestorDetailDialog> {
  late Investor _investor;
  PageResult<Investment> _investments = PageResult.empty(pageSize: 50);
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  static const _actionBlue = Color(0xFF1E88C8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _heroTop = Color(0xFF064E6A);
  static const _heroBottom = Color(0xFF069BAF);
  static const _paidGreen = Color(0xFF0E8A61);

  @override
  void initState() {
    super.initState();
    _investor = widget.investor;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final investor = await widget.api.getInvestor(widget.investor.id);
      final investments = await widget.api.getInvestments(
        investorId: widget.investor.id,
        page: 1,
        pageSize: 50,
      );
      if (!mounted) return;
      setState(() {
        _investor = investor;
        _investments = investments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAddInvestment() async {
    final changed = await showAddInvestmentDialog(
      context,
      api: widget.api,
      investorId: _investor.id,
      investorName: _investor.fullName,
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _editInvestor() async {
    final changed = await showAddInvestorDialog(
      context,
      api: widget.api,
      investor: _investor,
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _settleDues() async {
    if (_busy) return;
    final outstanding = _investor.dueThisMonthAmount;
    if (outstanding <= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مستحقات معلقة للتأكيد')),
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: outstanding == outstanding.roundToDouble()
          ? outstanding.toInt().toString()
          : outstanding.toStringAsFixed(2),
    );
    final payAmount = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'تسديد مستحقات المستثمر',
            style: AppTheme.text(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مستحقات هذا الشهر: ${money(outstanding)} د.ع'
                '\nيمكنك تسديد المبلغ كاملاً أو جزءاً منه.',
                style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'مبلغ التسديد',
                  hintText: 'مثال: ${(outstanding / 2).round()}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: AppTheme.text(
                  color: AppTheme.basic.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                final raw = amountCtrl.text.trim().replaceAll(',', '');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) return;
                Navigator.pop(ctx, value);
              },
              style: FilledButton.styleFrom(backgroundColor: _paidGreen),
              child: Text(
                'تأكيد التسديد',
                style: AppTheme.text(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    if (payAmount == null || !mounted) return;
    if (payAmount > outstanding + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'مبلغ التسديد أكبر من المستحقات (${money(outstanding)} د.ع)',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await widget.api.confirmInvestorDues(
        _investor.id,
        amount: payAmount,
      );
      if (!mounted) return;
      setState(() {
        _investor = updated;
        _changed = true;
      });
      await _load();
      if (!mounted) return;
      final remaining = _investor.dueThisMonthAmount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining > 0.01
                ? 'تم تسديد ${money(payAmount)} د.ع — المتبقي ${money(remaining)} د.ع'
                : 'تم تسديد المستحقات بالكامل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.42).clamp(420.0, 560.0);
    final height = (size.height * 0.88).clamp(560.0, 820.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: const Color(0xFFF7FBFD),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.soft),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
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
                        : _body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final name = _investor.fullName.trim();
    final initial = name.isEmpty ? 'م' : name[0];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _fieldBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [_heroTop, _heroBottom],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              style: AppTheme.text(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _investor.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.text(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _investor.phone.isEmpty ? _investor.username : _investor.phone,
                  style: AppTheme.text(
                    fontSize: 12,
                    color: AppTheme.basic.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isAdmin) ...[
            IconButton(
              tooltip: 'تعديل',
              onPressed: _editInvestor,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'عقد استثمار',
              onPressed: _openAddInvestment,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 22),
              color: _actionBlue,
            ),
          ],
          IconButton(
            onPressed: () => Navigator.pop(context, _changed),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final due = _investor.dueThisMonthAmount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        Text(
          'إحصائيات عامة',
          style: AppTheme.text(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _metricsGrid([
          ('عدد العقود', '${_investor.investmentsCount}'),
          ('أصل الرصيد', money(_investor.principalTotal)),
          ('بعد الفائدة', money(_investor.totalWithInterest)),
          ('المستلم', money(_investor.paidAmount)),
          ('المتبقي', money(_investor.remainingAmount)),
          ('القسط الشهري', money(_investor.monthlyPayoutTotal)),
        ]),
        const SizedBox(height: 14),
        _dueCard(due),
        if (widget.isAdmin) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _busy || due <= 0.01 ? null : _settleDues,
              style: FilledButton.styleFrom(
                backgroundColor: _paidGreen,
                disabledBackgroundColor: _paidGreen.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                due <= 0.01 ? 'لا مستحقات حالياً' : 'تسديد المستحقات',
                style: AppTheme.text(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'العقود الاستثمارية',
                style: AppTheme.text(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _fieldBorder),
              ),
              child: Text(
                '${_investments.items.length}',
                style: AppTheme.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.soft,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_investments.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _fieldBorder),
            ),
            child: Text(
              'لا توجد عقود بعد',
              textAlign: TextAlign.center,
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          for (var i = 0; i < _investments.items.length; i++) ...[
            _contractCard(i + 1, _investments.items[i]),
            if (i != _investments.items.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _dueCard(double due) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_heroTop, _heroBottom],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مستحقاته هذا الشهر',
                  style: AppTheme.text(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  money(due),
                  style: AppTheme.text(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white.withValues(alpha: 0.9),
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(List<(String, String)> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _fieldBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.$1,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.text(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.basic.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contractCard(int index, Investment item) {
    final statusColor = switch (item.status) {
      InvestmentStatus.completed => _paidGreen,
      InvestmentStatus.cancelled => const Color(0xFFC0392B),
      _ => _actionBlue,
    };
    final last = lastDueDate(
      firstDue: item.firstDueDate,
      monthsCount: item.monthsCount,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F4FB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: AppTheme.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.soft,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      money(item.principal),
                      style: AppTheme.text(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'فائدة ${item.interestPercent}%',
                      style: AppTheme.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.basic.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  investmentStatusLabel(item.status),
                  style: AppTheme.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat('بعد الفائدة', money(item.totalWithInterest)),
                ),
                Expanded(
                  child: _miniStat('القسط', money(item.monthlyPayout)),
                ),
                Expanded(
                  child: _miniStat(
                    'المتبقي',
                    money(item.remainingAmount),
                    valueColor: const Color(0xFFC38508),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أول قسط ${formatDayMonth(item.firstDueDate)}'
            ' · آخر قسط ${last == null ? '—' : formatDayMonth(last)}'
            ' · ${item.remainingMonths}/${item.monthsCount} شهر',
            style: AppTheme.text(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.basic.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.text(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.basic.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.text(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
