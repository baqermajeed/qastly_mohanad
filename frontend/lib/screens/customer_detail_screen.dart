import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';
import '../widgets/appointment_status_chip.dart';

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

Future<void> showCustomerDetailDialog(
  BuildContext context, {
  required ApiService api,
  required String customerId,
  bool isAdmin = false,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => CustomerDetailDialog(
      api: api,
      customerId: customerId,
      isAdmin: isAdmin,
    ),
  );
}

class CustomerDetailDialog extends StatefulWidget {
  const CustomerDetailDialog({
    super.key,
    required this.api,
    required this.customerId,
    this.isAdmin = false,
  });

  final ApiService api;
  final String customerId;
  final bool isAdmin;

  @override
  State<CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<CustomerDetailDialog> {
  Customer? _customer;
  bool _loading = true;
  String? _error;

  static const _headerBlue = Color(0xFFD7EEF8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _sectionBg = Color(0xFFF7FBFD);
  static const _actionBlue = Color(0xFF1E88C8);
  static const _titleBlue = Color(0xFF0B3A5C);

  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static const _whatsappGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openWhatsApp(Customer c) async {
    final uri = Uri.parse(c.whatsappUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  Future<void> _editInfo(Customer c) async {
    final updated = await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditCustomerInfoDialog(
        api: widget.api,
        customer: c,
        isAdmin: widget.isAdmin,
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _customer = updated);
    await _load();
  }

  // ignore: unused_element
  Future<void> _editPayment(Customer c, PaymentRecord payment) async {
    final updated = await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditPaymentDialog(
        api: widget.api,
        customer: c,
        payment: payment,
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _customer = updated);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customer = await widget.api.getCustomer(widget.customerId);
      setState(() => _customer = customer);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.68).clamp(760.0, 980.0);
    final height = (size.height * 0.88).clamp(620.0, 900.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Directionality(
        textDirection: TextDirection.rtl,
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
                            child: CircularProgressIndicator(
                              color: _actionBlue,
                            ),
                          )
                        : _error != null
                            ? Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: AppTheme.text(fontSize: 14),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      onPressed: _load,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _actionBlue,
                                      ),
                                      child: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                ),
                              )
                            : _customer == null
                                ? const SizedBox.shrink()
                                : _buildBody(_customer!),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 178,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.patientFileHeader,
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
                    _headerBlue.withValues(alpha: 0.94),
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
                onTap: () => Navigator.pop(context),
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
                      'ملف الزبون',
                      style: AppTheme.text(
                        color: _titleBlue,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: _actionBlue,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'معلومات الزبون والدفعات التلقائية',
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

  Widget _buildBody(Customer c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(c),
          const SizedBox(height: 14),
          _idsCard(c),
          const SizedBox(height: 14),
          _statsRow(c),
          const SizedBox(height: 14),
          _planRow(c),
          const SizedBox(height: 14),
          _paymentsSection(c),
        ],
      ),
    );
  }

