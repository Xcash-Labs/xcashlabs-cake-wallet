import 'package:intl/intl.dart';
import 'package:cw_core/crypto_amount_format.dart';

const xcashKAmountLength = 6;
const xcashKAmountDivider = 1000000;

final xcashKAmountFormat = NumberFormat()
  ..maximumFractionDigits = xcashKAmountLength
  ..minimumFractionDigits = 0;

String xcashKAmountToString({required int amount}) => xcashKAmountFormat
    .format(cryptoAmountToDouble(amount: amount, divider: xcashKAmountDivider))
    .replaceAll(',', '');

double xcashKAmountToDouble({required int amount}) =>
    cryptoAmountToDouble(amount: amount, divider: xcashKAmountDivider);

int xcashKParseAmount({required String amount}) =>
    (double.parse(amount) * xcashKAmountDivider).round();

/// Temporary compatibility wrappers to avoid touching the whole codebase.
String moneroAmountToString({required int amount}) =>
    xcashKAmountToString(amount: amount);

double moneroAmountToDouble({required int amount}) =>
    xcashKAmountToDouble(amount: amount);

int moneroParseAmount({required String amount}) =>
    xcashKParseAmount(amount: amount);