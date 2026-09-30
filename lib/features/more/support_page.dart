import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  List<Map<String, dynamic>> accounts = const [];
  String? selectedAccountId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final rows = await ref.read(repositoryProvider).accounts();
    if (!mounted) return;
    setState(() {
      accounts = rows.map((a) => <String, dynamic>{'id': a.id, 'name': a.name}).toList();
      if (accounts.isNotEmpty) selectedAccountId = accounts.first['id'] as String;
      loading = false;
    });
  }

  String get selectedName {
    for (final a in accounts) {
      if (a['id'] == selectedAccountId) return (a['name'] as String?)?.trim() ?? '';
    }
    return '';
  }

  Future<void> _openWhatsApp() async {
    final customer = selectedName.isEmpty ? 'العميل' : selectedName;
    final text = 'السلام عليكم ورحمة الله وبركاته\n$customer لدي استفسار حول تطبيق دفتر برو';
    final uri = Uri.parse('https://wa.me/967714692465?text=${Uri.encodeComponent(text)}');
    await _open(uri, 'تعذر فتح واتساب');
  }

  Future<void> _open(Uri uri, String error) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'التواصل والدعم'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        Text('السلام عليكم ورحمة الله وبركاته 🌷', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        SizedBox(height: 12),
                        Text('أنا المهندس سمير عبد القادر الحسام، مطوّر تطبيق دفتر برو.\n\nيسعدني ويشرّفني استخدامكم للتطبيق، وأتمنى أن يكون دفتر برو عونًا لكم في تنظيم حساباتكم، ومتابعة معاملاتكم، وحفظ حقوقكم بكل سهولة ووضوح.\n\nهذا التطبيق هو ثمرة جهد وطموح مستمر، وأسعى بإذن الله إلى تطويره وتحسينه وإضافة المزيد من المزايا التي تلبي احتياجاتكم وتجعل تجربتكم أفضل في كل تحديث.\n\nإذا كان لديكم استفسار، ملاحظة، اقتراح، أو فكرة لتطوير التطبيق، فلا تترددوا في التواصل معنا.\nآراؤكم واقتراحاتكم محل اهتمامنا، وبها نستطيع أن نجعل دفتر برو أفضل وأكثر فائدة للجميع.\n\nشكرًا لثقتكم، وشكرًا لاستخدامكم دفتر برو.\nنسأل الله لكم التوفيق والنجاح، وإلى مزيد من التقدم والتطور بإذن الله. 🌟\n\nالمهندس/ سمير عبد القادر الحسام\nمطور تطبيق دفتر برو', style: TextStyle(fontSize: 15, height: 1.75)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (accounts.isNotEmpty) ...[
                  const SectionTitle(title: 'اسم العميل في رسالة واتساب'),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), labelText: 'اختر العميل'),
                    items: accounts.map((a) => DropdownMenuItem<String>(value: a['id'] as String, child: Text(a['name'] as String))).toList(),
                    onChanged: (value) => setState(() => selectedAccountId = value),
                  ),
                  const SizedBox(height: 12),
                ],
                _contactButton(Icons.chat_rounded, 'واتساب', 'التواصل عبر WhatsApp', _openWhatsApp),
                const SizedBox(height: 10),
                _contactButton(Icons.send_rounded, 'تيليجرام', 'فتح حساب المطوّر على Telegram', () => _open(Uri.parse('https://t.me/S7m_5'), 'تعذر فتح تيليجرام')),
                const SizedBox(height: 10),
                _contactButton(Icons.camera_alt_rounded, 'إنستجرام', 'فتح حساب المطوّر على Instagram', () => _open(Uri.parse('https://www.instagram.com/sa.me_er?stkn=MWhzc2NwNXVzcnZ6Ng=='), 'تعذر فتح إنستجرام')),
              ],
            ),
    );
  }

  Widget _contactButton(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new_rounded),
      ),
    );
  }
}
