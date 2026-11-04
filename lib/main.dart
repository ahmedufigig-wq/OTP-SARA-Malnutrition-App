import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'data/app_database.dart';

const teal = Color(0xFF008080);
const mint = Color(0xFFE0F2F1);

void main() => runApp(const OtpSaraApp());

class OtpSaraApp extends StatelessWidget {
  const OtpSaraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'OTP SARA',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal, surface: Colors.white),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(backgroundColor: teal, foregroundColor: Colors.white, centerTitle: true),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E3E3))),
      ),
      useMaterial3: true,
    ),
    home: const Directionality(textDirection: ui.TextDirection.rtl, child: PatientHome()),
  );
}

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});
  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نظام OTP / SARA'), actions: [
      IconButton(tooltip: 'حول التطبيق', onPressed: () => showAboutDialog(context: context, applicationName: 'OTP SARA', applicationVersion: '1.0.0'), icon: const Icon(Icons.info_outline))
    ]),
    body: tab == 0 ? const PatientForm() : const PatientsList(),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.person_add_alt_1), label: 'تسجيل طفل'),
        NavigationDestination(icon: Icon(Icons.folder_shared), label: 'السجلات'),
      ],
    ),
  );
}

class PatientForm extends StatefulWidget {
  const PatientForm({super.key});
  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  final formKey = GlobalKey<FormState>();
  final controllers = List.generate(10, (_) => TextEditingController());
  DateTime admission = DateTime.now();
  String gender = 'ذكر', twins = 'لا', zScore = 'أقل من -3', admissionType = 'جديد', outcome = 'مستمر';
  bool saving = false;
  final Set<String> reasons = {};
  final List<String> reasonOptions = ['MUAC منخفض','Z-score منخفض','وذمة تغذوية','تحويل من مرفق صحي','انتكاسة / تدهور الحالة'];
  String get visitDate => DateFormat('yyyy-MM-dd').format(admission.add(const Duration(days: 7)));
  String get admissionDate => DateFormat('yyyy-MM-dd').format(admission);

  @override
  void dispose() { for (final c in controllers) { c.dispose(); } super.dispose(); }

  String? requiredText(String? v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;
  double? numeric(String s) => double.tryParse(s.trim());

  Widget field(String label, int index, {bool required = false, TextInputType type = TextInputType.text, String? hint}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
      controller: controllers[index], keyboardType: type,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required ? requiredText : null,
    ));

  Widget section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: teal)),
        const Divider(height: 22), ...children,
      ],
    )),
  );

  Future<void> pickAdmission() async {
    final picked = await showDatePicker(context: context, initialDate: admission, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => admission = picked);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final age = int.tryParse(controllers[2].text);
    final weight = numeric(controllers[6].text), height = numeric(controllers[7].text), muac = numeric(controllers[8].text);
    if (age == null || age < 0 || age > 59 || weight == null || weight <= 0 || height == null || height <= 0 || muac == null || muac <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من العمر والوزن والطول ومحيط منتصف العضد')));
      return;
    }
    setState(() => saving = true);
    try {
      await AppDatabase.instance.insertPatient({
        'sam_number': controllers[0].text.trim(),
        'child_name': controllers[1].text.trim(),
        'age_months': age, 'gender': gender,
        'phone': controllers[3].text.trim(),
        'governorate': controllers[4].text.trim(),
        'district': controllers[5].text.trim(),
        'village': controllers[9].text.trim(),
        'admission_date': admissionDate, 'visit_date': visitDate,
        'twins': twins, 'weight_kg': weight, 'height_cm': height,
        'z_score': zScore, 'muac_cm': muac,
        'admission_reasons': reasons.join('، '), 'admission_type': admissionType, 'outcome': outcome,
      });
      for (final c in controllers) { c.clear(); }
      setState(() { admission = DateTime.now(); reasons.clear(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سجل الطفل بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: قد يكون رقم SAM مسجلاً مسبقاً. $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: ListView(padding: const EdgeInsets.all(14), children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [Icon(Icons.health_and_safety, color: teal, size: 32), SizedBox(width: 12), Expanded(child: Text('استمارة تسجيل ومتابعة حالات سوء التغذية الحاد', style: TextStyle(fontWeight: FontWeight.bold, color: teal)))])),
      const SizedBox(height: 14),
      section('القسم A — بيانات الطفل', [
        field('رقم SAM', 0, required: true),
        field('اسم الطفل رباعياً', 1, required: true),
        field('العمر بالشهر (0–59)', 2, required: true, type: TextInputType.number),
        DropdownButtonFormField<String>(initialValue: gender, decoration: const InputDecoration(labelText: 'الجنس'), items: ['ذكر','أنثى'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>gender=v!)),
        field('رقم الهاتف', 3, type: TextInputType.phone),
        field('المحافظة / المديرية', 4),
        field('العزلة', 5),
        field('القرية أو الشارع', 9),
      ]),
      section('القسم B — بيانات الزيارة والقياسات', [
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('تاريخ القبول'), subtitle: Text(admissionDate), trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: pickAdmission)),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.event_available, color: teal), const SizedBox(width: 10), Expanded(child: Text('موعد المتابعة بعد 7 أيام: $visitDate', style: const TextStyle(fontWeight: FontWeight.bold, color: teal)))])),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: twins, decoration: const InputDecoration(labelText: 'هل الطفل من التوائم؟'), items: ['لا','نعم'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>twins=v!)),
        field('الوزن (كجم)', 6, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
        field('الطول (سم)', 7, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
        DropdownButtonFormField<String>(initialValue: zScore, decoration: const InputDecoration(labelText: 'Z-score'), items: ['أقل من -3','من -3 إلى -2'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>zScore=v!)),
        field('MUAC — محيط منتصف العضد (سم)', 8, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
      ]),
      section('القسم C — القبول والخروج', [
        const Text('أسباب القبول', style: TextStyle(fontWeight: FontWeight.w600)),
        ...reasonOptions.map((reason) => CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(reason), value: reasons.contains(reason), onChanged: (checked) => setState(() { if (checked == true) { reasons.add(reason); } else { reasons.remove(reason); } }))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: admissionType, decoration: const InputDecoration(labelText: 'نوع القبول'), items: ['جديد','إعادة قبول','تحويل داخلي'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>admissionType=v!)),
        DropdownButtonFormField<String>(initialValue: outcome, decoration: const InputDecoration(labelText: 'حالة الخروج / التحويل'), items: ['مستمر','تعافٍ','تحويل خارجي','تغيب','وفاة','غير ذلك'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>outcome=v!)),
      ]),
      FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.save), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ سجل الطفل'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 24),
    ]),
  );
}


