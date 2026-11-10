import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';

Future<void> showOverdueDialog(
  BuildContext context, {
  required ApiService api,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => OverdueDialog(api: api),
  );
}

class OverdueDialog extends StatefulWidget {
  const OverdueDialog({super.key, required this.api});

  final ApiService api;

  @override
  State<OverdueDialog> createState() => _OverdueDialogState();
}

class _OverdueDialogState extends State<OverdueDialog> {
  final _search = TextEditingController();
  List<Customer> _customers = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int _page = 0;
  static const _pageSize = 5;

  static const _headerBlue = Color(0xFFD7EEF8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _sectionBg = Color(0xFFF7FBFD);
  static const _actionBlue = Color(0xFF1E88C8);
  static const _lateRed = Color(0xFFE53935);
  static const _warnYellow = Color(0xFFFFF3C4);
  static const _warnYellowText = Color(0xFF9A7B00);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getCustomers(status: CustomerStatus.inactive);
      setState(() {
        _customers = list;
        _page = 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.governorate.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Customer> get _pageItems {
    final all = _filtered;
    final start = _page * _pageSize;
    if (start >= all.length) return [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _pageCount {
    final n = _filtered.length;
    if (n == 0) return 1;
    return (n / _pageSize).ceil();
  }

  int _paidInstallments(Customer c) {
    if (c.monthlyPayment <= 0) return 0;
    return (c.paidAmount / c.monthlyPayment).floor().clamp(0, c.monthsCount);
  }

  DateTime _dueDate(Customer c) {
    final paid = _paidInstallments(c);
    return DateTime(
      c.registrationDate.year,
      c.registrationDate.month + paid + 1,
      c.registrationDate.day,
    );
  }

  int _delayDays(Customer c) {
    final days = DateTime.now().difference(_dueDate(c)).inDays;
    return days < 0 ? 0 : days;
  }

  double _lateAmount(Customer c) {
    final days = _delayDays(c);
    if (days <= 0) return c.monthlyPayment;
    final monthsLate = (days / 30).ceil().clamp(1, c.remainingMonths);
    return (c.monthlyPayment * monthsLate).clamp(0, c.remainingAmount);
  }

  Future<void> _openWhatsApp(Customer c) async {
    await launchUrl(
      Uri.parse(c.whatsappUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _xlsCell(String value, {bool asText = false}) {
    final v = _xmlEscape(value);
    if (asText) {
      // \@ يجبر Excel على معاملة الخلية كنص
      return '<td style="mso-number-format:\'\\@\';">$v</td>';
    }
    return '<td>$v</td>';
  }

  Future<void> _exportExcel() async {
    try {
      final buffer = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office"')
        ..writeln('xmlns:x="urn:schemas-microsoft-com:office:excel"')
        ..writeln('xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="UTF-8">')
        ..writeln(
          '<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets>'
          '<x:ExcelWorksheet><x:Name>الخطط غير النشطة</x:Name>'
          '<x:WorksheetOptions><x:DisplayRightToLeft/></x:WorksheetOptions>'
          '</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->',
        )
        ..writeln('</head><body><table border="1">')
        ..writeln('<tr>')
        ..writeln(_xlsCell('#'))
        ..writeln(_xlsCell('اسم الزبون'))
        ..writeln(_xlsCell('رقم الهاتف'))
        ..writeln(_xlsCell('أشهر متبقية'))
        ..writeln(_xlsCell('المبلغ الشهري'))
        ..writeln(_xlsCell('المبلغ المتبقي'))
        ..writeln(_xlsCell('مدة التأخير (يوم)'))
        ..writeln(_xlsCell('تاريخ الاستحقاق'))
        ..writeln('</tr>');

      for (var i = 0; i < _filtered.length; i++) {
        final c = _filtered[i];
        buffer
          ..writeln('<tr>')
          ..writeln(_xlsCell('${i + 1}'))
          ..writeln(_xlsCell(c.name))
          ..writeln(_xlsCell(c.phone, asText: true))
          ..writeln(_xlsCell('${c.remainingMonths}'))
          ..writeln(_xlsCell('${money(c.monthlyPayment)} د.ع', asText: true))
          ..writeln(_xlsCell('${money(_lateAmount(c))} د.ع', asText: true))
          ..writeln(_xlsCell('${_delayDays(c)} يوم', asText: true))
          ..writeln(
            _xlsCell(
              DateFormat('dd/MM/yyyy').format(_dueDate(c)),
              asText: true,
            ),
          )
          ..writeln('</tr>');
      }

      buffer.writeln('</table></body></html>');

      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}غير_النشطة_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xls',
      );
      await file.writeAsString(buffer.toString(), flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم التصدير: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.88).clamp(900.0, 1180.0);
    final height = (size.height * 0.88).clamp(640.0, 920.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                  Expanded(child: _buildBody()),
                  _buildFooter(),
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
      height: 168,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.overdueHeader,
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
                      'الخطط غير النشطة (الملغاة)',
                      style: AppTheme.text(
                        color: AppTheme.basic,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.alarm_on_rounded,
                      color: _lateRed,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'قائمة المرضى الذين تجاوزوا تاريخ استحقاق الدفع',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _actionBlue),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _actionBlue,
                    side: const BorderSide(color: _fieldBorder),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.filter_list_rounded, size: 20),
                  label: Text(
                    'تصفية',
                    style: AppTheme.text(
                      color: _actionBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _search,
                  textAlign: TextAlign.right,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                  style: AppTheme.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث عن مريض (الاسم، رقم الهاتف...)',
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
                      vertical: 12,
                    ),
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
                      borderSide:
                          const BorderSide(color: _actionBlue, width: 1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildTable()),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد خطط غير نشطة حالياً',
          style: AppTheme.text(
            color: AppTheme.basic.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final items = _pageItems;
    final startIndex = _page * _pageSize;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3F0F7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tableHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                final index = startIndex + i + 1;
                final delay = _delayDays(c);
                final lateAmt = _lateAmount(c);
                final due = _dueDate(c);
                final zebra = i.isOdd;

                return Container(
                  color: zebra ? const Color(0xFFF7FBFD) : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _cell(
                        flex: 5,
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          textAlign: TextAlign.center,
                          style: AppTheme.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.basic.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      _cell(
                        flex: 14,
                        child: Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.text(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F4FB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                                color: _actionBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _cell(
                        flex: 12,
                        child: Text(
                          c.phone,
                          textAlign: TextAlign.center,
                          style: AppTheme.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.phone,
                          ),
                        ),
                      ),
                      _cell(
                        flex: 10,
                        child: Text(
                          '${c.remainingMonths}',
                          textAlign: TextAlign.center,
                          style: AppTheme.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _cell(
                        flex: 12,
                        child: Text(
                          '${money(c.monthlyPayment)} د.ع',
                          textAlign: TextAlign.center,
                          style: AppTheme.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _cell(
                        flex: 13,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 15,
                                color: _lateRed,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${money(lateAmt)} د.ع',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.text(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _lateRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _cell(
                        flex: 10,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: delay >= 30
                                  ? const Color(0xFFFFEBEE)
                                  : _warnYellow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$delay يوم',
                              style: AppTheme.text(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: delay >= 30 ? _lateRed : _warnYellowText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _cell(
                        flex: 11,
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(due),
                          textAlign: TextAlign.center,
                          style: AppTheme.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _cell(
                        flex: 13,
                        child: Center(
                          child: SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: () => _openWhatsApp(c),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.chat_rounded, size: 16),
                              label: Text(
                                'تواصل واتساب',
                                style: AppTheme.text(
                                  color: Colors.white,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    const headers = <(int, String)>[
      (5, '#'),
      (14, 'اسم الزبون'),
      (12, 'رقم الهاتف'),
      (10, 'أشهر متبقية'),
      (12, 'المبلغ الشهري'),
      (13, 'المبلغ المتبقي'),
      (10, 'مدة التأخير'),
      (11, 'تاريخ الاستحقاق'),
      (13, 'إجراء'),
    ];

    return Container(
      color: const Color(0xFFEEF5FA),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          for (final h in headers)
            _cell(
              flex: h.$1,
              child: Text(
                h.$2,
                textAlign: TextAlign.center,
                style: AppTheme.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.basic.withValues(alpha: 0.75),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }

  Widget _buildFooter() {
    final total = _filtered.length;
    final from = total == 0 ? 0 : _page * _pageSize + 1;
    final to = (_page * _pageSize + _pageItems.length).clamp(0, total);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8F1F6))),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _filtered.isEmpty ? null : _exportExcel,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F6B5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.table_view_rounded, size: 18),
              label: Text(
                'تصدير إلى Excel',
                style: AppTheme.text(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Spacer(),
          _pagination(),
          const Spacer(),
          Text(
            'عرض $from–$to من أصل $total مريض',
            style: AppTheme.text(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.basic.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    final count = _pageCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: _page > 0,
          onTap: () => setState(() => _page--),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < count && i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Material(
            color: _page == i ? _actionBlue : const Color(0xFFEEF5FA),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => setState(() => _page = i),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppTheme.text(
                      color: _page == i ? Colors.white : AppTheme.basic,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        _pageBtn(
          icon: Icons.chevron_right_rounded,
          enabled: _page < count - 1,
          onTap: () => setState(() => _page++),
        ),
      ],
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEEF5FA),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? AppTheme.basic
                : AppTheme.basic.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// توافق خلفي
class OverdueScreen extends StatelessWidget {
  const OverdueScreen({super.key, required this.api});

  final ApiService api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(child: OverdueDialog(api: api)),
    );
  }
}
