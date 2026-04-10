import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';
import '../../l10n/app_locale.dart';

class LeaveRequestPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const LeaveRequestPage({super.key, required this.user});
  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _svc = RequestsService();
  String _leaveType = L.tr('annual');
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _types = [L.tr('annual'), L.tr('sick'), L.tr('emergency'), L.tr('unpaid')];

  int get _days => (_startDate != null && _endDate != null)
      ? _endDate!.difference(_startDate!).inDays + 1
      : 0;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: C.pri, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submit() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = L.tr('select_start_end_date'));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = L.tr('end_after_start_date'));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = L.tr('leave_reason_required'));
      return;
    }
    if (_reasonCtrl.text.trim().length > 500) {
      setState(() => _error = L.tr('reason_too_long'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final result = await _svc.createLeaveRequest(
        uid: widget.user['uid'] ?? '',
        empId: widget.user['empId'] ?? '',
        name: widget.user['name'] ?? '',
        leaveType: L.toServerValue(_leaveType),
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonCtrl.text.trim(),
      );

      if (result['success'] == true && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.tr('leave_sent'), style: GoogleFonts.tajawal()),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() { _error = L.tr('request_error'); _loading = false; });
    }
  }

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(L.tr('leave_request'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
        centerTitle: true,
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: C.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // ─── نوع الإجازة ───
          _sectionLabel(L.tr('leave_type')),
          Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
            children: _types.map((t) => _chip(t, _leaveType == t, () => setState(() => _leaveType = t))).toList(),
          ),
          const SizedBox(height: 20),

          // ─── التواريخ ───
          _sectionLabel(L.tr('leave_date')),
          Row(children: [
            Expanded(child: _dateCard(L.tr('to'), _endDate, () => _pickDate(false))),
            const SizedBox(width: 10),
            Expanded(child: _dateCard(L.tr('from'), _startDate, () => _pickDate(true))),
          ]),
          if (_days > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)),
              child: Text(L.tr('leave_duration', args: {'days': _days.toString()}), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.pri)),
            ),
          ],
          const SizedBox(height: 20),

          // ─── السبب ───
          _sectionLabel(L.tr('leave_reason')),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 14, color: C.text),
            decoration: InputDecoration(
              hintText: L.tr('write_leave_reason'),
              hintStyle: GoogleFonts.tajawal(color: C.hint),
              filled: true, fillColor: C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.pri, width: 2)),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Error ───
          if (_error != null) Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.redBd)),
            child: Text(_error!, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.red), textAlign: TextAlign.right),
          ),

          // ─── Submit ───
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.send, size: 18),
                      const SizedBox(width: 8),
                      Text(L.tr('send_request'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? C.pri : C.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? C.pri : C.border),
      ),
      child: Text(label, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : C.sub)),
    ),
  );

  Widget _dateCard(String label, DateTime? date, VoidCallback onTap) {
    final fmt = DateFormat('dd MMM yyyy', 'ar');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
        child: Column(children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
          const SizedBox(height: 6),
          Icon(Icons.calendar_today_outlined, size: 18, color: date != null ? C.pri : C.hint),
          const SizedBox(height: 4),
          Text(date != null ? fmt.format(date) : L.tr('select_date'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: date != null ? C.text : C.hint)),
        ]),
      ),
    );
  }
}
