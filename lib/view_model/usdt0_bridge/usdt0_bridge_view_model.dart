import 'dart:async';

import 'package:cake_wallet/core/wallet_change_listener_view_model.dart';
import 'package:cake_wallet/entities/bridge_transfer.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/core/layerzero_scan_service.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/bridge_transfers_store.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:mobx/mobx.dart';

part 'usdt0_bridge_view_model.g.dart';

class USDT0BridgeViewModel = USDT0BridgeViewModelBase with _$USDT0BridgeViewModel;

abstract class USDT0BridgeViewModelBase extends WalletChangeListenerViewModel with Store {
  USDT0BridgeViewModelBase({
    required AppStore appStore,
    required this.bridgeTransfersStore,
  }) : super(appStore: appStore);

  void Function()? onBridgeSuccess;
  final Map<String, Completer<void>> _pollingCancellers = {};
  final BridgeTransfersStore bridgeTransfersStore;

  @observable
  CryptoCurrency? selectedToken;

  @observable
  int? destinationChainId;

  @observable
  String amount = '';

  @observable
  String recipientAddress = '';

  @observable
  USDT0Quote? quote;

  @observable
  bool isQuoteLoading = false;

  @observable
  String? quoteError;

  @observable
  bool isExecuting = false;

  @observable
  String? executeError;

  @observable
  bool bridgeSuccess = false;

  @observable
  BridgeTransfer? lastCreatedBridgeTransfer;

  @computed
  List<ChainInfo> get availableDestinationChains {
    if (!isEVMCompatibleChain(wallet.type)) return [];
    return evm!.getUSDT0DestinationChains(wallet);
  }

  @computed
  List<Erc20Token> get availableUSDT0Tokens {
    if (!isEVMCompatibleChain(wallet.type)) return [];
    final tokens = wallet.balance.keys.whereType<Erc20Token>();
    return tokens.where((token) => evm!.isUSDT0Token(wallet, token)).toList(growable: false);
  }

  @computed
  int? get sourceChainId => evm!.getSelectedChainId(wallet);

  @action
  void setDestinationChain(int chainId) {
    destinationChainId = chainId;
    quote = null;
    quoteError = null;
    executeError = null;
  }

  @action
  void setSelectedToken(CryptoCurrency token) {
    selectedToken = token;
    quote = null;
    quoteError = null;
    executeError = null;
  }

  @action
  void setAmount(String value) {
    amount = value;
    quote = null;
    quoteError = null;
    executeError = null;
  }

  @action
  void setRecipientAddress(String value) {
    recipientAddress = value;
    quote = null;
    quoteError = null;
    executeError = null;
  }

  bool get canShowBridge => isEVMCompatibleChain(wallet.type) && availableUSDT0Tokens.isNotEmpty;

  @computed
  BigInt get selectedTokenBalance {
    final token = selectedToken;
    if (token == null) return BigInt.zero;
    final bal = wallet.balance[token];
    if (bal is EVMChainERC20Balance) return bal.balance;
    return BigInt.zero;
  }

  @computed
  String? get amountError {
    final token = selectedToken;
    if (token == null || amount.isEmpty) return null;
    if (token is! Erc20Token) return null;

    final amountBigInt = token.tryParseAmount(amount.replaceAll(',', '.'));
    if (amountBigInt == null || amountBigInt == BigInt.zero) return null;
    if (amountBigInt > selectedTokenBalance) {
      return "Insufficient balance for ${token.title} token.";
    }

    return null;
  }

  @action
  void ensureDefaultSelection() {
    if (selectedToken == null && availableUSDT0Tokens.isNotEmpty) {
      selectedToken = availableUSDT0Tokens.first;
    }
    if (destinationChainId == null && availableDestinationChains.isNotEmpty) {
      destinationChainId = availableDestinationChains.first.chainId;
    }
  }

