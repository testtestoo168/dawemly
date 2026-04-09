import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

class SaOrganizations extends StatefulWidget {
  const SaOrganizations({super.key});
  @override
  State<SaOrganizations> createState() => _SaOrganizationsState();
}

class _SaOrganizationsState extends State<SaOrganizations> {
  bool _loading = true;
  List<Map<String, dynamic>> _orgs = [];
  Map<String, dynamic>? _selectedOrg;
  Map<String, dynamic>? _orgDetails;
  List<Map<String, dynamic>> _orgUsers = [];
  List<Map<String, dynamic>> _orgBranches = [];
  bool _loadingDetails = false;

  TextStyle _tj(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('superadmin.php?action=organizations');
      if (res['success'] == true && mounted) {
        setState(() {
          _orgs = (res['organizations'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrgDetails(int orgId) async {
    setState(() => _loadingDetails = true);
    try {
      final res = await ApiService.get('superadmin.php?action=org_details', params: {'id': '$orgId'});
      if (res['success'] == true && mounted) {
        setState(() {
          _orgDetails = (res['organization'] as Map<String, dynamic>?) ?? {};
          _orgUsers = (res['users'] as List? ?? []).cast<Map<String, dynamic>>();
          _orgBranches = (res['branches'] as List? ?? []).cast<Map<String, dynamic>>();
          _loadingDetails = false;
        });
      } else {
        if (mounted) setState(() => _loadingDetails = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _toggleOrg(int orgId) async {
    final res = await ApiService.post('superadmin.php?action=toggle_org', {'id': orgId});
    if (res['success'] == true) {
      _loadOrgs();
      if (_selectedOrg != null && (_selectedOrg!['id'] as int?) == orgId) {
        _loadOrgDetails(orgId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(textDirection: TextDirection.rtl, children: [
      // ─── Orgs list ───
      SizedBox(
        width: _selectedOrg != null ? 420 : double.infinity,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(children: [
              Text('المؤسسات (${_orgs.length})', style: _tj(18, weight: FontWeight.w700, color: W.text)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadOrgs,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('تحديث', style: _tj(12, weight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: W.pri,
                  side: BorderSide(color: W.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ]),
          ),
          // List
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _orgs.length,
            itemBuilder: (ctx, i) {
              final org = _orgs[i];
              final isActive = org['active'] == 1 || org['active'] == true;
              final isSelected = _selectedOrg != null && _selectedOrg!['id'] == org['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? W.priLight : Colors.white,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(color: isSelected ? W.pri : W.border),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedOrg = org);
                    _loadOrgDetails(org['id'] as int);
                  },
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      // Org icon
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        child: Icon(Icons.business_rounded, size: 22,
                          color: isActive ? const Color(0xFF17B26A) : const Color(0xFFF04438)),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(org['name'] ?? '', style: _tj(15, weight: FontWeight.w700, color: W.text)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.people_outline_rounded, size: 14, color: W.muted),
                          const SizedBox(width: 4),
                          Text('${org['current_employees'] ?? 0} موظف', style: _tj(12, color: W.sub)),
                          const SizedBox(width: 12),
                          Icon(Icons.person_outline_rounded, size: 14, color: W.muted),
                          const SizedBox(width: 4),
                          Text('${org['current_admins'] ?? 0} مدير', style: _tj(12, color: W.sub)),
                          const SizedBox(width: 12),
                          Icon(Icons.store_outlined, size: 14, color: W.muted),
                          const SizedBox(width: 4),
                          Text('${org['current_branches'] ?? 0} فرع', style: _tj(12, color: W.sub)),
                        ]),
                      ])),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(DS.radiusPill),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'معطل',
                          style: _tj(11, weight: FontWeight.w600,
                            color: isActive ? const Color(0xFF17B26A) : const Color(0xFFF04438)),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          )),
        ]),
      ),

      // ─── Detail panel ───
      if (_selectedOrg != null) ...[
        Container(width: 1, color: W.border),
        Expanded(child: _buildDetailPanel()),
      ],
    ]);
  }

  Widget _buildDetailPanel() {
    if (_loadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orgDetails == null) {
      return Center(child: Text('اختر مؤسسة لعرض التفاصيل', style: _tj(14, color: W.muted)));
    }

    final org = _orgDetails!;
    final isActive = org['active'] == 1 || org['active'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          IconButton(
            onPressed: () => setState(() { _selectedOrg = null; _orgDetails = null; }),
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: W.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(org['name'] ?? '', style: _tj(20, weight: FontWeight.w800, color: W.text)),
            if ((org['name_en'] ?? '').toString().isNotEmpty)
              Text(org['name_en'], style: _tj(13, color: W.sub)),
          ])),
          // Toggle button
          OutlinedButton.icon(
            onPressed: () => _toggleOrg(org['id'] as int),
            icon: Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
            label: Text(isActive ? 'تعطيل' : 'تفعيل', style: _tj(12, weight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: isActive ? W.red : W.green,
              side: BorderSide(color: isActive ? W.redBd : W.greenBd),
              backgroundColor: isActive ? W.redL : W.greenL,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Info cards
        Container(
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('معلومات المؤسسة', style: _tj(15, weight: FontWeight.w700, color: W.text)),
            const SizedBox(height: 16),
            _infoRow('البريد', org['email'] ?? '-'),
            _infoRow('الهاتف', org['phone'] ?? '-'),
            _infoRow('العنوان', org['address'] ?? '-'),
            _infoRow('الحد الأقصى للموظفين', '${org['max_employees'] ?? '-'}'),
            _infoRow('الباقة', org['plan_name'] ?? 'بدون باقة'),
            _infoRow('بداية الاشتراك', org['subscription_start'] ?? '-'),
            _infoRow('نهاية الاشتراك', org['subscription_end'] ?? '-'),
            _infoRow('تاريخ الإنشاء', org['created_at'] ?? '-'),
          ]),
        ),
        const SizedBox(height: 16),

        // Users
        Container(
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('المستخدمون (${_orgUsers.length})', style: _tj(15, weight: FontWeight.w700, color: W.text)),
            ]),
            const SizedBox(height: 12),
            if (_orgUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('لا يوجد مستخدمون', style: _tj(13, color: W.muted))),
              )
            else
              ..._orgUsers.map((u) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: u['role'] == 'admin' ? const Color(0xFFF4F3FF) : W.priLight,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: Center(child: Text(
                      (u['name'] ?? 'م').toString().substring(0, (u['name'] ?? 'م').toString().length >= 2 ? 2 : 1),
                      style: _tj(12, weight: FontWeight.w700, color: u['role'] == 'admin' ? const Color(0xFF7F56D9) : W.pri),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: W.text)),
                    Text('${u['email'] ?? ''} | ${u['emp_id'] ?? ''}', style: _tj(11, color: W.muted)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: u['role'] == 'admin' ? const Color(0xFFF4F3FF) : W.priLight,
                      borderRadius: BorderRadius.circular(DS.radiusPill),
                    ),
                    child: Text(
                      u['role'] == 'admin' ? 'مدير' : 'موظف',
                      style: _tj(10, weight: FontWeight.w600, color: u['role'] == 'admin' ? const Color(0xFF7F56D9) : W.pri),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (u['active'] == 1 || u['active'] == true) ? W.green : W.red,
                    ),
                  ),
                ]),
              )),
          ]),
        ),
        const SizedBox(height: 16),

        // Branches
        Container(
          padding: const EdgeInsets.all(20),
          decoration: DS.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الفروع (${_orgBranches.length})', style: _tj(15, weight: FontWeight.w700, color: W.text)),
            const SizedBox(height: 12),
            if (_orgBranches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('لا توجد فروع', style: _tj(13, color: W.muted))),
              )
            else
              ..._orgBranches.map((b) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: W.div))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(DS.radiusSm)),
                    child: const Icon(Icons.store_rounded, size: 18, color: Color(0xFFF79009)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(b['name'] ?? '', style: _tj(13, weight: FontWeight.w600, color: W.text))),
                ]),
              )),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 160, child: Text(label, style: _tj(13, color: W.sub))),
        Expanded(child: Text(value, style: _tj(13, weight: FontWeight.w600, color: W.text))),
      ]),
    );
  }
}
