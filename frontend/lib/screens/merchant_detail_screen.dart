import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import '../models/customer.dart';
import '../models/merchant.dart';
import '../models/page_result.dart';
import '../services/api_service.dart';
import '../utils/app_dialog.dart';
import '../utils/format.dart';
import '../widgets/infinite_scroll.dart';
import 'add_merchant_screen.dart';
import 'customer_detail_screen.dart';

Future<bool?> showMerchantDetailDialog(
  BuildContext context, {
  required ApiService api,
  required Merchant merchant,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => MerchantDetailDialog(api: api, merchant: merchant),
  );
}

class MerchantDetailDialog extends StatefulWidget {
  const MerchantDetailDialog({
    super.key,
    required this.api,
    required this.merchant,
  });

  final ApiService api;
  final Merchant merchant;

  @override
  State<MerchantDetailDialog> createState() => _MerchantDetailDialogState();
}

class _MerchantDetailDialogState extends State<MerchantDetailDialog> {
  static const _pageSize = 10;

  late Merchant _merchant;
  PageResult<Customer> _plansPage = PageResult.empty(pageSize: _pageSize);
  int _activePlansCount = 0;
  int _completedPlansCount = 0;
  bool _loading = true;
  bool _loadingMorePlans = false;
  bool _confirmingDues = false;
  String? _error;
  bool _changed = false;

  List<Customer> get _plans => _plansPage.items;
  bool get _hasMorePlans => _plansPage.hasNext;

