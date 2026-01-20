import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:intl/intl.dart';

// KB: TODO: this approach is not ideal for wallets with large numbers of transactions
// TODO: should we add a balance at time of transaction field?

/*

Seth wanted:
Transactions
  Timestamp/date
  TXID
  Amount
  Fee amount
  Currency
  Note

I've also included
  Type (Sent/Received)
  Block Height
  Subwallet Number
  Key (index)
  Recipient Address (if applicable)
  Tx Explorer Links

Swaps
  See swap_export_formatter.dart
*/

/// Standardized transaction export data class containing all exportable fields
class TransactionExportData {
  TransactionExportData({
    required this.timestamp,
    required this.txId,
    required this.amount,
    required this.fee,
    required this.type,
    required this.height,
    required this.note,
    required this.confirmations,
    required this.subwalletNumber,
    required this.key,
    required this.recipientAddress,
    required this.explorerLink,
  });

  final String timestamp;
  final String txId;
  final String amount;
  final String fee;
  final String type;
  final String height;
  final String note;
  final String confirmations;
  final String subwalletNumber;
  final String key;
  final String recipientAddress;
  final String explorerLink;

  /// Converts export data to CSV row with RFC 4180 escaping
  String toCsvRow() {
    return [
      _escapeCsvField(timestamp),
      _escapeCsvField(txId),
      _escapeCsvField(amount),
      _escapeCsvField(fee),
      _escapeCsvField(type),
      _escapeCsvField(height),
      _escapeCsvField(confirmations),
      _escapeCsvField(recipientAddress),
      _escapeCsvField(explorerLink),
      "\n"
    ].join("','");
  }

