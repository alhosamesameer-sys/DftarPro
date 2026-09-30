import '../../data/app_database.dart';
class SyncService {
  final AppDatabase database;
  const SyncService(this.database);
  Future<int> pendingCount() async => (await database.pendingQueue()).length;
  Future<void> run() async {}
}