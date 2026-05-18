import 'package:intl/intl.dart';

class RupiahFormatter {
  static String format(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static double parse(String formatted) {
    String cleaned = formatted.replaceAll('Rp ', '').replaceAll('.', '');
    return double.tryParse(cleaned) ?? 0;
  }
}