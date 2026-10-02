import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../data/app_database.dart';

/// Google Drive backup through Android's Storage Access Framework (SAF).
/// The user chooses the Drive account/file in the Android picker. DftarPro
/// stores the returned content URI and can update the same document later.
class GoogleDriveBackupService {
  static const _channel = MethodChannel('dftar/backup_storage');
  static const _fileName = 'دفتربرو_نسخة_احتياطية.json';
  final AppDatabase database;
  GoogleDriveBackupService(this.database);

  Future<Map<String, dynamic>?> chooseBackupDestination() async {
    final result = await _channel.invokeMethod<dynamic>('chooseBackupDestination', {'fileName': _fileName});
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> chooseRestoreFile() async {
    final result = await _channel.invokeMethod<dynamic>('chooseRestoreFile');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> _writeUri(String uri, List<int> bytes) async {
    await _channel.invokeMethod('writeBackup', {'uri': uri, 'bytes': Uint8List.fromList(bytes)});
  }

  Future<List<int>> _readUri(String uri) async {
    final result = await _channel.invokeMethod<dynamic>('readBackup', {'uri': uri});
    if (result is Uint8List) return result;
    if (result is List) return result.cast<int>();
    throw StateError('تعذر قراءة ملف النسخة الاحتياطية');
  }

  Future<String> connect() async {
    final selected = await chooseBackupDestination();
    if (selected == null) throw StateError('لم يتم اختيار مكان لحفظ النسخة الاحتياطية');
    final uri = selected['uri']?.toString() ?? '';
    if (uri.isEmpty) throw StateError('تعذر الحصول على مرجع ملف Google Drive');
    await database.setSetting('backup_drive_uri', uri);
    await database.setSetting('backup_drive_name', selected['name']?.toString() ?? _fileName);
    await database.setSetting('backup_drive_provider', selected['provider']?.toString() ?? 'Google Drive');
    await database.setSetting('backup_account', selected['accountLabel']?.toString() ?? 'Google Drive — الحساب الذي اخترته');
    return await upload();
  }

  Future<String> upload() async {
    final uri = await database.getSetting('backup_drive_uri') ?? '';
    if (uri.isEmpty) throw StateError('لم يتم ربط ملف Google Drive بعد');
    final bytes = utf8.encode(jsonEncode(await database.exportData()));
    try {
      await _writeUri(uri, bytes);
    } catch (_) {
      throw StateError('تعذر تحديث ملف Google Drive المرتبط. أعد اختيار ملف النسخة من Drive.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.setSetting('backup_drive_last_success', '$now');
    return await database.getSetting('backup_account') ?? 'Google Drive — الحساب الذي اخترته';
  }

  Future<Map<String, dynamic>> downloadBackup() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final uri = await database.getSetting('backup_drive_uri') ?? '';
    List<int> bytes;
    if (uri.isNotEmpty) {
      try {
        bytes = await _readUri(uri);
      } catch (_) {
        final selected = await chooseRestoreFile();
        if (selected == null) throw StateError('لم يتم اختيار نسخة احتياطية من Google Drive');
        bytes = await _readUri(selected['uri'].toString());
        await _saveSelected(selected);
      }
    } else {
      final selected = await chooseRestoreFile();
      if (selected == null) throw StateError('لم يتم اختيار نسخة احتياطية من Google Drive');
      final selectedUri = selected['uri']?.toString() ?? '';
      if (selectedUri.isEmpty) throw StateError('ملف النسخة الاحتياطية غير صالح');
      bytes = await _readUri(selectedUri);
      await _saveSelected(selected);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('النسخة الموجودة على Google Drive غير صالحة');
    return decoded;
  }

  Future<void> _saveSelected(Map<String, dynamic> selected) async {
    await database.setSetting('backup_drive_uri', selected['uri']?.toString() ?? '');
    await database.setSetting('backup_drive_name', selected['name']?.toString() ?? _fileName);
    await database.setSetting('backup_drive_provider', selected['provider']?.toString() ?? 'Google Drive');
    await database.setSetting('backup_account', selected['accountLabel']?.toString() ?? 'Google Drive — الحساب الذي اخترته');
  }

  Future<bool> _online() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<File> createLocalCopy() async {
    final configured = await database.getSetting('backup_local_path') ?? '';
    final dir = Directory(configured.isEmpty ? (await getApplicationDocumentsDirectory()).path : configured);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(dir.path + '/' + _fileName);
    await file.writeAsString(jsonEncode(await database.exportData()), flush: true);
    return file;
  }
}

class BackupNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(android: AndroidInitializationSettings('@drawable/app_icon'));
    await _notifications.initialize(settings);
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<bool> _enabled(String key, AppDatabase db) async => (await db.getSetting(key) ?? '1') == '1';

  Future<void> success(AppDatabase db) async {
    if (!await _enabled('backup_notify_success', db)) return;
    await initialize();
    await _notifications.show(2001, 'النسخ الاحتياطي', 'تم تحديث النسختين المحلية وGoogle Drive بنجاح.', const NotificationDetails(
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
  static const MethodChannel _alarmChannel = MethodChannel('dftar/backup_alarm');
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
    await scheduleAutoBackup();
    await checkAndBackup();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> scheduleAutoBackup() async {
    if (!Platform.isAndroid) return;
    final enabled = (await database.getSetting('backup_auto') ?? '0') == '1';
    if (!enabled) {
      try { await _alarmChannel.invokeMethod('cancelDailyBackup'); } catch (_) {}
      return;
    }
    final configured = await database.getSetting('backup_time') ?? '02:00';
    final parts = configured.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    try { await _alarmChannel.invokeMethod('scheduleDailyBackup', {'hour': hour, 'minute': minute}); } catch (_) {}
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
    try { await checkAndBackup(forceTime: true); } finally { _minuteBusy = false; }
  }

  Future<void> checkAndBackup({bool forceTime = false}) async {
    if (!await _online()) return;
    if ((await database.getSetting('backup_auto') ?? '0') != '1') return;
    if ((await database.getSetting('backup_drive_uri') ?? '').isEmpty) {
      await notifications.reminder(database, 'اختر ملف Google Drive لربط النسخة الاحتياطية التلقائية.');
      return;
    }
    final configured = await database.getSetting('backup_time') ?? '02:00';
    final parts = configured.split(':');
    if (parts.length != 2) return;
    final now = DateTime.now();
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    final last = int.tryParse(await database.getSetting('backup_last_success') ?? '0') ?? 0;
    final lastDate = last > 0 ? DateTime.fromMillisecondsSinceEpoch(last) : null;
    final alreadyToday = lastDate != null && lastDate.year == now.year && lastDate.month == now.month && lastDate.day == now.day;
    final scheduledReached = now.hour > hour || (now.hour == hour && now.minute >= minute);
    if (!forceTime && (!scheduledReached || alreadyToday)) return;
    if (forceTime && alreadyToday) return;
    await _runBackup(notify: true);
  }

  Future<bool> _runBackup({bool notify = true}) async {
    try {
      await drive.createLocalCopy();
      final account = await drive.upload();
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.setSetting('backup_last_success', '$now');
      await database.setSetting('backup_last_status', 'success');
      await database.setSetting('backup_last_error', '');
      await database.setSetting('backup_account', account);
      if (notify) await notifications.success(database);
      return true;
    } catch (e) {
      await database.setSetting('backup_last_status', 'failure');
      await database.setSetting('backup_last_error', e.toString());
      if (notify) await notifications.failure(database, 'تعذر تحديث النسخة الاحتياطية. أعد اختيار ملف Drive إذا لزم الأمر.');
      return false;
    }
  }

  Future<String> connectAndBackup() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final account = await drive.connect();
    final ok = await _runBackup(notify: true);
    if (!ok) throw StateError('تم اختيار ملف Google Drive لكن فشل تحديث النسخة الاحتياطية');
    return account;
  }

  Future<void> backupNow() async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    if ((await database.getSetting('backup_drive_uri') ?? '').isEmpty) {
      throw StateError('لم يتم ربط ملف Google Drive بعد');
    }
    final ok = await _runBackup(notify: true);
    if (!ok) throw StateError('فشل تحديث النسخة الاحتياطية');
  }

  Future<void> restoreFromDrive({bool merge = false}) async {
    if (!await _online()) throw StateError('لا يوجد اتصال بالإنترنت');
    final data = await drive.downloadBackup();
    await database.importData(data, merge: merge);
    await database.setSetting('backup_last_status', 'restored');
  }

  Future<void> disconnect() async {
    await database.setSetting('backup_drive_uri', '');
    await database.setSetting('backup_drive_name', '');
    await database.setSetting('backup_drive_provider', '');
    await database.setSetting('backup_account', '');
    await database.setSetting('backup_last_status', '');
    if (Platform.isAndroid) { try { await _alarmChannel.invokeMethod('cancelDailyBackup'); } catch (_) {} }
  }
}
