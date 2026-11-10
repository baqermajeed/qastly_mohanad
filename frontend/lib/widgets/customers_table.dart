import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../utils/format.dart';
import 'appointment_status_chip.dart';

class CustomersTable extends StatelessWidget {
  const CustomersTable({
    super.key,
    required this.customers,
    required this.onOpen,
    this.showMerchant = false,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onOpen;
  final bool showMerchant;

  List<(int, String)> get _headers => [
        (5, '#'),
        (7, ''),
        (11, 'اسم'),
        if (showMerchant) (10, 'التاجر'),
        (10, 'رقم هاتف'),
        (8, 'محافظة'),
        (10, 'تاريخ التسجيل'),
        (10, 'المبلغ الكلي'),
        (7, 'عدد الأشهر'),
        (8, 'أشهر متبقية'),
        (10, 'الدفعة الشهرية'),
        (10, 'المبلغ المتبقي'),
        (9, 'الحالة'),
        (11, 'واتساب'),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softGlow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                for (final h in _headers)
                  _HeaderCell(label: h.$2, flex: h.$1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softGlow,
            ),
            child: customers.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          'لا يوجد زبائن بعد',
                          style: AppTheme.text(
                            color: AppTheme.basic.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CustomerRow(
                      index: i + 1,
                      customer: customers[i],
                      onOpen: () => onOpen(customers[i]),
                      showMerchant: showMerchant,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.text(
          color: AppTheme.basic,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.index,
    required this.customer,
    required this.onOpen,
    this.showMerchant = false,
  });

  final int index;
  final Customer customer;
  final VoidCallback onOpen;
  final bool showMerchant;

  Future<void> _openWhatsApp() async {
    await launchUrl(
      Uri.parse(customer.whatsappUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Color get _rowColor {
    switch (customer.status) {
      case CustomerStatus.completed:
        return const Color(0xFF0E8A61).withValues(alpha: 0.18);
      case CustomerStatus.inactive:
        return const Color(0xFFE53935).withValues(alpha: 0.16);
      case CustomerStatus.active:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellStyle = AppTheme.text(
      color: AppTheme.basic,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: _rowColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                _cell(
                  flex: 5,
                  child: Opacity(
                    opacity: 0.4,
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      textAlign: TextAlign.center,
                      style: AppTheme.text(
                        color: AppTheme.basic,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _cell(
                  flex: 7,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.userAvatar,
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
                _cell(
                  flex: 11,
                  child: Text(
                    customer.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle,
                  ),
                ),
                if (showMerchant)
                  _cell(
                    flex: 10,
                    child: Text(
                      customer.merchantName ?? '—',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cellStyle,
                    ),
                  ),
                _cell(
                  flex: 10,
                  child: Text(
                    customer.phone,
                    textAlign: TextAlign.center,
                    style: AppTheme.text(
                      color: AppTheme.phone,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.phone,
                    ),
                  ),
                ),
                _cell(
                  flex: 8,
                  child: Text(
                    customer.governorate,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(customer.registrationDate),
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    money(customer.totalAmount),
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 7,
                  child: Text(
                    '${customer.monthsCount}',
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 8,
                  child: Text(
                    '${customer.remainingMonths}',
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    money(customer.monthlyPayment),
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 10,
                  child: Text(
                    money(customer.remainingAmount),
                    textAlign: TextAlign.center,
                    style: cellStyle,
                  ),
                ),
                _cell(
                  flex: 9,
                  child: Center(
                    child: AppointmentStatusChip(status: customer.status),
                  ),
                ),
                _cell(
                  flex: 11,
                  child: Center(
                    child: SizedBox(
                      height: 34,
                      child: FilledButton.icon(
                        onPressed: _openWhatsApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 14),
                        label: Text(
                          'واتساب',
                          style: AppTheme.text(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  Widget _cell({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: child,
      ),
    );
  }
}
