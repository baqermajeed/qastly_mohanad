import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.##', 'en');
final _date = DateFormat('yyyy-MM-dd');

String money(num value) => _money.format(value);
String formatDate(DateTime value) => _date.format(value);

DateTime firstDueDate(DateTime registration) {
  return DateTime(registration.year, registration.month + 1, 1);
}

DateTime addMonths(DateTime start, int months) {
  final index = start.month - 1 + months;
  final year = start.year + index ~/ 12;
  final month = index % 12 + 1;
  return DateTime(year, month, 1);
}

/// تاريخ القسط الأخير في جدول الخطة (ثابت): القسط رقم [monthsCount].
DateTime? lastDueDate({
  required DateTime? firstDue,
  required int monthsCount,
}) {
  if (firstDue == null || monthsCount <= 0) return null;
  return addMonths(firstDue, monthsCount - 1);
}

double installmentAmount({
  required double financedAmount,
  required int monthsCount,
  required double monthlyPayment,
  required int installmentNo,
}) {
  if (installmentNo < monthsCount) {
    return double.parse(monthlyPayment.toStringAsFixed(2));
  }
  return double.parse(
    (financedAmount - monthlyPayment * (monthsCount - 1)).toStringAsFixed(2),
  );
}

/// مبلغ القسط المستحق في شهر معيّن حسب جدول العقد.
double installmentDueInMonth({
  required DateTime firstDue,
  required int monthsCount,
  required double monthlyPayment,
  required double financedAmount,
  required DateTime month,
}) {
  if (monthsCount <= 0) return 0;
  final target = DateTime(month.year, month.month, 1);
  final start = DateTime(firstDue.year, firstDue.month, 1);
  final monthsDiff =
      (target.year - start.year) * 12 + (target.month - start.month);
  if (monthsDiff < 0 || monthsDiff >= monthsCount) return 0;
  return installmentAmount(
    financedAmount: financedAmount,
    monthsCount: monthsCount,
    monthlyPayment: monthlyPayment,
    installmentNo: monthsDiff + 1,
  );
}

String formatDayMonth(DateTime value) =>
    DateFormat('dd/MM/yyyy').format(value);

String? whatsappUrl(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('0')) {
    digits = '964${digits.substring(1)}';
  }
  digits = digits.replaceFirst(RegExp(r'^\+'), '');
  if (digits.isEmpty) return null;
  return 'https://wa.me/$digits';
}

/// Removes thousand separators so values can be parsed.
String stripMoney(String value) => value.replaceAll(',', '').trim();

double? parseMoney(String? value) {
  if (value == null) return null;
  return double.tryParse(stripMoney(value));
}

String? validatePatientName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'أدخل الاسم';

  // حروف عربية/إنجليزية ومسافات فقط
  if (!RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$').hasMatch(name)) {
    return 'الاسم يجب أن يحتوي على حروف فقط';
  }

  final parts =
      name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 3) {
    return 'الاسم يجب أن يكون ثلاثياً أو أكثر';
  }
  return null;
}

String? validateIraqiPhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return 'أدخل رقم الهاتف';
  if (!RegExp(r'^07\d{9}$').hasMatch(phone)) {
    return 'رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07';
  }
  return null;
}

/// Formats amount input with thousand separators while typing.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Allow digits and at most one decimal point.
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : null;

    final formattedInt = intPart.isEmpty
        ? ''
        : NumberFormat('#,##0', 'en').format(int.parse(intPart));

    final formatted = decPart == null
        ? (raw.endsWith('.') ? '$formattedInt.' : formattedInt)
        : '$formattedInt.$decPart';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