  @action
  Future<void> loadQuote() async {
    final src = sourceChainId;
    final dst = destinationChainId;
    final token = selectedToken;

    if (src == null || dst == null || token == null || amount.isEmpty || recipientAddress.isEmpty) {
      quoteError = 'Fill all fields';
      return;
    }

    if (token is! Erc20Token) return;

    final amountBigInt = token.tryParseAmount(amount.replaceAll(',', '.'));
    if (amountBigInt == null || amountBigInt == BigInt.zero) {
      quoteError = 'Invalid amount';
      return;
    }

    if (amountBigInt > selectedTokenBalance) {
      quoteError = "Insufficient balance for ${token.title} token.";
      return;
    }

    isQuoteLoading = true;
    quoteError = null;
    quote = null;
    executeError = null;

    try {
      quote = await evm!.quoteUSDT0Transfer(
        wallet: wallet,
        sourceChainId: src,
        destinationChainId: dst,
        amount: amountBigInt,
        recipientAddress: recipientAddress.trim(),
      );
    } catch (e) {
      quoteError = e.toString();
    } finally {
      isQuoteLoading = false;
    }
  }

  @action
  Future<void> executeBridge() async {
    final src = sourceChainId;
    final dst = destinationChainId;
    final token = selectedToken;

    if (src == null ||
        dst == null ||
        token == null ||
        amount.isEmpty ||
        recipientAddress.isEmpty ||
        quote == null) {
      executeError = 'Get a quote first';
      return;
    }

    if (token is! Erc20Token) return;

    final amountBigInt = token.tryParseAmount(amount.replaceAll(',', '.'));
    if (amountBigInt == null || amountBigInt == BigInt.zero) {
      executeError = 'Invalid amount';
      return;
    }

    if (amountBigInt > selectedTokenBalance) {
      executeError = "Insufficient balance for ${token.title} token.";
      return;
    }

    isExecuting = true;
    executeError = null;
    try {
      final priority = EVMChainTransactionPriority.medium;
      final pending = await evm!.executeUSDT0Transfer(
        wallet: wallet,
        token: token,
        sourceChainId: src,
        destinationChainId: dst,
        amount: amountBigInt,
        recipientAddress: recipientAddress.trim(),
        quote: quote!,
        priority: priority as TransactionPriority,
        useBlinkProtection: canSupportBlinkProtection(src),
      );

      final sourceTxHash = pending.evmTxHashFromRawHex ?? pending.id;
      await pending.commit();

      final record = BridgeTransfer(
        id: '${sourceTxHash}_${DateTime.now().millisecondsSinceEpoch}',
        walletId: wallet.name,
        sourceChainId: src,
        destinationChainId: dst,
        tokenSymbol: token.title,
        tokenContract: token.contractAddress,
        amount: amount,
        recipientAddress: recipientAddress.trim(),
        sourceTxHash: sourceTxHash,
        status: 'submitted',
        createdAt: DateTime.now(),
      );

      bridgeTransfersStore.addTransfer(record);
      runInAction(() {
        quote = null;
        bridgeSuccess = true;
        lastCreatedBridgeTransfer = record;
      });
      onBridgeSuccess?.call();
      _pollForSourceConfirmation(record, wallet);
    } catch (e) {
      executeError = e.toString();
    } finally {
      isExecuting = false;
    }
  }

  static const _pollInterval = Duration(seconds: 2);
  static const _pollTimeout = Duration(minutes: 3);
  static const _destinationPollInterval = Duration(seconds: 5);
  static const _destinationPollTimeout = Duration(minutes: 10);

  @override
  void onWalletChange(WalletBase wallet) {
    _cancelAllPolling();
    _resumePollingForActiveTransfers(wallet);
  }

  void _cancelAllPolling() {
    for (final canceller in _pollingCancellers.values) {
      if (!canceller.isCompleted) {
        canceller.complete();
      }
    }
    _pollingCancellers.clear();
  }

  void _resumePollingForActiveTransfers(WalletBase wallet) {
    if (!isEVMCompatibleChain(wallet.type)) return;

    final activeTransfers = bridgeTransfersStore.bridgeTransfers
        .where((t) => t.walletId == wallet.name && t.isActive)
        .toList();

    for (final transfer in activeTransfers) {
      if (transfer.status == 'submitted' || transfer.status == 'confirming') {
        _pollForSourceConfirmation(transfer, wallet);
      } else if (transfer.status == 'initiated') {
        _pollForDestinationCompletion(transfer, wallet);
      }
    }
  }

