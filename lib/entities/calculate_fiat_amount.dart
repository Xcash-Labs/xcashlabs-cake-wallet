import 'package:cw_core/crypto_amount_format.dart';

String calculateFiatAmount(
    {double? price, String? cryptoAmount, bool raw = false, String? langCode}) {
  if (price == null || cryptoAmount == null) {
    return '0.00'.withLocalSeperator(langCode);
  }

  cryptoAmount = cryptoAmount.replaceAll(',', '.');

  final _amount = double.parse(cryptoAmount);
  final _result = price * _amount;
  final result = _result < 0 ? _result * -1 : _result;

  if (result == 0.0) {
    return '0.00'.withLocalSeperator(langCode);
  }

  if (raw) {
    return result.toStringAsFixed(2);
  }

  var formatted = result.toStringAsFixed(2).withLocalSeperator(langCode);

  return result > 0.01 ? formatted : '< 0.01';
}

String formatWithCommas(String? number) {
  if (number?.isEmpty ?? true) return '';

  final parts = number!.split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '';

  final formattedInteger = integerPart.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match match) => ',',
  );

  return decimalPart.isNotEmpty ? '$formattedInteger.$decimalPart' : formattedInteger;
}
