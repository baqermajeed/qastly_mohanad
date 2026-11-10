import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';

Future<bool?> showPayDialog(
  BuildContext context, {
  required ApiService api,
  Customer? preselected,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => PayDialog(api: api, preselected: preselected),
  );
}

class PayDialog extends StatefulWidget {
  const PayDialog({super.key, required this.api, this.preselected});

  final ApiService api;
  final Customer? preselected;

  @override
  State<PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<PayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _patientSearch = TextEditingController();

  List<Customer> _customers = [];
  Customer? _selected;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _headerBlue = Color(0xFFD7EEF8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _sectionBg = Color(0xFFF7FBFD);
  static const _requiredRed = Color(0xFFE53935);
  static const _actionBlue = Color(0xFF1E88C8);

  @override
  void initState() {
    super.initState();
    _selected = widget.preselected;
    if (_selected != null) {
      _amount.text = money(_selected!.monthlyPayment);
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _patientSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await widget.api.getCustomers();
      final active =
          all
              .where(
                (c) =>
                    c.status != CustomerStatus.completed &&
                    c.status != CustomerStatus.pending &&
                    c.status != CustomerStatus.rejected,
              )
              .toList();
      setState(() {
        _customers = active;
        if (_selected != null) {
          _selected = active.cast<Customer?>().firstWhere(
                (c) => c?.id == _selected!.id,
                orElse: () => active.isNotEmpty ? active.first : null,
              );
        } else if (active.isNotEmpty) {
          _selected = null;
        }
        if (_selected != null && _amount.text.isEmpty) {
          _amount.text = money(_selected!.monthlyPayment);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _actionBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.basic,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected == null) return;

    final amount = parseMoney(_amount.text);
    setState(() => _saving = true);
    try {
      await widget.api.addPayment(
        customerId: _selected!.id,
        amount: amount,
        paymentDate: _date,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    String firstChar(String s) => String.fromCharCodes(s.runes.take(1));
    if (parts.length == 1) return firstChar(parts.first);
    return '${firstChar(parts.first)}${firstChar(parts[1])}';
  }

  Future<void> _pickPatient() async {
    final query = ValueNotifier<String>('');
    final picked = await showDialog<Customer>(
      context: context,
      barrierColor: const Color(0x99002E45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              width: 440,
              height: 520,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33002E45),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFFE8F5FB), Color(0xFFF7FBFD)],
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(10),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.close_rounded,
                                color: _actionBlue,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'اختر المريض',
                          style: AppTheme.text(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.people_alt_rounded,
                          color: _actionBlue,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      controller: _patientSearch,
                      textAlign: TextAlign.right,
                      autofocus: true,
                      onChanged: (v) => query.value = v,
                      style: AppTheme.text(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '...ابحث بالاسم أو الهاتف',
                        hintStyle: AppTheme.text(
                          color: AppTheme.basic.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.soft,
                        ),
                        filled: true,
                        fillColor: _sectionBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: _actionBlue,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: query,
                      builder: (_, q, _) {
                        final filtered = _customers.where((c) {
                          final s = q.trim().toLowerCase();
                          if (s.isEmpty) return true;
                          return c.name.toLowerCase().contains(s) ||
                              c.phone.contains(s);
                        }).toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 42,
                                  color: AppTheme.basic.withValues(alpha: 0.25),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'لا توجد نتائج',
                                  style: AppTheme.text(
                                    color:
                                        AppTheme.basic.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            final selected = _selected?.id == c.id;
                            return Material(
                              color: selected
                                  ? const Color(0xFFE3F4FB)
                                  : const Color(0xFFF4F8FB),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => Navigator.pop(ctx, c),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? _actionBlue.withValues(alpha: 0.45)
                                          : const Color(0xFFE3F0F7),
                                    ),
                                  ),
                                  // ترتيب فعلي: يمين = أفاتار ثم الاسم | يسار = صح
                                  child: Row(
                                    textDirection: TextDirection.ltr,
                                    children: [
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: _actionBlue,
                                          size: 22,
                                        )
                                      else
                                        Transform.rotate(
                                          angle: 3.1415926535,
                                          child: Icon(
                                            Icons.chevron_left_rounded,
                                            color: AppTheme.basic.withValues(
                                              alpha: 0.3,
                                            ),
                                            size: 22,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          textAlign: TextAlign.right,
                                          style: AppTheme.text(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppTheme.basic,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 42,
                                        height: 42,
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
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _actionBlue.withValues(
                                                alpha: 0.18,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _initials(c.name),
                                          style: AppTheme.text(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _patientSearch.clear();
    if (picked != null) {
      setState(() {
        _selected = picked;
        _amount.text = money(picked.monthlyPayment);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.55).clamp(520.0, 700.0);
    final height = (size.height * 0.82).clamp(520.0, 720.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33002E45),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _actionBlue),
                        )
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
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
                          : Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              decoration: BoxDecoration(
                                color: _sectionBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE3F0F7),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _labeledField(
                                    label: 'المريض',
                                    required: true,
                                    icon: Icons.person_outline_rounded,
                                    child: InkWell(
                                      onTap: _customers.isEmpty
                                          ? null
                                          : _pickPatient,
                                      borderRadius: BorderRadius.circular(14),
                                      child: _box(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: AppTheme.basic.withValues(
                                                alpha: 0.45,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _selected == null
                                                    ? '...اختر المريض أو اكتب الاسم'
                                                    : _selected!.name,
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTheme.text(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _selected == null
                                                      ? AppTheme.basic
                                                          .withValues(
                                                          alpha: 0.4,
                                                        )
                                                      : AppTheme.basic,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.person_outline_rounded,
                                              size: 20,
                                              color: AppTheme.soft,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_customers.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'لا يوجد زبائن بحاجة لتسديد',
                                        style: AppTheme.text(
                                          color: _requiredRed,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _labeledField(
                                          label: 'مبلغ الدفعة',
                                          required: true,
                                          child: _amountField(),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _labeledField(
                                          label: 'تاريخ التسديد',
                                          required: true,
                                          child: InkWell(
                                            onTap: _pickDate,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: _box(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today_outlined,
                                                    size: 18,
                                                    color: AppTheme.basic
                                                        .withValues(alpha: 0.45),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      DateFormat('dd/MM/yyyy')
                                                          .format(_date),
                                                      textAlign: TextAlign.right,
                                                      style: AppTheme.text(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.event_outlined,
                                                    size: 20,
                                                    color: AppTheme.soft,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _labeledField(
                                    label: 'ملاحظة',
                                    icon: Icons.sticky_note_2_outlined,
                                    child: TextFormField(
                                      controller: _note,
                                      textAlign: TextAlign.right,
                                      minLines: 3,
                                      maxLines: 4,
                                      style: AppTheme.text(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '...(أضف ملاحظة (اختياري',
                                        hintStyle: AppTheme.text(
                                          color: AppTheme.basic
                                              .withValues(alpha: 0.4),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.all(14),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: _fieldBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: _fieldBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: _actionBlue,
                                            width: 1.4,
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
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.payHeader,
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    _headerBlue.withValues(alpha: 0.92),
                    _headerBlue.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.pop(context, false),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.close_rounded,
                    color: _actionBlue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 28,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تسديد دفعة',
                      style: AppTheme.text(
                        color: AppTheme.basic,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _actionBlue,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تسجيل دفعة تقسيط جديدة للمريض',
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8F1F6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving || _customers.isEmpty ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _actionBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  'تسجيل الدفعة',
                  style: AppTheme.text(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    _saving ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _actionBlue,
                  side: const BorderSide(color: _actionBlue, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: Text(
                  'إلغاء',
                  style: AppTheme.text(
                    color: _actionBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required Widget child,
    bool required = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: _requiredRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              label,
              style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: _actionBlue),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorder),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _amountField() {
    return TextFormField(
      controller: _amount,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        ThousandsSeparatorInputFormatter(),
      ],
      validator: (v) {
        if (_selected == null) return 'اختر المريض أولاً';
        final n = parseMoney(v);
        if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
        final remaining = _selected!.remainingAmount;
        if (n > remaining + 0.01) {
          return 'المبلغ أكبر من المتبقي (${money(remaining)} د.ع)';
        }
        return null;
      },
      style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'أدخل مبلغ الدفعة',
        hintStyle: AppTheme.text(
          color: AppTheme.basic.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.monetization_on_outlined,
          size: 20,
          color: AppTheme.soft,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              'د.ع',
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _actionBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _requiredRed),
        ),
      ),
    );
  }
}

/// توافق خلفي مع الاستيرادات القديمة.
class PayScreen extends StatelessWidget {
  const PayScreen({super.key, required this.api, this.preselected});

  final ApiService api;
  final Customer? preselected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: PayDialog(api: api, preselected: preselected),
      ),
    );
  }
}
