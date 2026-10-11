import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';

class StatementExportService {
  static const MethodChannel _nativePdf = MethodChannel('dftar/native_pdf');

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(double n) => n.toStringAsFixed(2);
  String _escape(String value) => const HtmlEscape(HtmlEscapeMode.element).convert(value);

  Future<String> _logoDataUri(String path) async {
    if (path.trim().isEmpty) return '';
    try {
      final file = File(path);
      if (!await file.exists()) return '';
      final bytes = await file.readAsBytes();
      final lower = path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return '';
    }
  }

  Future<String> buildHtml(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final p = profile ?? const <String, String>{};
    final base = p['base_currency']?.trim().isNotEmpty == true ? p['base_currency']!.trim() : (items.isNotEmpty ? items.first.baseCurrency : account.currency);
    final credit = items.where((e) => e.type == 'credit').fold<double>(0, (s, e) => s + e.baseAmount);
    final debit = items.where((e) => e.type == 'debit').fold<double>(0, (s, e) => s + e.baseAmount);
    final ownerAr = p['user_name']?.trim().isNotEmpty == true ? p['user_name']!.trim() : 'سمير الحسامي';
    final ownerEn = p['user_name_en']?.trim().isNotEmpty == true ? p['user_name_en']!.trim() : 'Sameer Alhosami';
    final ownerPhone = p['phone']?.trim() ?? '';
    final logo = await _logoDataUri(p['logo_path'] ?? '');
    final logoHtml = logo.isEmpty ? '<div class="logo-mark"><span>+</span><b>−</b></div>' : '<img class="logo" src="$logo" alt="logo">';

    final rows = items.map((e) {
      final note = e.note.trim().isEmpty ? (e.category.trim().isEmpty ? 'عملية' : e.category.trim()) : e.note.trim();
      final amount = '${_money(e.amount)} ${e.currency}';
      final equivalent = e.currency == base ? '' : '<br><span class="sub">ما يعادل ${_money(e.baseAmount)} ${_escape(e.baseCurrency)}</span>';
      final kind = e.type == 'credit' ? 'له' : 'عليه';
      return '''<tr><td>${_escape(_date(e.date))}</td><td>${_escape(note)}</td><td class="kind">$kind</td><td>${_escape(amount)}$equivalent</td></tr>''';
    }).join();

    final netLabel = balance.abs() < 0.000001 ? 'الحساب متعادل' : balance > 0 ? 'له' : 'عليه';
    return '''<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" lang="ar" dir="rtl">
<head><meta charset="UTF-8"><meta name="ProgId" content="Word.Document"><title>كشف حساب</title>
<style>
@page Section1 { size:21cm 29.7cm; margin:1.2cm; }
div.Section1 { page:Section1; }
body { margin:0; padding:0; color:#111; background:#fff; font-family:Tahoma,Arial,sans-serif; direction:rtl; }
table { border-collapse:collapse; mso-table-lspace:0pt; mso-table-rspace:0pt; }
.header { width:100%; border-bottom:2px solid #222; }
.header td { border:0; vertical-align:middle; padding:4px; }
.en { width:38%; text-align:left; direction:ltr; font-family:Arial,sans-serif; font-size:14pt; font-weight:bold; }
.center { width:24%; text-align:center; }
.ar { width:38%; text-align:right; font-size:14pt; font-weight:bold; }
.logo { width:54px; height:54px; object-fit:contain; }
.logo-mark { display:inline-block; width:54px; height:54px; line-height:54px; border:2px solid #009688; border-radius:10px; color:#009688; font-size:20pt; font-weight:bold; text-align:center; } .logo-mark b { color:#d9534f; margin-left:4px; }
.small { font-size:9pt; font-weight:normal; }
.title { text-align:center; font-size:20pt; font-weight:bold; padding:9px 0; }
.box { width:100%; border:1.5px solid #222; margin-top:8px; }
.box th { background:#eee; border:1px solid #222; padding:7px; text-align:center; font-size:12pt; }
.box td { border:1px solid #222; padding:7px 9px; font-size:11pt; }
.label { font-weight:bold; }
.balance { width:100%; border:1.5px solid #222; margin-top:12px; text-align:center; }
.balance td { padding:10px; }
.balance .caption { font-weight:bold; font-size:13pt; }
.balance .value { font-size:18pt; font-weight:bold; }
.summary { width:100%; margin-top:10px; }
.summary td { width:33.33%; border:1px solid #222; background:#f7f7f7; padding:8px; text-align:center; font-size:11pt; }
.summary strong { display:block; margin-bottom:3px; }
.section { font-size:13pt; font-weight:bold; margin-top:13px; margin-bottom:5px; }
.tx { width:100%; border:1.5px solid #222; }
.tx th { background:#eee; border:1px solid #222; padding:7px 4px; text-align:center; font-size:10.5pt; }
.tx td { border:1px solid #222; padding:6px 4px; text-align:center; font-size:9.5pt; }
.kind { font-weight:bold; }
.sub { font-size:8pt; color:#555; }
.footer { border-top:1px solid #aaa; margin-top:15px; padding-top:6px; font-size:8pt; color:#555; text-align:right; }
</style></head>
<body><div class="Section1">
<table class="header"><tr>
<td class="en">${_escape(ownerEn)}<br><span class="small">${_escape(p['address_en']?.trim() ?? '')}</span></td>
<td class="center">$logoHtml</td>
<td class="ar">${_escape(ownerAr)}<br><span class="small">${_escape(p['address_ar']?.trim() ?? '')}${ownerPhone.isEmpty ? '' : ' • ${_escape(ownerPhone)}'}</span></td>
</tr></table>
<div class="title">كشف حساب</div>
<table class="box"><tr><th colspan="2">بيانات العميل</th></tr>
<tr><td><span class="label">اسم العميل:</span> ${_escape(account.name)}</td><td><span class="label">العنوان:</span> ${_escape(account.address.isEmpty ? '—' : account.address)}</td></tr>
<tr><td colspan="2"><span class="label">رقم الهاتف:</span> ${_escape(account.phone.isEmpty ? '—' : account.phone)}</td></tr></table>
<table class="balance"><tr><td><div class="caption">إجمالي الرصيد الحالي</div><div class="value">${_money(balance.abs())} ${_escape(base)} — $netLabel</div></td></tr></table>
<table class="summary"><tr><td><strong>إجمالي له</strong>${_money(credit)} ${_escape(base)}</td><td><strong>إجمالي عليه</strong>${_money(debit)} ${_escape(base)}</td><td><strong>الصافي</strong>${_money(balance.abs())} ${_escape(base)} — $netLabel</td></tr></table>
<div class="section">تفاصيل العمليات</div>
<table class="tx"><tr><th>التاريخ</th><th>التفاصيل</th><th>النوع</th><th>المبلغ / ما يعادله</th></tr>
${rows.isEmpty ? '<tr><td colspan="4">لا توجد عمليات مسجلة في هذا الحساب.</td></tr>' : rows}
<tr><td colspan="2"><strong>الإجمالي</strong></td><td>له / عليه</td><td><strong>${_money(credit)} ${_escape(base)} / ${_money(debit)} ${_escape(base)}</strong></td></tr></table>
<div class="footer">كشف حساب ${_escape(account.name)} • ${_escape(ownerAr)} • ${_date(DateTime.now())}</div>
</div></body></html>''';
  }

