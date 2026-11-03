import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    home: const Directionality(textDirection: TextDirection.rtl, child: PatientHome()),
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
        'admission_reasons': '', 'admission_type': admissionType, 'outcome': outcome,
      });
      for (final c in controllers) { c.clear(); }
      setState(() { admission = DateTime.now(); });
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
        DropdownButtonFormField<String>(value: gender, decoration: const InputDecoration(labelText: 'الجنس'), items: ['ذكر','أنثى'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>gender=v!)),
        field('رقم الهاتف', 3, type: TextInputType.phone),
        field('المحافظة / المديرية', 4),
        field('العزلة', 5),
        field('القرية أو الشارع', 9),
      ]),
      section('القسم B — بيانات الزيارة والقياسات', [
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('تاريخ القبول'), subtitle: Text(admissionDate), trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: pickAdmission)),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.event_available, color: teal), const SizedBox(width: 10), Expanded(child: Text('موعد المتابعة بعد 7 أيام: $visitDate', style: const TextStyle(fontWeight: FontWeight.bold, color: teal)))])),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: twins, decoration: const InputDecoration(labelText: 'هل الطفل من التوائم؟'), items: ['لا','نعم'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>twins=v!)),
        field('الوزن (كجم)', 6, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
        field('الطول (سم)', 7, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
        DropdownButtonFormField<String>(value: zScore, decoration: const InputDecoration(labelText: 'Z-score'), items: ['أقل من -3','من -3 إلى -2'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>zScore=v!)),
        field('MUAC — محيط منتصف العضد (سم)', 8, required: true, type: const TextInputType.numberWithOptions(decimal:true)),
      ]),
      section('القسم C — القبول والخروج', [
        DropdownButtonFormField<String>(value: admissionType, decoration: const InputDecoration(labelText: 'نوع القبول'), items: ['جديد','إعادة قبول','تحويل داخلي'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>admissionType=v!)),
        DropdownButtonFormField<String>(value: outcome, decoration: const InputDecoration(labelText: 'حالة الخروج / التحويل'), items: ['مستمر','تعافٍ','تحويل خارجي','تغيب','وفاة','غير ذلك'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>outcome=v!)),
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
  late Future<List<Map<String,Object?>>> future;
  @override
  void initState() { super.initState(); future = AppDatabase.instance.getPatients(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String,Object?>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const Center(child: Text('لا توجد سجلات بعد'));
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context,i) {
        final p = rows[i];
        return Card(child: ListTile(leading: const CircleAvatar(backgroundColor:mint,child:Icon(Icons.child_care,color:teal)), title: Text('${p['child_name']}'), subtitle: Text('SAM: ${p['sam_number']}  •  العمر: ${p['age_months']} شهر\nموعد المتابعة: ${p['visit_date']}'), isThreeLine: true));
      });
    },
  );
}
