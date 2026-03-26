import 'package:cw_core/balance.dart';
import 'package:cw_core/monero_amount_format.dart';

class MoneroBalance extends Balance {
  MoneroBalance({required this.fullBalance, required this.unlockedBalance, this.frozenBalance = 0})
      : formattedUnconfirmedBalance = xcashKAmountToString(amount: fullBalance - unlockedBalance),
        formattedUnlockedBalance = xcashKAmountToString(amount: unlockedBalance),
        formattedFrozenBalance = xcashKAmountToString(amount: frozenBalance),
        super(unlockedBalance, fullBalance);

  final int fullBalance;
  final int unlockedBalance;
  final int frozenBalance;
  final String formattedUnconfirmedBalance;
  final String formattedUnlockedBalance;
  final String formattedFrozenBalance;

  @override
  String get formattedUnAvailableBalance =>
      frozenBalance == 0 ? '' : formattedFrozenBalance;

  @override
  String get formattedAvailableBalance => formattedUnlockedBalance;

  @override
  String get formattedAdditionalBalance => formattedUnconfirmedBalance;
}
