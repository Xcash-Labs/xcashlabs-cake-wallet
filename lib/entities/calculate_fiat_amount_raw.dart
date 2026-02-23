import 'package:cw_core/crypto_amount_format.dart';

String calculateFiatAmountRaw({required double cryptoAmount, double? price, required String langCode}) {
  if (price == null) {
    return '0.00';
  }

  final result = price * cryptoAmount;

  if (result == 0.0) {
    return '0.00';
  }

  return result > 0.01 ? result.toStringAsFixed(2).withLocalSeperator(langCode) : '< 0.01';
}