  bool _isValidWalletContext(String expectedWalletId) {
    return wallet.name == expectedWalletId &&
        isEVMCompatibleChain(wallet.type) &&
        !_pollingCancellers.values.any((c) => c.isCompleted);
  }

  void _updateTransferStatus(
    BridgeTransfer record,
    String status, {
    String? errorMessage,
    String? statusMessage,
    DateTime? confirmedAt,
  }) {
    if (!_isValidWalletContext(record.walletId)) return;

    runInAction(() {
      record.updatedAt = DateTime.now();
      record.status = status;
      if (errorMessage != null) record.errorMessage = errorMessage;
      if (statusMessage != null) record.statusMessage = statusMessage;
      if (confirmedAt != null) record.confirmedAt = confirmedAt;
      bridgeTransfersStore.updateTransfer(record);
    });
  }

  Future<void> _pollForSourceConfirmation(
    BridgeTransfer record,
    WalletBase wallet,
  ) async {
    final canceller = Completer<void>();
    _pollingCancellers[record.id] = canceller;
    final walletId = wallet.name;
    final deadline = DateTime.now().add(_pollTimeout);

    try {
      while (DateTime.now().isBefore(deadline)) {
        await Future.any([
          Future.delayed(_pollInterval),
          canceller.future,
        ]);

        if (canceller.isCompleted || !_isValidWalletContext(walletId)) return;

        bool? receipt;
        try {
          receipt = await evm!.getTransactionReceipt(wallet, record.sourceTxHash);
        } catch (e) {
          printV('USDT0 bridge: Error fetching receipt: $e');
          continue;
        }

        if (receipt == null) continue;

        if (receipt == true) {
          _updateTransferStatus(
            record,
            'confirming',
            confirmedAt: DateTime.now(),
          );

          await Future.delayed(const Duration(seconds: 1));
          if (canceller.isCompleted || !_isValidWalletContext(walletId)) return;

          _updateTransferStatus(record, 'initiated');
          _pollForDestinationCompletion(record, wallet);

          return;
        } else if (receipt == false) {
          _updateTransferStatus(
            record,
            'failed',
            errorMessage: 'Transaction reverted',
          );
          return;
        }
      }

      if (!_isValidWalletContext(walletId)) return;

      _updateTransferStatus(record, 'initiated');
      _pollForDestinationCompletion(record, wallet);
    } finally {
      _pollingCancellers.remove(record.id);
    }
  }

  Future<void> _pollForDestinationCompletion(
    BridgeTransfer record,
    WalletBase wallet,
  ) async {
    final canceller = Completer<void>();
    _pollingCancellers['${record.id}_dest'] = canceller;
    final walletId = wallet.name;
    final deadline = DateTime.now().add(_destinationPollTimeout);

    try {
      while (DateTime.now().isBefore(deadline)) {
        await Future.any([
          Future.delayed(_destinationPollInterval),
          canceller.future,
        ]);

        if (canceller.isCompleted || !_isValidWalletContext(walletId)) return;

        LayerZeroMessageStatus? status;
        try {
          status = await LayerZeroScanService.getMessageStatus(record.sourceTxHash);
        } catch (e) {
          printV('USDT0 bridge: Error fetching LayerZero status: $e');
          continue;
        }

        if (status == null) continue;

        if (status.isDelivered) {
          _updateTransferStatus(
            record,
            'completed',
            statusMessage: status.status?.message,
          );
          return;
        }

        if (status.isFailed) {
          _updateTransferStatus(
            record,
            'failed',
            errorMessage: status.status?.message ?? 'Bridge message failed',
            statusMessage: status.status?.message,
          );
          return;
        }

        _updateTransferStatus(
          record,
          record.status,
          statusMessage: status.status?.message,
        );
      }
    } finally {
      _pollingCancellers.remove('${record.id}_dest');
    }
  }

  @action
  void clearBridgeSuccess() {
    bridgeSuccess = false;
    lastCreatedBridgeTransfer = null;
  }

  void dispose() {
    _cancelAllPolling();
  }
}
