import '../models.dart';
class CalculateBalanceUseCase {
  double call(List<TransactionItem> items){var value=0.0;for(final t in items){value+=t.type=='credit'?t.amount:-t.amount;}return value;}
}