  Map<String, Object?> _accountMap(Account a) => {'id':a.id,'name':a.name,'phone':a.phone,'address':a.address,'notes':a.notes};
  Map<String, Object?> _txMap(TransactionItem e) => {'id':e.id,'type':e.type,'amount':e.amount,'currency':e.currency,'baseAmount':e.baseAmount,'baseCurrency':e.baseCurrency,'category':e.category,'note':e.note,'date':_date(e.date)};

  Future<Uint8List> buildPdf(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final path = await _nativePdf.invokeMethod<String>('createStatementPdf', {'account':_accountMap(account),'profile':profile ?? const <String,String>{},'transactions':items.map(_txMap).toList(),'balance':balance});
    if (path == null || path.isEmpty) throw StateError('تعذر إنشاء ملف PDF');
    return File(path).readAsBytes();
  }

  Future<void> share(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final bytes = await buildPdf(account, items, balance, profile: profile);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/كشف_حساب_${account.id}.pdf');
    await file.writeAsBytes(bytes, flush:true);
    await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/pdf')],text:'كشف حساب ${account.name}'));
  }

  Future<void> sharePdfToWhatsApp(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile, required String phone}) async {
    final bytes = await buildPdf(account, items, balance, profile: profile);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/كشف_حساب_${account.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    final opened = await _nativePdf.invokeMethod<bool>('shareStatementToWhatsApp', {
      'path': file.path,
      'phone': phone,
      'mimeType': 'application/pdf',
      'business': false,
    });
    if (opened != true) throw StateError('تعذر فتح واتساب لمشاركة ملف PDF');
  }

  Future<void> openStatement(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    await _nativePdf.invokeMethod<String>('openStatementPdf', {
      'account': _accountMap(account),
      'profile': profile ?? const <String,String>{},
      'transactions': items.map(_txMap).toList(),
      'balance': balance,
    });
  }

  Future<void> printStatement(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final bytes = await buildPdf(account, items, balance, profile: profile);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name:'كشف_حساب_${account.id}.pdf');
  }

  Future<void> shareWordToWhatsApp(Account account, List<TransactionItem> items, double balance, Map<String, String> profile, {required String phone}) async {
    final dir = await getTemporaryDirectory();
    final html = await buildHtml(account, items, balance, profile: profile);
    final safe = account.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/كشف_حساب_$safe.doc');
    await file.writeAsString(html, encoding: utf8, flush: true);
    final opened = await _nativePdf.invokeMethod<bool>('shareStatementToWhatsApp', {
      'path': file.path,
      'phone': phone,
      'mimeType': 'application/msword',
      'business': false,
    });
    if (opened != true) throw StateError('تعذر فتح واتساب لمشاركة ملف Word');
  }

  Future<void> shareWord(Account account, List<TransactionItem> items, double balance, Map<String, String> profile) async {
    final dir = await getTemporaryDirectory();
    final html = await buildHtml(account, items, balance, profile:profile);
    final safe = account.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/كشف_حساب_$safe.doc');
    await file.writeAsString(html,encoding:utf8,flush:true);
    await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/msword')],text:'كشف حساب ${account.name}'));
  }
}
