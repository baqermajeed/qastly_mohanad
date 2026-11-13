import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/investor.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';

Future<bool?> showAddInvestorDialog(
  BuildContext context, {
  required ApiService api,
  Investor? investor,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => AddInvestorDialog(api: api, investor: investor),
  );
}

class AddInvestorDialog extends StatefulWidget {
  const AddInvestorDialog({super.key, required this.api, this.investor});

  final ApiService api;
  final Investor? investor;

  @override
  State<AddInvestorDialog> createState() => _AddInvestorDialogState();
}

class _AddInvestorDialogState extends State<AddInvestorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  static const _actionBlue = Color(0xFF1E88C8);
  static const _fieldBorder = Color(0xFFD5E8F2);

  bool get _editing => widget.investor != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.investor;
    if (inv != null) {
      _name.text = inv.fullName;
      _phone.text = inv.phone;
      _username.text = inv.username;
      _note.text = inv.note;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _username.dispose();
    _password.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.api.updateInvestor(
          id: widget.investor!.id,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text.trim().isEmpty ? null : _password.text,
          note: _note.text.trim(),
        );
      } else {
        await widget.api.createInvestor(
          username: _username.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          note: _note.text.trim(),
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
    final width = (size.width * 0.5).clamp(520.0, 680.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: size.height * 0.9),
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
                        _editing ? 'تعديل المستثمر' : 'إضافة مستثمر',
                        style: AppTheme.text(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'حساب دخول للمستثمر. العقود الاستثمارية تُضاف لاحقاً بشكل منفصل.',
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
                          controller: _name,
                          label: 'اسم المستثمر',
                          hint: 'الاسم الكامل',
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'أدخل الاسم'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
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
                        _field(
                          controller: _note,
                          label: 'ملاحظة (اختياري)',
                          hint: 'ملاحظات إدارية',
                          maxLines: 2,
                        ),
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
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: _fieldBorder),
                            foregroundColor: AppTheme.basic,
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
                              : Text(_editing ? 'حفظ التعديلات' : 'إضافة المستثمر'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscure = false,
    bool enabled = true,
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
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? const Color(0xFFF7FBFE) : const Color(0xFFF0F4F7),
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