class PatientsList extends StatefulWidget {
  const PatientsList({super.key});
  @override
  State<PatientsList> createState() => _PatientsListState();
}

class _PatientsListState extends State<PatientsList> {
  final searchController = TextEditingController();
  late Future<List<Map<String,Object?>>> future;
  @override
  void initState() { super.initState(); _load(); }
  void _load() => future = AppDatabase.instance.getPatients(search: searchController.text);
  Future<void> _search(String value) async {
    final result = AppDatabase.instance.getPatients(search: value);
    setState(() => future = result);
  }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12,12,12,4), child: TextField(
      controller: searchController,
      onChanged: _search,
      decoration: InputDecoration(
        hintText: 'ابحث باسم الطفل أو رقم SAM',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { searchController.clear(); _search(''); }),
      ),
    )),
    Expanded(child: FutureBuilder<List<Map<String,Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return Center(child: Text(searchController.text.isEmpty ? 'لا توجد سجلات محفوظة بعد' : 'لا توجد نتائج مطابقة للبحث'));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context,i) {
          final p = rows[i];
          return Card(child: ListTile(
            leading: const CircleAvatar(backgroundColor:mint,child:Icon(Icons.child_care,color:teal)),
            title: Text('${p['child_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('SAM: ${p['sam_number']}  •  العمر: ${p['age_months']} شهر\\nآخر موعد متابعة: ${p['visit_date']}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetails(patientId: p['id'] as int)));
              if (mounted) _search(searchController.text);
            },
          ));
        });
      },
    )),
  ]);
}

class PatientDetails extends StatefulWidget {
  final int patientId;
  const PatientDetails({super.key, required this.patientId});
  @override
  State<PatientDetails> createState() => _PatientDetailsState();
}

class _PatientDetailsState extends State<PatientDetails> {
  late Future<void> loading;
  Map<String,Object?>? patient;
  List<Map<String,Object?>> visits = [];
  @override
  void initState() { super.initState(); loading = _load(); }
  Future<void> _load() async {
    patient = await AppDatabase.instance.getPatient(widget.patientId);
    visits = await AppDatabase.instance.getVisits(widget.patientId);
  }
  Future<void> _refresh() async {
    setState(() { loading = _load(); });
    await loading;
    if (mounted) setState(() {});
  }

