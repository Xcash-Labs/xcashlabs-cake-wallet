import 'dart:async';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:hive/hive.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// From trade_monitor.dart -- TODO: remove unused when finished
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
// Prolly remove these, we'll see

// From transactions export formatter -- TODO: remove unused when finished

// KB: TODO: this approach may be intensive to run on wallets with large numbers of transactions
// We could consider an approach that runs in an isolate, but that doesn't make sense because user has taken an action
// to export transactions, so some delay is acceptable. We can optimize later if needed

/*

Seth wanted:
Swaps
  Timestamp/date - got
  Deposit TXID - got
  Amount - got
  From Currency -> To Currency (swap pair header row) - got
  Withdrawal TXID - got
  Amount - got
  Provider - got
  Rate - will need to calculate from (deposit - fee) / (receive amount)
  
I'm considering supplementing with: 
  Status - this isn't easily accessed via TradeState
  Note(?)

*/

// Standardized transaction export data class containing all exportable fields
class SwapExportData {
  SwapExportData(Trade trade)
      : createdAt = trade.createdAt,
        depositTxId = trade.txId,
        amount = trade.amount,
        from = trade.from,
        to = trade.to,
        withdrawalTxId = trade.outputTransaction ?? 'N/A',
        providerName = trade.providerName,
        receiveAmount = trade.receiveAmount;

  // TODO: Consider including status

  final DateTime? createdAt;
  final String? depositTxId;
  final String amount;
  final CryptoCurrency? from, to;
  final String withdrawalTxId;
  final String? receiveAmount;
  final String? providerName;
  // Rate calculation will need to be done inside a method. I don't see us storing fees anywhere

  static String _escapeCsvField(String field) {
    if (field.contains(',') ||
        field.contains('\n') ||
        field.contains('"') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String csvHeader() {
    return 'Created At,Deposit TXID,Amount,Swap Pair,Provider Name,Withdrawal TXID,Receive Amount,Exchange Rate';
  }

  // There's a bug in the rate calculation
  static dynamic formatSwap(Trade trade) {
    final rate = (trade.receiveAmount != null &&
            trade.amount.isNotEmpty &&
            trade.receiveAmount!.isNotEmpty)
        ? (double.parse(trade.receiveAmount!) / double.parse(trade.amount)).toStringAsPrecision(16)
        : 'N/A';

    return _formatSwapData(trade, rate);
  }

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static _formatSwapData(Trade trade, String rate) {
    final timestamp = _dateFormat.format(trade.createdAt ?? DateTime.now());
    final timestampString = "'" + timestamp;
    var responseString = [
      _escapeCsvField(timestampString),
      _escapeCsvField(trade.txId ?? 'N/A'),
      _escapeCsvField(trade.amount),
      _escapeCsvField('${trade.from?.fullName ?? 'N/A'} -> ${trade.to?.fullName ?? 'N/A'}'),
      _escapeCsvField(trade.providerName ?? 'N/A'),
      _escapeCsvField(trade.outputTransaction ?? 'N/A'),
      _escapeCsvField(trade.receiveAmount ?? 'N/A'),
      _escapeCsvField(rate),
    ].join("','");
    responseString = responseString + "'";
    return responseString;
  }
}