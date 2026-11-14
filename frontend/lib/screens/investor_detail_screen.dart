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
  static const _heroTop = Color(0xFF064E6A);
  static const _heroBottom = Color(0xFF069BAF);

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
      Investment? selected;
      final preferredId = _selected?.id ?? widget.initialInvestmentId;
      final targetId = preferredId ??
          (investments.items.isNotEmpty ? investments.items.first.id : null);
      if (targetId != null) {
        try {
          selected = await widget.api.getInvestment(targetId);
        } catch (_) {
          for (final item in investments.items) {
            if (item.id == targetId) {
              selected = item;
              break;
            }
          }
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

  Future<void> _selectInvestment(String id) async {
    setState(() => _busy = true);
    try {
      final full = await widget.api.getInvestment(id);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.34).clamp(360.0, 440.0);
    final height = (size.height * 0.62).clamp(420.0, 560.0);

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
          elevation: 0,
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
    final inv = _selected;
    if (inv == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'لا يوجد عقد لعرضه',
                style: AppTheme.text(
                  color: AppTheme.basic.withValues(alpha: 0.55),
                ),
              ),
              if (widget.isAdmin) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _openAddInvestment,
                  style: FilledButton.styleFrom(backgroundColor: _actionBlue),
                  child: const Text('إضافة عقد استثمار'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final unpaid = inv.payouts.where((p) => !p.paid).toList();
    final lastDue = lastDueDate(
      firstDue: inv.firstDueDate,
      monthsCount: inv.monthsCount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        if (widget.isAdmin && _investments.items.length > 1) ...[
          DropdownButtonFormField<String>(
            value: inv.id,
            decoration: InputDecoration(
              labelText: 'العقد',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
            ),
            items: [
              for (final item in _investments.items)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    '${money(item.principal)} · ${item.monthsCount} شهر',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (id) {
                    if (id != null) _selectInvestment(id);
                  },
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'معلومات وإحصائيات العقد',
                style: AppTheme.text(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.isAdmin && unpaid.isNotEmpty)
              TextButton(
                onPressed: _busy ? null : _confirmAll,
                child: const Text('تأكيد المستحق'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _metricsGrid(inv),
        const SizedBox(height: 12),
        _datesRow(
          first: formatDayMonth(inv.firstDueDate),
          last: lastDue == null ? '—' : formatDayMonth(lastDue),
        ),
      ],
    );
  }

  Widget _metricsGrid(Investment inv) {
    final items = [
      ('القسط الشهري', money(inv.monthlyPayout)),
      ('عدد الأشهر', '${inv.monthsCount}'),
      ('أشهر متبقية', '${inv.remainingMonths}'),
      ('المستلم', money(inv.paidAmount)),
      ('المتبقي', money(inv.remainingAmount)),
    ];
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

  Widget _datesRow({required String first, required String last}) {
    return Row(
      children: [
        Expanded(child: _dateTile('أول دفعة', first, Icons.play_arrow_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _dateTile('آخر دفعة', last, Icons.flag_rounded)),
      ],
    );
  }

  Widget _dateTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _actionBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.text(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.basic.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  value,
                  style: AppTheme.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