  Future<void> _editPatient() async {
    if (patient == null) return;
    final name = TextEditingController(text: '${patient!['child_name'] ?? ''}');
    final sam = TextEditingController(text: '${patient!['sam_number'] ?? ''}');
    final age = TextEditingController(text: '${patient!['age_months'] ?? ''}');
    final phone = TextEditingController(text: '${patient!['phone'] ?? ''}');
    final gov = TextEditingController(text: '${patient!['governorate'] ?? ''}');
    final district = TextEditingController(text: '${patient!['district'] ?? ''}');
    final village = TextEditingController(text: '${patient!['village'] ?? ''}');
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل بيانات الطفل'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _editField(name, 'اسم الطفل'),
        _editField(sam, 'رقم SAM'),
        _editField(age, 'العمر بالشهر', number: true),
        _editField(phone, 'رقم الهاتف'),
        _editField(gov, 'المحافظة'),
        _editField(district, 'المديرية / العزلة'),
        _editField(village, 'القرية'),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          if (name.text.trim().isEmpty || sam.text.trim().isEmpty || int.tryParse(age.text) == null) return;
          Navigator.pop(dialogContext, true);
        }, child: const Text('حفظ التعديلات')),
      ],
    ));
    if (saved == true) {
      try {
        await AppDatabase.instance.updatePatient(widget.patientId, {
          'child_name': name.text.trim(), 'sam_number': sam.text.trim(),
          'age_months': int.parse(age.text), 'phone': phone.text.trim(),
          'governorate': gov.text.trim(), 'district': district.text.trim(), 'village': village.text.trim(),
        });
        await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التعديل: $e')));
      }
    }
    for (final c in [name,sam,age,phone,gov,district,village]) { c.dispose(); }
  }

  Widget _editField(TextEditingController c, String label, {bool number = false}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label)));

  Future<void> _editVisit([Map<String,Object?>? visit]) async {
    final weight = TextEditingController(text: visit == null ? '' : '${visit['weight_kg']}');
    final height = TextEditingController(text: visit == null ? '' : '${visit['height_cm']}');
    final muac = TextEditingController(text: visit == null || visit['muac_cm'] == null ? '' : '${visit['muac_cm']}');
    final zscore = TextEditingController(text: visit == null ? '' : '${visit['z_score'] ?? ''}');
    final notes = TextEditingController(text: visit == null ? '' : '${visit['notes'] ?? ''}');
    DateTime date = visit == null ? DateTime.now() : (DateTime.tryParse('${visit['visit_date']}') ?? DateTime.now());
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(visit == null ? 'إضافة زيارة جديدة' : 'تعديل بيانات الزيارة'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('تاريخ الزيارة'), subtitle: Text(DateFormat('yyyy-MM-dd').format(date)), trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
          final d = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setDialogState(() => date = d);
        })),
        _editField(weight, 'الوزن (كجم)', number: true),
        _editField(height, 'الطول (سم)', number: true),
        _editField(muac, 'MUAC (سم)', number: true),
        _editField(zscore, 'Z-score'),
        _editField(notes, 'ملاحظات الزيارة'),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          final w = double.tryParse(weight.text), h = double.tryParse(height.text);
          if (w == null || w <= 0 || h == null || h <= 0) return;
          Navigator.pop(dialogContext, true);
        }, child: const Text('حفظ')),
      ],
    )));
    if (saved == true) {
      final data = {
        'visit_date': DateFormat('yyyy-MM-dd').format(date),
        'weight_kg': double.parse(weight.text),
        'height_cm': double.parse(height.text),
        'muac_cm': double.tryParse(muac.text),
        'z_score': zscore.text.trim(),
        'notes': notes.text.trim(),
      };
      if (visit == null) {
        await AppDatabase.instance.addVisit(widget.patientId, data);
      } else {
        await AppDatabase.instance.updateVisit(visit['id'] as int, data);
      }
      await _refresh();
    }
    for (final c in [weight,height,muac,zscore,notes]) { c.dispose(); }
  }

  Future<void> _exportAndSharePdf() async {
    if (patient == null) return;
    try {
      final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();
      final arabicBold = await PdfGoogleFonts.notoNaskhArabicBold();
      final doc = pw.Document();
      final p = patient!;
      doc.addPage(pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('نظام OTP / SARA — سجل الطفل')),
          pw.Text('اسم الطفل: ${p['child_name']}'),
          pw.Text('رقم SAM: ${p['sam_number']}'),
          pw.Text('العمر: ${p['age_months']} شهر   |   الجنس: ${p['gender']}'),
          pw.Text('الهاتف: ${p['phone'] ?? '—'}'),
          pw.Text('الموقع: ${p['governorate'] ?? ''} / ${p['district'] ?? ''} / ${p['village'] ?? ''}'),
          pw.SizedBox(height: 12),
          pw.Text('سجل الزيارات والقياسات', style: pw.TextStyle(font: arabicBold, fontSize: 16)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['الزيارة','التاريخ','الوزن كجم','الطول سم','MUAC سم','Z-score','ملاحظات'],
            data: visits.map((v) => [
              '${visits.indexOf(v)+1}', '${v['visit_date']}', '${v['weight_kg']}',
              '${v['height_cm']}', '${v['muac_cm'] ?? '—'}',
              '${v['z_score'] ?? '—'}', '${v['notes'] ?? ''}',
            ]).toList(),
            headerStyle: pw.TextStyle(font: arabicBold, fontSize: 9),
            cellStyle: pw.TextStyle(font: arabicFont, fontSize: 8),
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: pw.PdfColors.teal100),
          ),
          pw.SizedBox(height: 12),
          pw.Text('ملاحظة: مؤشرات الارتفاع والانخفاض مقارنة رقمية بين الزيارات، ولا تغني عن التقييم السريري وفق بروتوكول البرنامج.', style: pw.TextStyle(font: arabicFont, fontSize: 9)),
          pw.SizedBox(height: 8),
          pw.Text('تاريخ إنشاء التقرير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: arabicFont, fontSize: 8)),
        ],
      ));
      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final safeName = '${p['sam_number']}'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/OTP_SARA_$safeName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'سجل الطفل ${p['child_name']} — OTP SARA',
        text: 'تقرير سجل الطفل بصيغة PDF',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء أو مشاركة PDF: $e')));
    }
  }

  Widget _trend(double? current, double? previous, String unit) {
    if (current == null || previous == null) return const Text('—');
    final diff = current - previous;
    final same = diff.abs() < 0.0001;
    final up = diff > 0;
    final color = same ? Colors.blueGrey : (up ? Colors.green : Colors.red);
    final icon = same ? Icons.trending_flat : (up ? Icons.trending_up : Icons.trending_down);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 4),
      Text(same ? 'ثبات' : (up ? 'ارتفاع' : 'انخفاض'), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      Text(' (${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)} $unit)', style: TextStyle(color: color, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ملف الطفل'), actions: [IconButton(tooltip: 'حفظ ومشاركة PDF', onPressed: _exportAndSharePdf, icon: const Icon(Icons.picture_as_pdf))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _editVisit(), icon: const Icon(Icons.add), label: const Text('إضافة زيارة')),
    body: FutureBuilder<void>(future: loading, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (patient == null) return const Center(child: Text('لم يتم العثور على السجل'));
      final p = patient!;
      return ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const CircleAvatar(backgroundColor: mint, child: Icon(Icons.child_care, color: teal)), const SizedBox(width: 10), Expanded(child: Text('${p['child_name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), IconButton(tooltip: 'تعديل بيانات الطفل', onPressed: _editPatient, icon: const Icon(Icons.edit, color: teal))]),
          const SizedBox(height: 8),
          Text('رقم SAM: ${p['sam_number']}'),
          Text('العمر: ${p['age_months']} شهر  •  الجنس: ${p['gender']}'),
          Text('الهاتف: ${p['phone'] ?? '—'}'),
          Text('الموقع: ${p['governorate'] ?? ''} / ${p['district'] ?? ''} / ${p['village'] ?? ''}'),
        ]))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('سجل الزيارات ومقارنة القياسات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: teal))),
        if (visits.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد زيارات مسجلة'))),
        ...List.generate(visits.length, (i) {
          final v = visits[i];
          final previous = i > 0 ? visits[i-1] : null;
          final weight = (v['weight_kg'] as num?)?.toDouble();
          final height = (v['height_cm'] as num?)?.toDouble();
          final prevWeight = (previous?['weight_kg'] as num?)?.toDouble();
          final prevHeight = (previous?['height_cm'] as num?)?.toDouble();
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('زيارة ${i+1} — ${v['visit_date']}', style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(tooltip: 'تعديل الزيارة', onPressed: () => _editVisit(v), icon: const Icon(Icons.edit, color: teal))]),
            const Divider(),
            Text('الوزن: ${weight?.toStringAsFixed(2) ?? '—'} كجم'),
            _trend(weight, prevWeight, 'كجم'),
            const SizedBox(height: 7),
            Text('الطول: ${height?.toStringAsFixed(1) ?? '—'} سم'),
            _trend(height, prevHeight, 'سم'),
            const SizedBox(height: 7),
            Text('MUAC: ${v['muac_cm'] ?? '—'} سم  •  Z-score: ${v['z_score'] ?? '—'}'),
            if ('${v['notes'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('ملاحظات: ${v['notes']}')),
            if (previous == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('هذه هي الزيارة المرجعية الأولى للمقارنة.', style: TextStyle(color: Colors.blueGrey, fontSize: 12))),
          ])));
        }),
        const SizedBox(height: 80),
      ]);
    }),
  );
}
