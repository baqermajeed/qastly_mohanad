import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/user.dart';
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

Future<bool?> showAddCustomerDialog(
  BuildContext context, {
  required ApiService api,
  AppUser? user,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => AddCustomerDialog(api: api, user: user),
  );
}

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key, required this.api, this.user});

  final ApiService api;
  final AppUser? user;

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mastercard = TextEditingController();
  final _nationalId = TextEditingController();
  final _total = TextEditingController();
  final _months = TextEditingController();
  final _notes = TextEditingController();

  String? _governorate;
  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _saving = false;

  static const _headerBlue = Color(0xFFD7EEF8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _sectionBg = Color(0xFFF7FBFD);
  static const _requiredRed = Color(0xFFE53935);
  static const _actionBlue = Color(0xFF1E88C8);

  @override
  void initState() {
    super.initState();
    _total.addListener(_onAmountChanged);
    _months.addListener(_onAmountChanged);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _total.removeListener(_onAmountChanged);
    _months.removeListener(_onAmountChanged);
    _name.dispose();
    _phone.dispose();
    _mastercard.dispose();
    _nationalId.dispose();
    _total.dispose();
    _months.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  int? get _monthsCount => int.tryParse(_months.text.trim());

  double get _bankPercent => widget.user?.bankPercent ?? 0;
  double get _platformPercent => widget.user?.platformPercent ?? 0;
  double get _investorPercent => widget.user?.investorPercent ?? 0;

  double? get _totalAmount => parseMoney(_total.text);

  double? get _bankAmount {
    final total = _totalAmount;
    if (total == null) return null;
    return total * _bankPercent / 100;
  }

  double? get _platformAmount {
    final total = _totalAmount;
    if (total == null) return null;
    return total * _platformPercent / 100;
  }

  double? get _investorAmount {
    final total = _totalAmount;
    if (total == null) return null;
    return total * _investorPercent / 100;
  }

  double? get _financed {
    final total = _totalAmount;
    final bank = _bankAmount;
    final platform = _platformAmount;
    final investor = _investorAmount;
    if (total == null || bank == null || platform == null || investor == null) {
      return null;
    }
    return total - bank - platform - investor;
  }

  double? get _monthly {
    final financed = _financed;
    final months = _monthsCount;
    if (financed == null || months == null || months <= 0) return null;
    return financed / months;
  }

  DateTime get _firstDue => firstDueDate(_now);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final months = _monthsCount;
    if (_governorate == null || months == null) return;

    setState(() => _saving = true);
    try {
      await widget.api.createCustomer(
        name: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        phone: _phone.text.trim(),
        governorate: _governorate!,
        totalAmount: parseMoney(_total.text)!,
        monthsCount: months,
        registrationDate: DateTime.now(),
        mastercardNumber: _mastercard.text.trim(),
        nationalId: _nationalId.text.trim(),
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
    final width = (size.width * 0.62).clamp(560.0, 780.0);
    final height = (size.height * 0.86).clamp(560.0, 820.0);

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
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        children: [
                      _sectionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'معلومات الزبون',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _labeledField(
                                label: 'اسم الزبون',
                                required: true,
                                child: _input(
                                  controller: _name,
                                  hint: 'أدخل الاسم الثلاثي للزبون',
                                  icon: Icons.person_outline_rounded,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[\u0600-\u06FFa-zA-Z\s]'),
                                    ),
                                  ],
                                  validator: validatePatientName,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _labeledField(
                                label: 'رقم الهاتف',
                                required: true,
                                child: _input(
                                  controller: _phone,
                                  hint: '0770xxxxxxxx',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: validateIraqiPhone,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _labeledField(
                                label: 'المحافظة',
                                required: true,
                                child: _dropdown<String>(
                                  value: _governorate,
                                  hint: 'اختر المحافظة',
                                  icon: Icons.location_on_outlined,
                                  items: _governorates
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(g),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _governorate = v),
                                  validator: (v) =>
                                      v == null ? 'اختر المحافظة' : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        icon: Icons.payments_outlined,
                        title: 'تفاصيل التقسيط',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _labeledField(
                                label: 'المبلغ الكلي',
                                required: true,
                                child: _input(
                                  controller: _total,
                                  hint: 'أدخل المبلغ الكلي',
                                  icon: Icons.payments_outlined,
                                  suffix: Text(
                                    'د.ع',
                                    style: AppTheme.text(
                                      color: AppTheme.basic.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    ThousandsSeparatorInputFormatter(),
                                  ],
                                  validator: (v) {
                                    final n = parseMoney(v);
                                    if (n == null || n <= 0) {
                                      return 'أدخل مبلغاً صحيحاً';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _labeledField(
                                label: 'عدد أشهر التقسيط',
                                required: true,
                                child: _input(
                                  controller: _months,
                                  hint: 'أدخل عدد الأشهر',
                                  icon: Icons.calendar_month_outlined,
                                  suffix: Text(
                                    'شهر',
                                    style: AppTheme.text(
                                      color: AppTheme.basic.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    final n = int.tryParse(v?.trim() ?? '');
                                    if (n == null || n <= 0) {
                                      return 'أدخل عدد أشهر صحيح';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _labeledField(
                                label: 'مبلغ الدفعة الشهرية',
                                child: _readonlyBox(
                                  _monthly == null
                                      ? '0 د.ع'
                                      : '${money(_monthly!)} د.ع',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        icon: Icons.pie_chart_outline_rounded,
                        title: 'توزيع المبالغ',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _labeledField(
                                    label: 'نسبة المصرف ($_bankPercent%)',
                                    child: _readonlyBox(
                                      _bankAmount == null
                                          ? '0 د.ع'
                                          : '${money(_bankAmount!)} د.ع',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _labeledField(
                                    label: 'نسبة المنصة ($_platformPercent%)',
                                    child: _readonlyBox(
                                      _platformAmount == null
                                          ? '0 د.ع'
                                          : '${money(_platformAmount!)} د.ع',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _labeledField(
                                    label: 'نسبة المستثمر ($_investorPercent%)',
                                    child: _readonlyBox(
                                      _investorAmount == null
                                          ? '0 د.ع'
                                          : '${money(_investorAmount!)} د.ع',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _labeledField(
                                    label: 'المبلغ بعد النسب',
                                    child: _readonlyBox(
                                      _financed == null
                                          ? '0 د.ع'
                                          : '${money(_financed!)} د.ع',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'أول دفعة تُضاف يوم ${DateFormat('dd/MM/yyyy').format(_firstDue)} (1 من الشهر التالي)',
                                style: AppTheme.text(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _actionBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        icon: Icons.description_outlined,
                        title: 'معلومات إضافية',
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _labeledField(
                                    label: 'رقم الماستر كارد',
                                    child: _input(
                                      controller: _mastercard,
                                      hint: 'أدخل رقم الماستر كارد',
                                      icon: Icons.credit_card_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(19),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _labeledField(
                                    label: 'رقم البطاقة الوطنية',
                                    child: _input(
                                      controller: _nationalId,
                                      hint: 'أدخل رقم البطاقة الوطنية',
                                      icon: Icons.badge_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _labeledField(
                                    label: 'تاريخ ووقت التسجيل',
                                    child: _readonlyBox(
                                      DateFormat('dd/MM/yyyy  HH:mm:ss')
                                          .format(_now),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: _labeledField(
                                    label: 'ملاحظات',
                                    child: _input(
                                      controller: _notes,
                                      hint: 'أضف ملاحظات (اختياري)',
                                      icon: Icons.sticky_note_2_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                        ],
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
              AppAssets.addPatientHeader,
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
                  stops: const [0, 0.45, 1],
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
              elevation: 0,
              child: InkWell(
                onTap: () => Navigator.pop(context, false),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.close_rounded, color: _actionBlue, size: 22),
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
              // RTL: start = اليمين حتى يتطابق يمين العنوان مع النص أسفله
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة زبون جديد',
                  textAlign: TextAlign.right,
                  style: AppTheme.text(
                    color: AppTheme.basic,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل بيانات الزبون وخطة التقسيط. الدفعات تُضاف كل يوم 1.',
                  textAlign: TextAlign.right,
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8F1F6))),
      ),
      child: Row(
        children: [
          // RTL: الأول يمين = حفظ
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
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
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  'إرسال للموافقة',
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
                onPressed: _saving ? null : () => Navigator.pop(context, false),
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

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: AppTheme.text(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: _actionBlue),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required Widget child,
    bool required = false,
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
              style: AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _box({required Widget child, Color? color}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorder),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _readonlyBox(String value) {
    return _box(
      color: const Color(0xFFEAF5FB),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: AppTheme.text(
            color: AppTheme.basic.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: TextAlign.right,
      style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.text(
          color: AppTheme.basic.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        // RTL: prefix = يمين (أيقونة)، suffix = يسار (د.ع)
        prefixIcon: Icon(icon, size: 20, color: AppTheme.soft),
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: Center(widthFactor: 1, child: suffix),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.basic.withValues(alpha: 0.45),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.text(
          color: AppTheme.basic.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.soft),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

/// توافق خلفي مع الاستيرادات القديمة إن وُجدت.
class AddCustomerScreen extends StatelessWidget {
  const AddCustomerScreen({super.key, required this.api, this.user});

  final ApiService api;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(child: AddCustomerDialog(api: api, user: user)),
    );
  }
}