  static const _headerBlue = Color(0xFFD7EEF8);
  static const _fieldBorder = Color(0xFFD5E8F2);
  static const _sectionBg = Color(0xFFF7FBFD);
  static const _actionBlue = Color(0xFF1E88C8);
  static const _titleBlue = Color(0xFF0B3A5C);
  static const _whatsappGreen = Color(0xFF25D366);
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _merchant = widget.merchant;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final merchant = await widget.api.getMerchant(widget.merchant.id);
      final plansFuture = widget.api.getCustomers(
        merchantId: widget.merchant.id,
        page: 1,
        pageSize: _pageSize,
      );
      final activeFuture = widget.api.getCustomers(
        merchantId: widget.merchant.id,
        status: CustomerStatus.active,
        page: 1,
        pageSize: 1,
      );
      final inactiveFuture = widget.api.getCustomers(
        merchantId: widget.merchant.id,
        status: CustomerStatus.inactive,
        page: 1,
        pageSize: 1,
      );
      final completedFuture = widget.api.getCustomers(
        merchantId: widget.merchant.id,
        status: CustomerStatus.completed,
        page: 1,
        pageSize: 1,
      );
      final plans = await plansFuture;
      final active = await activeFuture;
      final inactive = await inactiveFuture;
      final completed = await completedFuture;
      if (!mounted) return;
      setState(() {
        _merchant = merchant;
        _plansPage = plans;
        _loadingMorePlans = false;
        _activePlansCount = active.total + inactive.total;
        _completedPlansCount = completed.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsApp() async {
    final url = whatsappUrl(_merchant.phone);
    if (url == null) return;
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  Future<void> _confirmDues() async {
    if (_confirmingDues || _merchant.dueConfirmedThisMonth) return;
    if (_merchant.dueThisMonthAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مستحقات معلقة للتأكيد')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'تأكيد استلام المستحقات',
            style: AppTheme.text(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'سيتم تعليم التاجر مستلماً لدفعته النقدية الظاهرة (${money(_merchant.dueThisMonthAmount)} د.ع)${_merchant.dueCarriedAmount > 0 ? ' مع المبالغ المرحلة من أشهر سابقة' : ''}. مستحقات التاجر تُصرف دفعة واحدة نقداً يوم 1 من الشهر التالي لاعتماد الزبون.',
            style: AppTheme.text(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: AppTheme.text(
                  color: AppTheme.basic.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0E8A61),
              ),
              child: Text(
                'تأكيد الدفع',
                style: AppTheme.text(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _confirmingDues = true);
    try {
      final updated = await widget.api.confirmMerchantDues(_merchant.id);
      if (!mounted) return;
      setState(() {
        _merchant = updated;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد استلام المستحقات لهذا الشهر')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تأكيد المستحقات')),
      );
    } finally {
      if (mounted) setState(() => _confirmingDues = false);
    }
  }

  Future<void> _editMerchant() async {
    final changed = await showAddMerchantDialog(
      context,
      api: widget.api,
      merchant: _merchant,
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _openPlan(Customer c) async {
    await showCustomerDetailDialog(
      context,
      api: widget.api,
      customerId: c.id,
      isAdmin: true,
    );
    if (!mounted) return;
    _changed = true;
    await _load();
  }

  Future<void> _loadMorePlans() async {
    if (_loadingMorePlans || _loading || !_hasMorePlans) return;
    setState(() => _loadingMorePlans = true);
    try {
      final next = await widget.api.getCustomers(
        merchantId: widget.merchant.id,
        page: _plansPage.page + 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _plansPage = _plansPage.appended(next);
        _loadingMorePlans = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMorePlans = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.72).clamp(860.0, 1080.0);
    final height = (size.height * 0.9).clamp(640.0, 920.0);

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
                            child: CircularProgressIndicator(color: _actionBlue),
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
                            : _buildBody(),
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
      height: 150,
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
              child: InkWell(
                onTap: () => Navigator.pop(context, _changed),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملف التاجر',
                  style: AppTheme.text(
                    color: _titleBlue,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'معلومات التاجر وخطط زبائنه وإحصائياته',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(),
          const SizedBox(height: 14),
          _statsRow(),
          const SizedBox(height: 14),
          _percentsRow(),
          const SizedBox(height: 14),
          _dueThisMonthCard(),
          const SizedBox(height: 14),
          _plansSection(),
        ],
      ),
    );
  }

  Widget _infoCard() {
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon: Icons.person_outline_rounded,
                  label: 'الاسم',
                  value: _merchant.fullName,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _infoItem(
                  icon: Icons.phone_outlined,
                  label: 'رقم الهاتف',
                  value: _merchant.phone.isEmpty ? '—' : _merchant.phone,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _infoItem(
                  icon: Icons.location_on_outlined,
                  label: 'المحافظة',
                  value: _merchant.governorate.isEmpty
                      ? '—'
                      : _merchant.governorate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE3F0F7)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon: Icons.home_outlined,
                  label: 'العنوان',
                  value: _merchant.address.isEmpty ? '—' : _merchant.address,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _infoItem(
                  icon: Icons.credit_card_outlined,
                  label: 'رقم الماستر',
                  value: _merchant.masterCard.isEmpty
                      ? '—'
                      : _merchant.masterCard,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _infoItem(
                  icon: Icons.badge_outlined,
                  label: 'اسم المستخدم',
                  value: _merchant.username,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _editMerchant,
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
                    onPressed: _merchant.phone.isEmpty ? null : _openWhatsApp,
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
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'عدد الخطط',
            value: '${_merchant.customersCount}',
            icon: Icons.folder_copy_outlined,
            background: const Color(0xFFE8F3FB),
            iconColor: const Color(0xFF1E88C8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'الخطط النشطة',
            value: '$_activePlansCount',
            icon: Icons.timelapse_rounded,
            background: const Color(0xFFEAF6FB),
            iconColor: const Color(0xFF069BAF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'الخطط المكتملة',
            value: '$_completedPlansCount',
            icon: Icons.check_circle_outline,
            background: const Color(0xFFE7F7EF),
            iconColor: const Color(0xFF0E8A61),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'إجمالي الخطط',
            value: '${money(_merchant.totalAmounts)} د.ع',
            icon: Icons.monetization_on_outlined,
            background: const Color(0xFFF3ECFB),
            iconColor: const Color(0xFF7B4DB8),
          ),
        ),
      ],
    );
  }

  Widget _percentsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'نسبة المصرف',
            value: '${_merchant.bankPercent}%  •  ${money(_merchant.bankAmounts)} د.ع',
            icon: Icons.account_balance_outlined,
            background: const Color(0xFFE8F3FB),
            iconColor: const Color(0xFF1E88C8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'نسبة المنصة',
            value:
                '${_merchant.platformPercent}%  •  ${money(_merchant.platformAmounts)} د.ع',
            icon: Icons.storefront_outlined,
            background: const Color(0xFFE7F7EF),
            iconColor: const Color(0xFF0E8A61),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'نسبة المستثمر',
            value:
                '${_merchant.investorPercent}%  •  ${money(_merchant.investorAmounts)} د.ع',
            icon: Icons.savings_outlined,
            background: const Color(0xFFF7EFDC),
            iconColor: const Color(0xFFC38508),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'المسدد من الأقساط',
            value: '${money(_merchant.paidAmounts)} د.ع',
            icon: Icons.payments_outlined,
            background: const Color(0xFFEAF6FB),
            iconColor: const Color(0xFF069BAF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'المتبقي على الزبائن',
            value: '${money(_merchant.remainingAmounts)} د.ع',
            icon: Icons.pending_actions_outlined,
            background: const Color(0xFFFDECEC),
            iconColor: const Color(0xFFE53935),
          ),
        ),
      ],
    );
  }

  Widget _dueThisMonthCard() {
    final confirmed = _merchant.dueConfirmedThisMonth;
    final hasAmount = _merchant.dueThisMonthAmount > 0;
    final carried = _merchant.dueCarriedAmount;
    final label = carried > 0
        ? 'دفعة نقدية معلّقة (${_merchant.dueThisMonthCount} زبون) • مرحّل ${money(carried)} د.ع'
        : 'دفعة نقدية مستحقة يوم 1 (${_merchant.dueThisMonthCount} زبون)';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_outlined,
                      size: 18,
                      color: Color(0xFFC38508),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
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
                const SizedBox(height: 10),
                Text(
                  '${money(_merchant.dueThisMonthAmount)} د.ع',
                  style: AppTheme.text(
                    color: _titleBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 42,
            child: confirmed
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F7EF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF9AD4B8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Color(0xFF0E8A61),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تم التأكيد',
                          style: AppTheme.text(
                            color: const Color(0xFF0E8A61),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    onPressed: (!hasAmount || _confirmingDues)
                        ? null
                        : _confirmDues,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E8A61),
                      disabledBackgroundColor: const Color(0xFFB7D7C8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _confirmingDues
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      'تأكيد الدفع',
                      style: AppTheme.text(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _plansSection() {
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
                  'خطط الزبائن',
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
                const Spacer(),
                Text(
                  '${_plansPage.total} خطة',
                  style: AppTheme.text(
                    color: AppTheme.basic.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _tableHeader(),
          SizedBox(
            height: 320,
            child: _plans.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد خطط زبائن لهذا التاجر بعد',
                      style: AppTheme.text(
                        color: AppTheme.basic.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : InfiniteScroll(
                    hasMore: _hasMorePlans,
                    loadingMore: _loadingMorePlans,
                    onLoadMore: _loadMorePlans,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _plans.length + 1,
                      itemBuilder: (_, i) {
                        if (i >= _plans.length) {
                          return InfiniteScrollFooter(
                            loadingMore: _loadingMorePlans,
                            hasMore: _hasMorePlans,
                            total: _plansPage.total,
                          );
                        }
                        return _planRow(
                          index: i + 1,
                          customer: _plans[i],
                          striped: i.isOdd,
                        );
                      },
                    ),
                  ),
          ),
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
          _headerCell('#', flex: 1),
          _headerCell('الزبون', flex: 3),
          _headerCell('الهاتف', flex: 3),
          _headerCell('المبلغ الكلي', flex: 3),
          _headerCell('مستحق التاجر', flex: 3),
          _headerCell('صرف التاجر', flex: 3),
          _headerCell('أشهر الزبون', flex: 2),
          _headerCell('قسط الزبون', flex: 3),
          _headerCell('المتبقي على الزبون', flex: 3),
          _headerCell('الحالة', flex: 2),
          _headerCell('التسجيل', flex: 3),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
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
    );
  }

  Widget _planRow({
    required int index,
    required Customer customer,
    required bool striped,
  }) {
    final statusLabel = switch (customer.status) {
      CustomerStatus.completed => 'مكتملة',
      CustomerStatus.inactive => 'غير نشطة',
      CustomerStatus.pending => 'بانتظار الموافقة',
      CustomerStatus.rejected => 'مرفوضة',
      CustomerStatus.active => 'نشطة',
    };
    final statusColor = switch (customer.status) {
      CustomerStatus.completed => const Color(0xFF0E8A61),
      CustomerStatus.inactive => const Color(0xFFE53935),
      CustomerStatus.rejected => const Color(0xFFE53935),
      CustomerStatus.pending => const Color(0xFFC38508),
      CustomerStatus.active => const Color(0xFF1E88C8),
    };

    return Material(
      color: striped ? const Color(0xFFF3FAFD) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openPlan(customer),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
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
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  customer.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  customer.phone,
                  textAlign: TextAlign.center,
                  style: AppTheme.text(
                    color: AppTheme.phone,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  money(customer.totalAmount),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  money(customer.financedAmount),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  customer.firstDueDate == null
                      ? '—'
                      : _dateFmt.format(customer.firstDueDate!),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${customer.monthsCount}',
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  money(customer.monthlyPayment),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  money(customer.remainingAmount),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTheme.text(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _dateFmt.format(customer.registrationDate),
                  textAlign: TextAlign.center,
                  style: AppTheme.text(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFDDEAF1),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
}
