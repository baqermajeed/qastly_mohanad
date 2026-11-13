import 'package:flutter/material.dart';

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
  Investment? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  static const _actionBlue = Color(0xFF1E88C8);
  static const _fieldBorder = Color(0xFFD5E8F2);

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
      final investor = widget.isAdmin
          ? await widget.api.getInvestor(widget.investor.id)
          : await widget.api.getInvestor(widget.investor.id);
      final investments = await widget.api.getInvestments(
        investorId: widget.investor.id,
        page: 1,
        pageSize: 50,
      );
      Investment? selected;
      final selectedId = _selected?.id ?? widget.initialInvestmentId;
      if (selectedId != null) {
        try {
          selected = await widget.api.getInvestment(selectedId);
        } catch (_) {
          selected = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _investor = investor;
        _investments = investments;
        _selected = selected;
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

  Future<void> _openInvestment(Investment item) async {
    setState(() => _busy = true);
    try {
      final full = await widget.api.getInvestment(item.id);
      if (!mounted) return;
      setState(() => _selected = full);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAll() async {
    final inv = _selected;
    if (inv == null) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.api.confirmInvestmentPayouts(inv.id);
      if (!mounted) return;
      setState(() => _selected = updated);
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmOne(InvestorPayout payout) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.confirmPayout(payout.id);
      if (!mounted) return;
      setState(() => _selected = updated);
      _changed = true;
      await _load();
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
    final width = (size.width * 0.86).clamp(860.0, 1180.0);
    final height = (size.height * 0.9).clamp(620.0, 900.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: Colors.white,
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
                        : Row(
                            children: [
                              Expanded(flex: 5, child: _contractsPane()),
                              Container(width: 1, color: _fieldBorder),
                              Expanded(flex: 6, child: _detailPane()),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF3FAFD),
        border: Border(bottom: BorderSide(color: _fieldBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _investor.fullName,
                  style: AppTheme.text(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_investor.username} · ${_investor.phone.isEmpty ? '—' : _investor.phone}',
                  style: AppTheme.text(
                    fontSize: 13,
                    color: AppTheme.basic.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isAdmin) ...[
            OutlinedButton(
              onPressed: _editInvestor,
              child: const Text('تعديل'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _openAddInvestment,
              style: FilledButton.styleFrom(backgroundColor: _actionBlue),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('عقد استثمار'),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _contractsPane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryGrid(),
          const SizedBox(height: 16),
          Text(
            'العقود الاستثمارية',
            style: AppTheme.text(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _investments.items.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد عقود بعد',
                      style: AppTheme.text(
                        color: AppTheme.basic.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _investments.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _investments.items[i];
                      final selected = _selected?.id == item.id;
                      return InkWell(
                        onTap: () => _openInvestment(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE8F5FC)
                                : const Color(0xFFF8FCFE),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _actionBlue : _fieldBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      money(item.principal),
                                      style: AppTheme.text(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    investmentStatusLabel(item.status),
                                    style: AppTheme.text(
                                      fontSize: 12,
                                      color: _actionBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'فائدة ${item.interestPercent}% · قسط ${money(item.monthlyPayout)} · ${item.monthsCount} شهر',
                                style: AppTheme.text(
                                  fontSize: 12,
                                  color: AppTheme.basic.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'بداية ${formatDate(item.startDate)} · أول قسط ${formatDate(item.firstDueDate)}',
                                style: AppTheme.text(
                                  fontSize: 11,
                                  color: AppTheme.basic.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    final cards = [
      ('أصل الرصيد', money(_investor.principalTotal)),
      ('بعد الفائدة', money(_investor.totalWithInterest)),
      ('المدفوع', money(_investor.paidAmount)),
      ('المتبقي', money(_investor.remainingAmount)),
      ('قسط الشهر', money(_investor.dueThisMonthAmount)),
      ('عقود', '${_investor.investmentsCount}'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in cards)
          SizedBox(
            width: 140,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fieldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.$1,
                    style: AppTheme.text(
                      fontSize: 11,
                      color: AppTheme.basic.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.$2,
                    style: AppTheme.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _detailPane() {
    final inv = _selected;
    if (inv == null) {
      return Center(
        child: Text(
          'اختر عقداً لعرض جدول الأقساط',
          style: AppTheme.text(color: AppTheme.basic.withValues(alpha: 0.55)),
        ),
      );
    }

    final unpaid = inv.payouts.where((p) => !p.paid).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تفاصيل العقد',
                  style: AppTheme.text(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.isAdmin && unpaid.isNotEmpty)
                FilledButton(
                  onPressed: _busy ? null : _confirmAll,
                  style: FilledButton.styleFrom(backgroundColor: _actionBlue),
                  child: const Text('تأكيد صرف المستحق'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip('الأصل', money(inv.principal)),
              _chip('الفائدة', '${inv.interestPercent}% (${money(inv.interestAmount)})'),
              _chip('بعد الفائدة', money(inv.totalWithInterest)),
              _chip('القسط الشهري', money(inv.monthlyPayout)),
              _chip('المتبقي', money(inv.remainingAmount)),
              _chip('أشهر متبقية', '${inv.remainingMonths}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'جدول الأقساط',
            style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: inv.payouts.isEmpty
                ? Center(
                    child: Text(
                      'لا أقساط مستحقة بعد — أول قسط ${formatDate(inv.firstDueDate)}',
                      textAlign: TextAlign.center,
                      style: AppTheme.text(
                        color: AppTheme.basic.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: inv.payouts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final p = inv.payouts[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FCFE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _fieldBorder),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                'قسط ${p.installmentNo}',
                                style: AppTheme.text(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(child: Text(formatDate(p.dueDate))),
                            Expanded(
                              child: Text(
                                money(p.amount),
                                style: AppTheme.text(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              p.paid ? 'مصروف' : 'مستحق',
                              style: AppTheme.text(
                                fontSize: 12,
                                color: p.paid
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.isAdmin && !p.paid) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _busy ? null : () => _confirmOne(p),
                                child: const Text('تأكيد'),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _fieldBorder),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.text(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
