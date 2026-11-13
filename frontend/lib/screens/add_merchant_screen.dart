import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/merchant.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';

const _governorates = [
  'بغداد',
  'البصرة',
  'نينوى',
  'أربيل',
  'السليمانية',
  'دهوك',
  'كركوك',
  'الأنبار',
  'ديالى',
  'صلاح الدين',
  'بابل',
  'كربلاء',
  'النجف',
  'واسط',
  'ميسان',
  'ذي قار',
  'المثنى',
  'القادسية',
];

Future<bool?> showAddMerchantDialog(
  BuildContext context, {
  required ApiService api,
  Merchant? merchant,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => AddMerchantDialog(api: api, merchant: merchant),
  );
}

class AddMerchantDialog extends StatefulWidget {
  const AddMerchantDialog({super.key, required this.api, this.merchant});

  final ApiService api;
  final Merchant? merchant;

  @override
  State<AddMerchantDialog> createState() => _AddMerchantDialogState();
}

class _AddMerchantDialogState extends State<AddMerchantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _master = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _bank = TextEditingController();
  final _platform = TextEditingController();
  final _investor = TextEditingController();
  String? _governorate;
  bool _saving = false;

  static const _actionBlue = Color(0xFF1E88C8);
  static const _fieldBorder = Color(0xFFD5E8F2);

  bool get _editing => widget.merchant != null;

  @override
  void initState() {
    super.initState();
    final m = widget.merchant;
    if (m != null) {
      _name.text = m.fullName;
      _phone.text = m.phone;
      _address.text = m.address;
      _master.text = m.masterCard;
      _username.text = m.username;
      _bank.text = m.bankPercent.toString();
      _platform.text = m.platformPercent.toString();
      _investor.text = m.investorPercent.toString();
      _governorate = _governorates.contains(m.governorate)
          ? m.governorate
          : (m.governorate.isEmpty ? null : m.governorate);
    } else {
      _investor.text = '0';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _master.dispose();
    _username.dispose();
    _password.dispose();
    _bank.dispose();
    _platform.dispose();
    _investor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_governorate == null) return;

    final bank = parseMoney(_bank.text);
    final platform = parseMoney(_platform.text);
    final investor = parseMoney(_investor.text) ?? 0;
    if (bank == null ||
        platform == null ||
        bank + platform + investor >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'مجموع نسبة المصرف والمنصة والمستثمر يجب أن يكون أقل من 100',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.api.updateMerchant(
          id: widget.merchant!.id,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          governorate: _governorate!,
          address: _address.text.trim(),
          masterCard: _master.text.trim().replaceAll(' ', ''),
          password: _password.text.trim().isEmpty ? null : _password.text,
          bankPercent: bank,
          platformPercent: platform,
          investorPercent: investor,
        );
      } else {
        await widget.api.createMerchant(
          username: _username.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          governorate: _governorate!,
          address: _address.text.trim(),
          masterCard: _master.text.trim().replaceAll(' ', ''),
          bankPercent: bank,
          platformPercent: platform,
          investorPercent: investor,
        );
      }
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
    final width = (size.width * 0.62).clamp(640.0, 820.0);
    final height = (size.height * 0.88).clamp(560.0, 860.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editing ? 'تعديل التاجر' : 'إضافة تاجر',
                      style: AppTheme.text(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أدخل بيانات التاجر ونسب العمولة (مصرف / منصة / مستثمر). تُثبَّت على زبائنه الجدد.',
                      style: AppTheme.text(
                        fontSize: 13,
                        color: AppTheme.basic.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _name,
                                label: 'اسم التاجر',
                                hint: 'الاسم الكامل',
                                validator: (v) => (v == null || v.trim().length < 2)
                                    ? 'أدخل الاسم'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _phone,
                                label: 'رقم الهاتف',
                                hint: '0770xxxxxxxx',
                                keyboard: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: validateIraqiPhone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dropdown(
                                label: 'المحافظة',
                                value: _governorate,
                                hint: 'اختر المحافظة',
                                items: [
                                  for (final g in _governorates)
                                    DropdownMenuItem(value: g, child: Text(g)),
                                  if (_governorate != null &&
                                      !_governorates.contains(_governorate))
                                    DropdownMenuItem(
                                      value: _governorate,
                                      child: Text(_governorate!),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _governorate = v),
                                validator: (v) =>
                                    v == null ? 'اختر المحافظة' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _address,
                                label: 'العنوان',
                                hint: 'عنوان المحل / النشاط',
                                validator: (v) =>
                                    (v == null || v.trim().length < 2)
                                        ? 'أدخل العنوان'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _master,
                          label: 'رقم الماستر',
                          hint: 'رقم بطاقة الماستر',
                          keyboard: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(19),
                          ],
                          validator: (v) {
                            final value = (v ?? '').replaceAll(' ', '');
                            if (value.length < 8) return 'أدخل رقم ماستر صالحاً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _username,
                                label: 'اسم المستخدم',
                                hint: 'للدخول إلى النظام',
                                enabled: !_editing,
                                validator: (v) {
                                  if (_editing) return null;
                                  if (v == null || v.trim().length < 3) {
                                    return 'اسم المستخدم قصير';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _password,
                                label: _editing
                                    ? 'كلمة مرور جديدة (اختياري)'
                                    : 'كلمة المرور',
                                hint: _editing
                                    ? 'اتركه فارغاً للإبقاء على الحالية'
                                    : 'كلمة المرور',
                                obscure: true,
                                validator: (v) {
                                  if (_editing) return null;
                                  if (v == null || v.length < 4) {
                                    return 'كلمة المرور قصيرة';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _bank,
                                label: 'نسبة المصرف %',
                                hint: 'مثلاً 5',
                                keyboard: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                validator: _percentValidator,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                controller: _platform,
                                label: 'نسبة المنصة %',
                                hint: 'مثلاً 3',
                                keyboard: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                validator: _percentValidator,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _investor,
                          label: 'نسبة المستثمر %',
                          hint: 'مثلاً 2',
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: _percentValidator,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _actionBlue,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'حفظ',
                                  style: AppTheme.text(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
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
  }

  String? _percentValidator(String? v) {
    final n = parseMoney(v);
    if (n == null || n < 0 || n >= 100) return 'أدخل نسبة بين 0 و 99';
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    bool enabled = true,
    bool obscure = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          validator: validator,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          style: AppTheme.text(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _actionBlue, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _actionBlue, width: 1.4),
            ),
          ),
          style: AppTheme.text(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
