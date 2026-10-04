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
  bool loading = false;


  Future<void> _openWhatsApp() async {
    final profile = await ref.read(repositoryProvider).userProfile();
    final userName = (profile['user_name'] ?? '').toString().trim();
    final sender = userName.isEmpty ? 'المستخدم' : userName;
    final text = 'السلام عليكم ورحمة الله وبركاته\n$sender لدي استفسار حول تطبيق دفتر برو';
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
                _contactButton(Icons.chat_rounded, 'واتساب', 'التواصل عبر WhatsApp', _openWhatsApp),
                const SizedBox(height: 10),
                _contactButton(Icons.send_rounded, 'تيليجرام', 'فتح حساب المطوّر على Telegram', () => _open(Uri.parse('https://t.me/S7m_5'), 'تعذر فتح تيليجرام')),
                const SizedBox(height: 10),
                _contactButton(Icons.camera_alt_rounded, 'إنستجرام', 'فتح حساب المطوّر على Instagram', () => _open(Uri.parse('https://www.instagram.com/sa.me_er?stkn=MWhzc2NwNXVzcnZ6Ng=='), 'تعذر فتح إنستجرام')),
                const SizedBox(height: 10),
                _contactButton(
                  Icons.language_rounded,
                  'زورنا على موقعنا',
                  'زيارة الموقع الرسمي لهلوسات أفكار',
                  () => _open(
                    Uri.parse('https://halosat-afkar-1jm1qvdj4-alhosamesameer-sys.vercel.app'),
                    'تعذر فتح الموقع',
                  ),
                ),
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