  Widget _infoCard(Customer c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F002E45),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _infoItem(
                icon: Icons.person_outline_rounded,
                label: 'الاسم',
                value: c.name,
              ),
            ),
            _vDivider(),
            Expanded(
              child: _infoItem(
                icon: Icons.phone_outlined,
                label: 'رقم الهاتف',
                value: c.phone,
              ),
            ),
            _vDivider(),
            Expanded(
              child: _infoItem(
                icon: Icons.location_on_outlined,
                label: 'المحافظة',
                value: c.governorate,
              ),
            ),
            _vDivider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        color: _actionBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'حالة الخطة',
                            style: AppTheme.text(
                              color: AppTheme.basic.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppointmentStatusChip(status: c.status),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _vDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _editInfo(c),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _actionBlue,
                          side: const BorderSide(color: Color(0xFFB7D7EA)),
                          backgroundColor: const Color(0xFFEAF6FB),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          'تعديل المعلومات',
                          style: AppTheme.text(
                            color: _actionBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: FilledButton.icon(
                        onPressed: () => _openWhatsApp(c),
                        style: FilledButton.styleFrom(
                          backgroundColor: _whatsappGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(
                          'تواصل واتساب',
                          style: AppTheme.text(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
  }

  Widget _idsCard(Customer c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F002E45),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _infoItem(
                icon: Icons.credit_card_outlined,
                label: 'رقم الماستر كارد',
                value: c.mastercardNumber.isEmpty ? '—' : c.mastercardNumber,
              ),
            ),
            _vDivider(),
            Expanded(
              child: _infoItem(
                icon: Icons.badge_outlined,
                label: 'رقم البطاقة الوطنية',
                value: c.nationalId.isEmpty ? '—' : c.nationalId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFDDEAF1),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _actionBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.text(
                    color: _titleBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planRow(Customer c) {
    final firstDue = c.firstDueDate;
    final nextDue = c.nextDueDate;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'نسبة المصرف',
            value: '${c.bankPercent}%  •  ${money(c.bankAmount)} د.ع',
            icon: Icons.account_balance_outlined,
            background: const Color(0xFFE8F3FB),
            iconColor: const Color(0xFF1E88C8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'نسبة المنصة',
            value: '${c.platformPercent}%  •  ${money(c.platformAmount)} د.ع',
            icon: Icons.storefront_outlined,
            background: const Color(0xFFE7F7EF),
            iconColor: const Color(0xFF0E8A61),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'المبلغ بعد النسب',
            value: '${money(c.financedAmount)} د.ع',
            icon: Icons.pie_chart_outline,
            background: const Color(0xFFF3ECFB),
            iconColor: const Color(0xFF7B4DB8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: firstDue == null ? 'أول دفعة' : 'أول دفعة ${_dateFmt.format(firstDue)}',
            value: nextDue == null
                ? 'لا توجد دفعات قادمة'
                : 'القادمة ${_dateFmt.format(nextDue)}',
            icon: Icons.event_available_outlined,
            background: const Color(0xFFEAF6FB),
            iconColor: const Color(0xFF069BAF),
          ),
        ),
      ],
    );
  }

  Widget _statsRow(Customer c) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'المبلغ الكلي',
            value: '${money(c.totalAmount)} د.ع',
            icon: Icons.monetization_on_outlined,
            background: const Color(0xFFE7F7EF),
            iconColor: const Color(0xFF0E8A61),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'عدد الأشهر الكلي',
            value: '${c.monthsCount} شهر',
            icon: Icons.calendar_month_outlined,
            background: const Color(0xFFE8F3FB),
            iconColor: const Color(0xFF1E88C8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'المبلغ المتبقي',
            value: '${money(c.remainingAmount)} د.ع',
            icon: Icons.payments_outlined,
            background: const Color(0xFFFDECEC),
            iconColor: const Color(0xFFE53935),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'عدد الأشهر المتبقية',
            value: '${c.remainingMonths} شهر',
            icon: Icons.event_repeat_outlined,
            background: const Color(0xFFEAF6FB),
            iconColor: const Color(0xFF069BAF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'مبلغ الدفعة الشهرية',
            value: '${money(c.monthlyPayment)} د.ع',
            icon: Icons.calendar_today_outlined,
            background: const Color(0xFFF3ECFB),
            iconColor: const Color(0xFF7B4DB8),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color background,
    required Color iconColor,
  }) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: AppTheme.text(
                color: _titleBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsSection(Customer c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F002E45),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  'سجل الدفعات التلقائية',
                  style: AppTheme.text(
                    color: _titleBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.receipt_long_outlined,
                  color: _actionBlue,
                  size: 20,
                ),
              ],
            ),
          ),
          _tableHeader(),
          if (c.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
              child: Center(
                child: Text(
                  c.firstDueDate == null
                      ? 'لا توجد دفعات بعد'
                      : 'لا توجد دفعات بعد — أول دفعة يوم ${_dateFmt.format(c.firstDueDate!)}',
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...List.generate(c.payments.length, (i) {
              final p = c.payments[i];
              return _paymentRow(
                customer: c,
                index: i + 1,
                payment: p,
                striped: i.isOdd,
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _headerCell('#', flex: 1, icon: null),
          _headerCell('تاريخ التسديد', flex: 3, icon: Icons.calendar_today_outlined),
          _headerCell('مبلغ الدفعة', flex: 3, icon: Icons.payments_outlined),
          _headerCell('طريقة الدفع', flex: 3, icon: Icons.credit_card_outlined),
          _headerCell('الملاحظة', flex: 5, icon: Icons.description_outlined),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex, IconData? icon}) {
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.basic.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentRow({
    required Customer customer,
    required int index,
    required PaymentRecord payment,
    required bool striped,
  }) {
    final note = (payment.note == null || payment.note!.trim().isEmpty)
        ? '—'
        : payment.note!.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFF3FAFD) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              index.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _dateFmt.format(payment.paymentDate),
              textAlign: TextAlign.center,
              style: AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${money(payment.amount)} د.ع',
              textAlign: TextAlign.center,
              style: AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(child: _methodChip(method: payment.method)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              note,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.text(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: note == '—'
                    ? AppTheme.basic.withValues(alpha: 0.4)
                    : AppTheme.basic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodChip({required String method}) {
    final isCard = method == 'card';
    final isAuto = method == 'auto';
    final bg = isAuto
        ? const Color(0xFFEAF6FB)
        : isCard
            ? const Color(0xFFE8F3FB)
            : const Color(0xFFE7F7EF);
    final fg = isAuto
        ? const Color(0xFF069BAF)
        : isCard
            ? const Color(0xFF1E88C8)
            : const Color(0xFF0E8A61);
    final label = isAuto ? 'تلقائي' : isCard ? 'بطاقة' : 'نقداً';
    final icon = isAuto
        ? Icons.autorenew_rounded
        : isCard
            ? Icons.credit_card_rounded
            : Icons.payments_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.text(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCustomerInfoDialog extends StatefulWidget {
  const _EditCustomerInfoDialog({
    required this.api,
    required this.customer,
    required this.isAdmin,
  });

  final ApiService api;
  final Customer customer;
  final bool isAdmin;

  @override
  State<_EditCustomerInfoDialog> createState() =>
      _EditCustomerInfoDialogState();
}

class _EditCustomerInfoDialogState extends State<_EditCustomerInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _mastercard;
  late final TextEditingController _nationalId;
  late final TextEditingController _confirmPassword;
  late String _governorate;
  late CustomerStatus _status;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;

  static const _actionBlue = Color(0xFF1E88C8);

  bool get _canEditStatus =>
      widget.isAdmin && widget.customer.remainingAmount > 0.01;

  bool get _needsPasswordConfirm =>
      _canEditStatus &&
      _status == CustomerStatus.inactive &&
      widget.customer.status != CustomerStatus.inactive;

  List<CustomerStatus> get _statusOptions {
    if (!_canEditStatus) {
      return [widget.customer.status];
    }
    return const [
      CustomerStatus.active,
      CustomerStatus.inactive,
    ];
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer.name);
    _phone = TextEditingController(text: widget.customer.phone);
    _mastercard =
        TextEditingController(text: widget.customer.mastercardNumber);
    _nationalId = TextEditingController(text: widget.customer.nationalId);
    _confirmPassword = TextEditingController();
    _governorate = _governorates.contains(widget.customer.governorate)
        ? widget.customer.governorate
        : _governorates.first;
    final options = _statusOptions;
    _status = options.contains(widget.customer.status)
        ? widget.customer.status
        : options.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _mastercard.dispose();
    _nationalId.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateCustomer(
        id: widget.customer.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        governorate: _governorate,
        mastercardNumber: _mastercard.text.trim(),
        nationalId: _nationalId.text.trim(),
        status: widget.isAdmin ? _status : null,
        confirmPassword:
            _needsPasswordConfirm ? _confirmPassword.text : null,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حفظ التعديلات');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, color: _actionBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'تعديل معلومات الزبون',
              style: AppTheme.text(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الاسم',
                    style: AppTheme.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'أدخل اسماً صالحاً';
                      }
                      return null;
                    },
                    style: AppTheme.text(fontWeight: FontWeight.w600),
                    decoration: _fieldDecoration(hint: 'اسم الزبون'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'رقم الهاتف',
                    style: AppTheme.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().length < 7) {
                        return 'أدخل رقم هاتف صالحاً';
                      }
                      return null;
                    },
                    style: AppTheme.text(fontWeight: FontWeight.w600),
                    decoration: _fieldDecoration(hint: '07xxxxxxxx'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'المحافظة',
                    style: AppTheme.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _governorate,
                    items: _governorates
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              g,
                              style: AppTheme.text(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _governorate = v);
                    },
                    decoration: _fieldDecoration(hint: 'المحافظة'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'رقم الماستر كارد',
                    style: AppTheme.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _mastercard,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    style: AppTheme.text(fontWeight: FontWeight.w600),
                    decoration: _fieldDecoration(hint: 'رقم الماستر كارد'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'رقم البطاقة الوطنية',
                    style: AppTheme.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nationalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(20),
                    ],
                    style: AppTheme.text(fontWeight: FontWeight.w600),
                    decoration: _fieldDecoration(hint: 'رقم البطاقة الوطنية'),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 14),
                    Text(
                      'حالة الخطة',
                      style: AppTheme.text(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<CustomerStatus>(
                      value: _status,
                      items: _statusOptions
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                statusLabel(s),
                                style:
                                    AppTheme.text(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: !_canEditStatus
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() {
                                  _status = v;
                                  if (v != CustomerStatus.inactive) {
                                    _confirmPassword.clear();
                                  }
                                });
                              }
                            },
                      decoration: _fieldDecoration(hint: 'حالة الخطة'),
                    ),
                    if (_needsPasswordConfirm) ...[
                      const SizedBox(height: 14),
                      Text(
                        'كلمة مرور الحساب للتأكيد',
                        style: AppTheme.text(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscurePassword,
                        validator: (v) {
                          if (!_needsPasswordConfirm) return null;
                          if (v == null || v.trim().length < 4) {
                            return 'أدخل كلمة مرور حسابك للتأكيد';
                          }
                          return null;
                        },
                        style: AppTheme.text(fontWeight: FontWeight.w600),
                        decoration: _fieldDecoration(
                          hint: 'كلمة مرور المدير',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _actionBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _needsPasswordConfirm
                            ? 'تعليمليم الخطة غير نشطة يوقف الأقساط والدفعات التلقائية، ويتطلب كلمة مرور حساب المدير.'
                            : 'غير نشطة = خطة ملغاة وتتوقف دفعاتها التلقائية. المكتملة تظهر تلقائياً عند اكتمال السداد.',
                        style: AppTheme.text(
                          color: _actionBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'حالة الخطة الحالية: ${statusLabel(widget.customer.status)}. تعليم الخطة غير نشطة متاح لمدير المنصة فقط.',
                        style: AppTheme.text(
                          color: _actionBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: AppTheme.text(
                        color: AppTheme.late,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _actionBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'حفظ التعديلات',
                    style: AppTheme.text(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7FBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5E8F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _actionBlue, width: 1.5),
      ),
    );
  }
}

class _EditPaymentDialog extends StatefulWidget {
  const _EditPaymentDialog({
    required this.api,
    required this.customer,
    required this.payment,
  });

  final ApiService api;
  final Customer customer;
  final PaymentRecord payment;

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late String _method;
  bool _saving = false;
  String? _error;

  static const _actionBlue = Color(0xFF1E88C8);

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: money(widget.payment.amount));
    _note = TextEditingController(text: widget.payment.note ?? '');
    _date = widget.payment.paymentDate;
    _method = widget.payment.method;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _maxAmount {
    final paidOthers =
        widget.customer.paidAmount - widget.payment.amount;
    return (widget.customer.totalAmount - paidOthers).clamp(
      0,
      double.infinity,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = parseMoney(_amount.text);
    if (amount == null) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.api.updatePayment(
        paymentId: widget.payment.id,
        amount: amount,
        paymentDate: _date,
        note: _note.text.trim(),
        method: _method,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حفظ تعديل الدفعة');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: _actionBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'تعديل الدفعة',
              style: AppTheme.text(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'مبلغ الدفعة',
                  style: AppTheme.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    ThousandsSeparatorInputFormatter(),
                  ],
                  validator: (v) {
                    final n = parseMoney(v);
                    if (n == null || n <= 0) return 'أدخل مبلغاً صالحاً';
                    if (n > _maxAmount + 0.01) {
                      return 'الحد الأقصى ${money(_maxAmount)} د.ع';
                    }
                    return null;
                  },
                  style: AppTheme.text(fontWeight: FontWeight.w600),
                  decoration: _decoration('مبلغ الدفعة'),
                ),
                const SizedBox(height: 14),
                Text(
                  'تاريخ التسديد',
                  style: AppTheme.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _decoration('تاريخ التسديد'),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_date),
                      style: AppTheme.text(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'طريقة الدفع',
                  style: AppTheme.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _method = v);
                  },
                  decoration: _decoration('طريقة الدفع'),
                ),
                const SizedBox(height: 14),
                Text(
                  'الملاحظة',
                  style: AppTheme.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  style: AppTheme.text(fontWeight: FontWeight.w600),
                  decoration: _decoration('ملاحظة (اختياري)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: AppTheme.text(
                      color: AppTheme.late,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AppTheme.text(
                color: AppTheme.basic.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _actionBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
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
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7FBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5E8F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _actionBlue, width: 1.5),
      ),
    );
  }
}
