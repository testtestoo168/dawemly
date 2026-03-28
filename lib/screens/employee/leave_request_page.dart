import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';

class LeaveRequestPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const LeaveRequestPage({super.key, required this.user});
  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _svc = RequestsService();
  String _leaveType = 'سنوية';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _types = ['سنوية', 'مرضية', 'طارئة', 'بدون راتب'];

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
      setState(() => _error = 'يرجى تحديد تاريخ البداية والنهاية');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى كتابة سبب الإجازة');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final result = await _svc.createLeaveRequest(
        uid: widget.user['uid'] ?? '',
        empId: widget.user['empId'] ?? '',
        name: widget.user['name'] ?? '',
        leaveType: _leaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonCtrl.text.trim(),
      );

      if (result['success'] == true && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إرسال طلب الإجازة بنجاح (${result['days']} يوم)', style: GoogleFonts.tajawal()),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() { _error = 'حدث خطأ في إرسال الطلب'; _loading = false; });
    }
  }

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب إجازة', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
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
          _sectionLabel('نوع الإجازة'),
          Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
            children: _types.map((t) => _chip(t, _leaveType == t, () => setState(() => _leaveType = t))).toList(),
          ),
          const SizedBox(height: 20),

          // ─── التواريخ ───
          _sectionLabel('تاريخ الإجازة'),
          Row(children: [
            Expanded(child: _dateCard('إلى', _endDate, () => _pickDate(false))),
            const SizedBox(width: 10),
            Expanded(child: _dateCard('من', _startDate, () => _pickDate(true))),
          ]),
          if (_days > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.priLight, borderRadius: BorderRadius.circular(10)),
              child: Text('مدة الإجازة: $_days يوم', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: C.pri)),
            ),
          ],
          const SizedBox(height: 20),

          // ─── السبب ───
          _sectionLabel('سبب الإجازة'),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 14, color: C.text),
            decoration: InputDecoration(
              hintText: 'اكتب سبب الإجازة...',
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
                      Text('إرسال الطلب', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: date != null ? C.pri : C.border)),
        child: Column(children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
          const SizedBox(height: 6),
          Icon(Icons.calendar_today_outlined, size: 18, color: date != null ? C.pri : C.hint),
          const SizedBox(height: 4),
          Text(date != null ? fmt.format(date) : 'اختر التاريخ', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: date != null ? C.text : C.hint)),
        ]),
      ),
    );
  }
}
