import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';

Future<bool?> showAddInvestmentDialog(
  BuildContext context, {
  required ApiService api,
  required String investorId,
  required String investorName,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => AddInvestmentDialog(
      api: api,
      investorId: investorId,
      investorName: investorName,
    ),
  );
}

class AddInvestmentDialog extends StatefulWidget {
  const AddInvestmentDialog({
    super.key,
    required this.api,
    required this.investorId,
    required this.investorName,
  });

  final ApiService api;
  final String investorId;
  final String investorName;

  @override
  State<AddInvestmentDialog> createState() => _AddInvestmentDialogState();
}

class _AddInvestmentDialogState extends State<AddInvestmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _principal = TextEditingController();
  final _interest = TextEditingController(text: '10');
  final _months = TextEditingController(text: '10');
  final _note = TextEditingController();
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  static const _actionBlue = Color(0xFF1E88C8);
  static const _fieldBorder = Color(0xFFD5E8F2);

  @override
  void dispose() {
    _principal.dispose();
    _interest.dispose();
    _months.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _previewPrincipal => parseMoney(_principal.text);
  double? get _previewInterest => parseMoney(_interest.text);
  int? get _previewMonths => int.tryParse(_months.text.trim());

  double? get _interestAmount {
    final p = _previewPrincipal;
    final i = _previewInterest;
    if (p == null || i == null) return null;
    return p * i / 100.0;
  }

  double? get _totalWithInterest {
    final p = _previewPrincipal;
    final interest = _interestAmount;
    if (p == null || interest == null) return null;
    return p + interest;
  }

  double? get _monthly {
    final total = _totalWithInterest;
    final months = _previewMonths;
    if (total == null || months == null || months <= 0) return null;
    return total / months;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final principal = parseMoney(_principal.text);
    final interest = parseMoney(_interest.text);
    final months = int.tryParse(_months.text.trim());
    if (principal == null || interest == null || months == null) return;

    setState(() => _saving = true);
    try {
      await widget.api.createInvestment(
        investorId: widget.investorId,
        principal: principal,
        interestPercent: interest,
        monthsCount: months,
        startDate: _startDate,
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.5).clamp(520.0, 720.0);
    final firstDue = firstDueDate(_startDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: size.height * 0.92),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'عقد استثمار جديد',
                        style: AppTheme.text(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'للمستثمر: ${widget.investorName} — كل عقد مستقل عن العقود السابقة.',
                        style: AppTheme.text(
                          fontSize: 13,
                          color: AppTheme.basic.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Column(
                      children: [
                        _field(
                          controller: _principal,
                          label: 'المبلغ المستثمر (الكاش)',
                          hint: '1000000',
                          keyboard: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = parseMoney(v);
                            if (n == null || n <= 0) return 'أدخل مبلغاً صالحاً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _interest,
                                label: 'نسبة الفائدة %',
                                hint: '10',
                                keyboard: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.]'),
                                  ),
                                ],
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final n = parseMoney(v);
                                  if (n == null || n < 0 || n > 100) {
                                    return 'نسبة غير صالحة';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _months,
                                label: 'عدد الأشهر',
                                hint: '10',
                                keyboard: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0 || n > 120) {
                                    return 'بين 1 و 120';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'تاريخ بداية الاستثمار',
                              filled: true,
                              fillColor: const Color(0xFFF7FBFE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _fieldBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _fieldBorder),
                              ),
                            ),
                            child: Text(formatDate(_startDate)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'أول قسط: ${formatDate(firstDue)}',
                            style: AppTheme.text(
                              fontSize: 12,
                              color: AppTheme.basic.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _note,
                          label: 'ملاحظة (اختياري)',
                          hint: 'وصف العقد',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _previewCard(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: _fieldBorder),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: _actionBlue,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('إنشاء العقد'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'معاينة الحساب',
            style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _previewRow('مبلغ الفائدة', _interestAmount),
          _previewRow('الرصيد بعد الفائدة', _totalWithInterest),
          _previewRow('القسط الشهري', _monthly),
        ],
      ),
    );
  }

  Widget _previewRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.text(fontSize: 13))),
          Text(
            value == null ? '—' : money(value),
            style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF7FBFE),
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
          ),
        ),
      ],
    );
  }
}
