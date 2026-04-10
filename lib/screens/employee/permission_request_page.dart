import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/requests_service.dart';
import '../../l10n/app_locale.dart';

class PermissionRequestPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const PermissionRequestPage({super.key, required this.user});
  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  final _svc = RequestsService();
  String _permType = L.tr('early_departure');
  DateTime _date = DateTime.now();
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _types = [L.tr('early_departure'), L.tr('attendance_lateness')];

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? (_fromTime ?? TimeOfDay.now()) : (_toTime ?? TimeOfDay.now()),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: C.pri)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => isFrom ? _fromTime = picked : _toTime = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: C.pri, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? L.tr('am') : L.tr('pm');
    return '${h.toString().padLeft(2, '0')}:$m $p';
  }

  void _submit() async {
    if (_fromTime == null || _toTime == null) {
      setState(() => _error = L.tr('select_start_end_time'));
      return;
    }
    final fromMin = _fromTime!.hour * 60 + _fromTime!.minute;
    final toMin = _toTime!.hour * 60 + _toTime!.minute;
    if (toMin <= fromMin) {
      setState(() => _error = L.tr('end_after_start_time'));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = L.tr('reason_required'));
      return;
    }
    if (_reasonCtrl.text.trim().length > 500) {
      setState(() => _error = L.tr('reason_too_long'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final result = await _svc.createPermissionRequest(
        uid: widget.user['uid'] ?? '',
        empId: widget.user['empId'] ?? '',
        name: widget.user['name'] ?? '',
        permType: L.toServerValue(_permType),
        fromTime: _fmtTime(_fromTime!),
        toTime: _fmtTime(_toTime!),
        date: _date,
        reason: _reasonCtrl.text.trim(),
        fromMinutes: _fromTime!.hour * 60 + _fromTime!.minute,
        toMinutes: _toTime!.hour * 60 + _toTime!.minute,
      );

      if (result['success'] == true && mounted) {
        final hours = (result['hours'] as num?)?.toStringAsFixed(1) ?? '0';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.tr('permission_sent', args: {'hours': hours.toString()}), style: GoogleFonts.tajawal()),
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
    final dateFmt = DateFormat('dd MMM yyyy', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(L.tr('permission_request'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
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
          // ─── نوع الإذن ───
          _sectionLabel(L.tr('permission_type')),
          Row(children: _types.map((t) => Expanded(child: Padding(
            padding: EdgeInsets.only(left: t == _types.last ? 0 : 8),
            child: _typeCard(t, _permType == t, () => setState(() => _permType = t)),
          ))).toList()),
          const SizedBox(height: 20),

          // ─── التاريخ ───
          _sectionLabel(L.tr('date')),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: C.pri),
                const SizedBox(width: 8),
                Text(dateFmt.format(_date), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ─── الوقت ───
          _sectionLabel(L.tr('time')),
          Row(children: [
            Expanded(child: _timeCard(L.tr('to'), _toTime, () => _pickTime(false))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_back, size: 16, color: C.hint)),
            Expanded(child: _timeCard(L.tr('from'), _fromTime, () => _pickTime(true))),
          ]),
          const SizedBox(height: 20),

          // ─── السبب ───
          _sectionLabel(L.tr('reason')),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            style: GoogleFonts.tajawal(fontSize: 14, color: C.text),
            decoration: InputDecoration(
              hintText: L.tr('write_permission_reason'),
              hintStyle: GoogleFonts.tajawal(color: C.hint),
              filled: true, fillColor: C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.pri, width: 2)),
            ),
          ),
          const SizedBox(height: 20),

          if (_error != null) Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.redL, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.redBd)),
            child: Text(_error!, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: C.red), textAlign: TextAlign.right),
          ),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
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

  Widget _typeCard(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(DS.radiusMd),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? C.orange.withOpacity(0.08) : C.white,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        Icon(label.contains(L.tr('departure')) ? Icons.logout : Icons.access_time, size: 22, color: selected ? C.orange : C.muted),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? C.orange : C.sub)),
      ]),
    ),
  );

  Widget _timeCard(String label, TimeOfDay? time, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(DS.radiusMd),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(DS.radiusMd), border: Border.all(color: C.border)),
      child: Column(children: [
        Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: C.muted)),
        const SizedBox(height: 6),
        Icon(Icons.access_time, size: 18, color: time != null ? C.orange : C.hint),
        const SizedBox(height: 4),
        Text(time != null ? _fmtTime(time) : L.tr('select_time'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: time != null ? C.text : C.hint)),
      ]),
    ),
  );
}
