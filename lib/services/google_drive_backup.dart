import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../data/app_database.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._headers);
  @override Future<http.StreamedResponse> send(http.BaseRequest request) { request.headers.addAll(_headers); return _inner.send(request); }
  @override void close() => _inner.close();
}

class GoogleDriveBackupService {
  static const _scope = drive.DriveApi.driveFileScope;
  static const _fileName = 'دفتر_Pro_نسخة_احتياطية.json';
  final AppDatabase database;
  final GoogleSignIn _google = GoogleSignIn(scopes: [_scope]);
  GoogleDriveBackupService(this.database);

  Future<GoogleSignInAccount?> _account({bool silent = false}) async {
    try {
      return silent ? await _google.signInSilently() : await _google.signIn();
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' || e.message?.contains('ApiException: 10') == true) {
        throw StateError('تعذر تسجيل الدخول إلى Google. إعدادات OAuth الخاصة بنسخة Android (اسم الحزمة وبصمة SHA-1/SHA-256) لا تطابق نسخة دفتر Pro الموقعة.');
      }
      rethrow;
    }
  }

  Future<drive.DriveApi> _api(GoogleSignInAccount account) async {
    final headers = await account.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<GoogleSignInAccount?> connect() => _account();

  Future<void> disconnect() async {
    try { await _google.signOut(); } catch (_) {}
    await database.setSetting('backup_account', '');
    await database.setSetting('backup_drive_file_id', '');
  }

  Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_fileName' and trashed = false",
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      pageSize: 10,
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = result.files ?? const <drive.File>[];
    return files.isEmpty ? null : files.first;
  }

  Future<String> upload() async {
    var account = await _account(silent: true);
    account ??= await _account();
    if (account == null) throw StateError('لم يتم اختيار حساب Google');
    final api = await _api(account);
    final bytes = utf8.encode(jsonEncode(await database.exportData()));
    final storedId = await database.getSetting('backup_drive_file_id');
    final existing = storedId?.isNotEmpty == true ? drive.File(id: storedId) : await _findBackup(api);
    drive.File result;
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length, contentType: 'application/json');
    if (existing?.id != null && existing!.id!.isNotEmpty) {
      try {
        result = await api.files.update(drive.File(name: _fileName, mimeType: 'application/json'), existing.id!, uploadMedia: media, $fields: 'id,name,modifiedTime');
      } catch (_) {
        result = await _create(api, bytes);
      }
    } else {
      result = await _create(api, bytes);
    }
    final id = result.id;
    if (id == null || id.isEmpty) throw StateError('تعذر الحصول على معرف ملف النسخة الاحتياطية');
    await database.setSetting('backup_drive_file_id', id);
    await database.setSetting('backup_account', account.email);
    return account.email;
  }

  Future<drive.File> _create(drive.DriveApi api, List<int> bytes) => api.files.create(
    drive.File(name: _fileName, mimeType: 'application/json'),
    uploadMedia: drive.Media(Stream<List<int>>.value(bytes), bytes.length, contentType: 'application/json'),
    $fields: 'id,name,modifiedTime',
  );

  Future<Map<String, dynamic>> downloadBackup() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    var account = await _account(silent: true);
    account ??= await _account();
    if (account == null) throw StateError('لم يتم اختيار حساب Google');
    final api = await _api(account);
    var id = await database.getSetting('backup_drive_file_id') ?? '';
    if (id.isEmpty) {
      final found = await _findBackup(api);
      id = found?.id ?? '';
      if (id.isNotEmpty) await database.setSetting('backup_drive_file_id', id);
    }
    if (id.isEmpty) throw StateError('لم يتم العثور على نسخة دفتر Pro في حساب Google هذا');
    drive.Media response;
    try {
      final result = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia);
      if (result is! drive.Media) throw StateError('تعذر تنزيل النسخة من Google Drive');
      response = result;
    } catch (_) {
      final found = await _findBackup(api);
      if (found?.id == null) throw StateError('لم يتم العثور على نسخة دفتر Pro في حساب Google هذا');
      final result = await api.files.get(found!.id!, downloadOptions: drive.DownloadOptions.fullMedia);
      if (result is! drive.Media) throw StateError('تعذر تنزيل النسخة من Google Drive');
      response = result;
      await database.setSetting('backup_drive_file_id', found.id!);
    }
    final chunks = <List<int>>[];
    await for (final chunk in response.stream) { chunks.add(chunk); }
    final bytes = chunks.expand((x) => x).toList();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('النسخة الموجودة على Google Drive غير صالحة');
    return decoded;
  }

  Future<bool> _online() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<File> createLocalCopy() async {
    final configured = await database.getSetting('backup_local_path') ?? '';
    final dir = Directory(configured.isEmpty ? (await getApplicationDocumentsDirectory()).path : configured);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$_fileName');
    await file.writeAsString(jsonEncode(await database.exportData()), flush: true);
    return file;
  }
}

class BackupNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _notifications.initialize(settings);
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<bool> _enabled(String key, AppDatabase db) async => (await db.getSetting(key) ?? '1') == '1';

  Future<void> success(AppDatabase db) async {
    if (!await _enabled('backup_notify_success', db)) return;
    await initialize();
    await _notifications.show(2001, 'النسخ الاحتياطي', 'تم تحديث النسخة الاحتياطية بنجاح.', const NotificationDetails(
      android: AndroidNotificationDetails('backup_status','النسخ الاحتياطي',channelDescription:'نتائج النسخ الاحتياطي',importance:Importance.defaultImportance,priority:Priority.defaultPriority),
    ));
  }

  Future<void> failure(AppDatabase db, String message) async {
    if (!await _enabled('backup_notify_failure', db)) return;
    await initialize();
    await _notifications.show(2002, 'فشل النسخ الاحتياطي', message, const NotificationDetails(
      android: AndroidNotificationDetails('backup_status','النسخ الاحتياطي',channelDescription:'نتائج النسخ الاحتياطي',importance:Importance.high,priority:Priority.high),
    ));
  }

  Future<void> reminder(AppDatabase db, String message) async {
    if ((await db.getSetting('reminders_enabled') ?? '1') != '1') return;
    await initialize();
    await _notifications.show(2003, 'تذكير', message, const NotificationDetails(
      android: AndroidNotificationDetails('backup_reminder','التذكيرات',channelDescription:'تذكيرات النسخ الاحتياطي',importance:Importance.defaultImportance,priority:Priority.defaultPriority),
    ));
  }
}

class BackupCoordinator {
  final AppDatabase database;
  final Connectivity _connectivity = Connectivity();
  late final GoogleDriveBackupService drive;
  final BackupNotificationService notifications = BackupNotificationService();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _running = false;
  bool _minuteBusy = false;

  BackupCoordinator(this.database) { drive = GoogleDriveBackupService(database); }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await notifications.initialize();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) checkAndBackup();
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkScheduledTime());
    await checkAndBackup();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<bool> _online() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _checkScheduledTime() async {
    if (_minuteBusy || !await _online()) return;
    if ((await database.getSetting('backup_auto') ?? '0') != '1') return;
    final configured = await database.getSetting('backup_time') ?? '02:00';
    final parts = configured.split(':');
    if (parts.length != 2) return;
    final now = DateTime.now();
    if (now.hour != int.tryParse(parts[0]) || now.minute != int.tryParse(parts[1])) return;
    _minuteBusy = true;
    try {
      await checkAndBackup(forceTime: true);
    } finally {
      _minuteBusy = false;
    }
  }

  Future<void> checkAndBackup({bool forceTime = false}) async {
    if (!await _online()) return;
    if ((await database.getSetting('backup_auto') ?? '0') != '1') return;
    final account = await database.getSetting('backup_account') ?? '';
    if (account.isEmpty) {
      await notifications.reminder(database, 'اربط حساب Google Drive لتفعيل النسخ الاحتياطي التلقائي.');
      return;
    }
    final last = int.tryParse(await database.getSetting('backup_last_success') ?? '0') ?? 0;
    final due = last <= 0 || DateTime.now().millisecondsSinceEpoch - last >= const Duration(hours: 24).inMilliseconds;
    if (!forceTime && !due) return;
    await _runBackup(notify: true);
  }

  Future<bool> _runBackup({bool notify = true}) async {
    try {
      await drive.createLocalCopy();
      final email = await drive.upload();
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.setSetting('backup_last_success', '$now');
      await database.setSetting('backup_last_status', 'success');
      await database.setSetting('backup_last_error', '');
      await database.setSetting('backup_account', email);
      if (notify) await notifications.success(database);
      return true;
    } catch (e) {
      await database.setSetting('backup_last_status', 'failure');
      await database.setSetting('backup_last_error', e.toString());
      if (notify) await notifications.failure(database, 'تعذر تحديث النسخة الاحتياطية. سيتم إعادة المحاولة عند توفر الاتصال.');
      return false;
    }
  }

  Future<String> connectAndBackup() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final account = await drive.connect();
    if (account == null) throw StateError('لم يتم اختيار حساب Google');
    await database.setSetting('backup_account', account.email);
    final ok = await _runBackup(notify: true);
    if (!ok) throw StateError('تم اختيار حساب Google لكن فشل رفع النسخة الاحتياطية');
    return account.email;
  }

  Future<void> backupNow() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final account = await drive.connect();
    if (account == null) throw StateError('لم يتم اختيار حساب Google');
    await database.setSetting('backup_account', account.email);
    final ok = await _runBackup(notify: true);
    if (!ok) throw StateError('فشل رفع النسخة الاحتياطية');
  }

  Future<void> restoreFromDrive({bool merge = false}) async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final data = await drive.downloadBackup();
    await database.importData(data, merge: merge);
    await database.setSetting('backup_last_status', 'restored');
  }

  Future<void> disconnect() async {
    await drive.disconnect();
    await database.setSetting('backup_last_status', '');
  }
}
