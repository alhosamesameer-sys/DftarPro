import '../domain/models.dart';

extension AccountLedgerX on Account { String get displayName => name; }
extension TransactionLedgerX on TransactionItem { bool get isCredit => type == 'credit' || type == 'تحصيل'; }