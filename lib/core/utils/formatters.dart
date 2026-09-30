const _currencyNames = <String, String>{
  'YER': 'ريال يمني','SAR': 'ريال سعودي','EGP': 'جنيه مصري','USD': 'دولار أمريكي','EUR': 'يورو',
  'AED': 'درهم إماراتي','KWD': 'دينار كويتي','QAR': 'ريال قطري','OMR': 'ريال عماني','BHD': 'دينار بحريني',
  'JOD': 'دينار أردني','IQD': 'دينار عراقي','SYP': 'ليرة سورية','TRY': 'ليرة تركية','GBP': 'جنيه إسترليني',
};
const _currencyDecimals = <String, int>{
  'YER': 0,'SAR': 2,'EGP': 2,'USD': 2,'EUR': 2,'AED': 2,'KWD': 3,'QAR': 2,'OMR': 3,'BHD': 3,'JOD': 3,'IQD': 0,'SYP': 0,'TRY': 2,'GBP': 2,
};
String currencyName(String currency) => _currencyNames[currency.toUpperCase()] ?? currency.toUpperCase();
int currencyDecimals(String currency) => _currencyDecimals[currency.toUpperCase()] ?? 2;
String formatAmount(num value, String currency) => value.toStringAsFixed(currencyDecimals(currency));
String money(num value, String currency) {
  final sign = value < 0 ? '-' : '';
  return '$sign${formatAmount(value.abs(), currency)} ${currencyName(currency)}';
}
String dateAr(DateTime date) {
  final d = date.toLocal();
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}