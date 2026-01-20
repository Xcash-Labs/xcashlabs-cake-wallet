import 'dart:io' show Platform, File, Directory;

import 'package:flutter/material.dart' show BuildContext;
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:cake_wallet/utils/share_util.dart';
import 'package:cake_wallet/utils/transaction_export_formatter.dart';
import 'package:cake_wallet/utils/swap_export_formatter.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/currency_for_wallet_type.dart';

class ExportHistoryService {
  /// Generates CSV string from wallet transactions grouped by token symbol
  static String generateTransactionCSV({
    required WalletBase wallet,
  }) {
    final allTransactions = wallet.transactionHistory.transactions.values.toList();

    // Sort transactions chronologically (oldest first)
    final sortedTransactions = [...allTransactions]..sort((a, b) => a.date.compareTo(b.date));

    // Group transactions by token symbol
    final Map<String, List<TransactionInfo>> transactionsByToken = {};
    
    for (final tx in sortedTransactions) {
      final tokenSymbol = TransactionExportFormatter.getTokenSymbol(tx, wallet.type);
      if (!transactionsByToken.containsKey(tokenSymbol)) {
        transactionsByToken[tokenSymbol] = [];
      }
      transactionsByToken[tokenSymbol]!.add(tx);
    }

    // Get native token symbol for prioritization
    final nativeTokenSymbol = walletTypeToCryptoCurrency(wallet.type).title.toUpperCase();
    
    // Sort token symbols: native token first, then alphabetically
    final sortedTokenSymbols = transactionsByToken.keys.toList()..sort((a, b) {
      final aUpper = a.toUpperCase();
      final bUpper = b.toUpperCase();
      
      if (aUpper == nativeTokenSymbol && bUpper != nativeTokenSymbol) return -1;
      if (bUpper == nativeTokenSymbol && aUpper != nativeTokenSymbol) return 1;
      return aUpper.compareTo(bUpper);
    });

    // Build CSV string with sections per token
    final buffer = StringBuffer();
    
    for (int i = 0; i < sortedTokenSymbols.length; i++) {
      final tokenSymbol = sortedTokenSymbols[i];
      final transactions = transactionsByToken[tokenSymbol]!;
      
      // Skip empty groups
      if (transactions.isEmpty) continue;
      
      // Add section header with uppercase token symbol
      buffer.writeln('=== ${tokenSymbol.toUpperCase()} TRANSACTIONS ===');
      
      // Add CSV header
      buffer.writeln(TransactionExportData.csvHeader(walletType: wallet.type));
      
      // Format and add transactions for this token
      for (final tx in transactions) {
        buffer.writeln(TransactionExportFormatter.formatTransaction(tx, wallet.type));
      }
      
      // Add blank line between sections (except after last section)
      if (i < sortedTokenSymbols.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Generates CSV string from wallet swaps/trades
  static String generateSwapCSV({
    required TradesStore tradesStore,
    required String walletId,
  }) {
    final swaps = tradesStore.trades
        .where((trade) => trade.trade.walletId == walletId)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln(SwapExportData.csvHeader());

    for (final data in swaps) {
      buffer.writeln(SwapExportData.formatSwap(data.trade));
    }

    return buffer.toString();
  }

  /// Generates combined CSV string with both transactions and swaps
  static String generateCombinedCSV({
    required WalletBase wallet,
    required TradesStore tradesStore,
  }) {
    final transactionCSV = generateTransactionCSV(wallet: wallet);
    final swapCSV = generateSwapCSV(tradesStore: tradesStore, walletId: wallet.id);

    final buffer = StringBuffer();
    
    // Add transaction sections (already have their own token-based headers)
    buffer.write(transactionCSV);
    buffer.writeln();
    
    // Add swaps section
    buffer.writeln('=== SWAPS ===');
    buffer.write(swapCSV);

    return buffer.toString();
  }

  /// Saves CSV data to file (platform-specific handling)
  static Future<bool> saveToFile({
    required String csvContent,
    required String walletName,
    BuildContext? context,
  }) async {
    try {
      final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
      final timestamp = formatter.format(DateTime.now());
      final fileName = 'cakewallet_history_${walletName}_$timestamp.csv';

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: Use file picker
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Export',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(csvContent);

          if (context != null) {
            Fluttertoast.showToast(
              msg: 'Export saved successfully',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          }
          return true;
        }
        return false;
      } else if (Platform.isAndroid) {
        // Android: Save to Downloads folder
        const downloadDirPath = '/storage/emulated/0/Download';
        final filePath = '$downloadDirPath/$fileName';
        final file = File(filePath);

        if (file.existsSync()) {
          file.deleteSync();
        }
        await file.writeAsString(csvContent);

        if (context != null) {
          Fluttertoast.showToast(
            msg: 'Export saved to Downloads',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
        return true;
      } else if (Platform.isIOS) {
        // iOS: Save to temp and share
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsString(csvContent);

        if (context != null) {
          await ShareUtil.shareFile(
            filePath: tempFile.path,
            fileName: fileName,
            context: context,
          );

          // Clean up temp file
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        }
        return true;
      }

      return false;
    } catch (e) {
      printV('Error saving CSV file: $e');
      if (context != null) {
        Fluttertoast.showToast(
          msg: 'Export failed: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
      return false;
    }
  }

  /// Shares CSV data via share dialog (platform-specific handling)
  static Future<bool> shareFile({
    required String csvContent,
    required String walletName,
    required BuildContext context,
  }) async {
    try {
      final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
      final timestamp = formatter.format(DateTime.now());
      final fileName = 'cakewallet_history_${walletName}_$timestamp.csv';

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(csvContent);

      await ShareUtil.shareFile(
        filePath: tempFile.path,
        fileName: fileName,
        context: context,
      );

      // Clean up temp file after a delay to ensure sharing is complete
      Future.delayed(Duration(seconds: 2), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });

      return true;
    } catch (e) {
      printV('Error sharing CSV file: $e');
      Fluttertoast.showToast(
        msg: 'Export failed: ${e.toString()}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return false;
    }
  }
}