  /// Converts export data to JSON map
  // KB: TODO: Either remove or use for debugging
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'txId': txId,
      'amount': amount,
      'fee': fee,
      'type': type,
      'height': height,
      'confirmations': confirmations,
      'recipientAddress': recipientAddress,
      'explorerLink': explorerLink,
    };
  }

  /// Escapes CSV field according to RFC 4180
  /// Wraps in quotes if contains comma, newline, or quote
  /// Doubles internal quotes
  static String _escapeCsvField(String field) {
    if (field.contains(',') ||
        field.contains('\n') ||
        field.contains('"') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Returns CSV header row
  static String csvHeader({WalletType? walletType}) {
    var headerString = '';
    switch (walletType) {
      case WalletType.monero:
        headerString =
            'Timestamp,Amount,Received/Sent,Fee,Transaction ID,Recipient Address,Note,Explorer Link';
      case WalletType.dogecoin:
      case WalletType.bitcoin:
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        headerString =
            'Timestamp,Amount,Received/Sent,Fee,Transaction ID,Fee,Recipient Address,Note,Explorer Link';
      case WalletType.solana:
      case WalletType.ethereum:
        headerString =
            'Timestamp,Amount,Received/Sent,Transaction ID,Fee,Recipient Address,Note,Explorer Link';
      default:
        headerString =
            'Timestamp,Amount,Received/Sent,Fee,Transaction ID,Recipient Address,Note,Explorer Link';
    }
    return headerString;
  }
}

/// Transaction export formatter utility
class TransactionExportFormatter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String _escapeCsvField(String field) {
    if (field.contains(',') ||
        field.contains('\n') ||
        field.contains('"') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Formats any TransactionInfo into standardized export data
  /// Safely extracts properties based on wallet type
  static String formatTransaction(
    TransactionInfo tx,
    WalletType walletType,
  ) {
    try {
      // Format timestamp
      final timestamp = _dateFormat.format(tx.date);
      // Format transaction type
      final type = tx.direction == TransactionDirection.incoming ? 'Received' : 'Sent';

      // Format recipient address based on direction
      String recipientAddress = 'N/A';
      if (tx.direction == TransactionDirection.incoming) {
        recipientAddress = 'N/A'; // Incoming transactions don't have recipient
      } else {
        // Try to get recipient address from transaction-specific fields
        recipientAddress = _extractRecipientAddress(tx) ?? 'Not known';
      }

      // Extract wallet-type-specific fields
      switch (walletType) {
        case WalletType.monero:
        case WalletType.wownero:
        case WalletType.nano:
          return _formatMoneroTransaction(tx, timestamp, type, recipientAddress);
        case WalletType.bitcoin:
        case WalletType.litecoin:
        case WalletType.bitcoinCash:
        case WalletType.dogecoin:
          return _formatElectrumTransaction(tx, timestamp, type, recipientAddress, walletType);
        case WalletType.polygon:
        case WalletType.arbitrum:
        case WalletType.base:
        case WalletType.ethereum:
          return _formatEVMTransaction(tx, timestamp, type, recipientAddress, walletType);
        case WalletType.solana:
          return _formatSolanaTransaction(tx, timestamp, type, recipientAddress);
        case WalletType.tron:
          return _formatTronTransaction(tx, timestamp, type, recipientAddress);
        case WalletType.decred:
          return _formatDecredTransaction(tx, timestamp, type, recipientAddress);
        default:
          return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
      }
    } catch (e) {
      return _formatGenericTransaction(
        tx,
        _dateFormat.format(tx.date),
        tx.direction == TransactionDirection.incoming ? 'Received' : 'Sent',
        'Not known',
      );
    }
  }

  /// Formats Monero transaction with all Monero-specific fields
  static String _formatMoneroTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
  ) {
    try {
      final dynamic moneroProp = tx;

      final amount = tx.amountFormatted().toString();
      final txId = tx.txHash.toString();
      final fee = moneroProp.feeFormatted();
      final note = moneroProp.note?.toString() ?? '';
      if (moneroProp.recipientAddress != null &&
          moneroProp.recipientAddress.toString().isNotEmpty) {
        recipientAddress = moneroProp.recipientAddress.toString();
      }

      final explorerLink = 'https://monero.com/tx/$txId';
      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount),
        _escapeCsvField(type),
        _escapeCsvField(fee.toString()),
        _escapeCsvField(txId),
        _escapeCsvField(recipientAddress),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      printV(e);
      // rethrow;
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Formats Bitcoin/Litecoin/Bitcoin Cash/Dogecoin transaction
  static String _formatElectrumTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
    WalletType walletType,
  ) {
    try {
      final dynamic electrumProp = tx;

      final amount = tx.amountFormatted().toString();
      final txId = tx.txHash.toString();
      final fee = electrumProp.feeFormatted().toString();
      // Try to get recipient from transaction
      if (electrumProp.to != null && electrumProp.to.toString().isNotEmpty) {
        recipientAddress = electrumProp.to.toString();
      }
      final note = electrumProp.note?.toString() ?? '';

      String explorerLink = 'N/A';
      switch (walletType) {
        case WalletType.bitcoin:
          explorerLink = 'https://blockchair.com/bitcoin/transaction/$txId';
          break;
        case WalletType.litecoin:
          explorerLink = 'https://blockchair.com/litecoin/transaction/$txId';
          break;
        case WalletType.bitcoinCash:
          explorerLink = 'https://blockchair.com/bitcoin-cash/transaction/$txId';
          break;
        case WalletType.dogecoin:
          explorerLink = 'https://blockchair.com/dogecoin/transaction/$txId';
          break;
        default:
          explorerLink = 'N/A';
      }

      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount),
        _escapeCsvField(type),
        _escapeCsvField(fee.toString()),
        _escapeCsvField(txId),
        _escapeCsvField(recipientAddress),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Formats EVM chain transaction (Ethereum, Polygon, Arbitrum, etc)
  static String _formatEVMTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
    WalletType walletType,
  ) {
    try {
      final dynamic evmProp = tx;

      final amount = evmProp.amountFormatted();
      final txId = tx.id;
      final fee = evmProp.feeFormatted().toString() ?? 'N/A';
      final note = evmProp.note?.toString() ?? '';

      if (evmProp.to != null && evmProp.to.toString().isNotEmpty) {
        recipientAddress = evmProp.to.toString();
      }

      String explorerLink = 'N/A';
      switch (walletType) {
        case WalletType.ethereum:
          explorerLink = 'https://etherscan.io/tx/$txId';
          break;
        case WalletType.polygon:
          explorerLink = 'https://polygonscan.com/tx/$txId';
          break;
        case WalletType.arbitrum:
          explorerLink = 'https://arbiscan.io/tx/$txId';
          break;
        case WalletType.base:
          explorerLink = 'https://basescan.org/tx/$txId';
          break;
        default:
          explorerLink = 'N/A';
      }

      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount.toString()),
        _escapeCsvField(type),
        _escapeCsvField(txId),
        _escapeCsvField(fee.toString()),
        _escapeCsvField(recipientAddress),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      printV(e);
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Formats Solana transaction
  static String _formatSolanaTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
  ) {
    try {
      final dynamic solanaProp = tx;
      final amount = solanaProp.amountFormatted();
      final txId = tx.txHash.toString();
      final fee = solanaProp.feeFormatted().toString();
      final note = solanaProp.note?.toString() ?? '';
      var to = '';
      if (solanaProp.to != null && solanaProp.to.toString().isNotEmpty) {
        to = solanaProp.to.toString();
      }

      final explorerLink = 'https://explorer.solana.com/tx/$txId';

      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount.toString()),
        _escapeCsvField(type),
        _escapeCsvField(txId),
        _escapeCsvField(fee),
        _escapeCsvField(to),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      printV("KB: $e");
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Formats Tron transaction
  static String _formatTronTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
  ) {
    try {
      final dynamic tronProp = tx;
      final amount = tx.amountFormatted().toString();
      final txId = tx.txHash.toString();
      final fee = tronProp.feeFormatted().toString();
      final note = tronProp.note?.toString() ?? '';
      if (tronProp.recipientAddress != null && tronProp.recipientAddress.toString().isNotEmpty) {
        recipientAddress = tronProp.recipientAddress.toString();
      }

      final explorerLink = 'https://tronscan.org/#/transaction/$txId';
      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount),
        _escapeCsvField(type),
        _escapeCsvField(fee),
        _escapeCsvField(txId),
        _escapeCsvField(recipientAddress),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      // rethrow;
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Formats Decred transaction
  static String _formatDecredTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
  ) {
    try {
      final dynamic decredProp = tx;

      final amount = tx.amountFormatted().toString();
      final height = tx.height.toString();
      final txId = tx.txHash.toString();
      final fee = decredProp.feeFormatted().toString();
      final note = decredProp.note?.toString() ?? '';
      if (decredProp.recipientAddress != null &&
          decredProp.recipientAddress.toString().isNotEmpty) {
        recipientAddress = decredProp.recipientAddress.toString();
      }

      final explorerLink = 'https://dcrdata.decred.org/tx/$txId';
      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount),
        _escapeCsvField(type),
        _escapeCsvField(height),
        _escapeCsvField(txId),
        _escapeCsvField(fee),
        _escapeCsvField(recipientAddress),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      return _formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Generic fallback formatter for unknown or unsupported wallet types
  static String _formatGenericTransaction(
    TransactionInfo tx,
    String timestamp,
    String type,
    String recipientAddress,
  ) {
    // To be finished

    try {
      final dynamic genericProp = tx;
      final amount = tx.amountFormatted();
      final height = tx.height.toString();
      final txId = tx.txHash.toString();
      final fee = genericProp.feeFormatted().toString();
      final note = genericProp.note?.toString() ?? '';
      final recipientAddress = tx.to;

      final explorerLink = 'N/A';

      final formattedData = [
        _escapeCsvField(timestamp),
        _escapeCsvField(amount.toString()),
        _escapeCsvField(type),
        _escapeCsvField(height),
        _escapeCsvField(txId),
        _escapeCsvField(fee),
        _escapeCsvField(recipientAddress!),
        _escapeCsvField(note),
        _escapeCsvField(explorerLink),
      ].join("','");

      var formattedString = "'" + formattedData + "'";
      return formattedString;
    } catch (e) {
      printV(e);
      rethrow;
      //_formatGenericTransaction(tx, timestamp, type, recipientAddress);
    }
  }

  /// Attempts to extract recipient address from transaction based on generic field names
  static String? _extractRecipientAddress(TransactionInfo tx) {
    try {
      final dynamic txProp = tx;

      // Try common field names
      if (txProp.to != null && txProp.to.toString().isNotEmpty) {
        return txProp.to.toString();
      }
      if (txProp.recipientAddress != null && txProp.recipientAddress.toString().isNotEmpty) {
        return txProp.recipientAddress.toString();
      }
      if (txProp.address != null && txProp.address.toString().isNotEmpty) {
        return txProp.address.toString();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extracts token symbol from transaction info or returns wallet's default currency
  /// Supports: EVMChainTransactionInfo, SolanaTransactionInfo, TronTransactionInfo,
  /// NanoTransactionInfo, ZanoTransactionInfo
  static String getTokenSymbol(TransactionInfo tx, WalletType walletType) {
    try {
      final dynamic txProp = tx;

      // Try to get tokenSymbol from transaction types that support it
      if (txProp.tokenSymbol != null && txProp.tokenSymbol.toString().isNotEmpty) {
        return txProp.tokenSymbol.toString();
      }
    } catch (e) {
      // If tokenSymbol property doesn't exist or throws error, fall through to default
    }

    return walletType.toString();
    // Return wallet's default currency symbol for wallets without multi-token support
  }
}
