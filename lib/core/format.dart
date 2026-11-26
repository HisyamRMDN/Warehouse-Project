import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// 12500 -> "Rp 12.500"
String formatRupiah(num value) => _rupiah.format(value);
