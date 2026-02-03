import 'package:cake_wallet/core/wallet_change_listener_view_model.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:mobx/mobx.dart';

part 'usdt0_bridge_view_model.g.dart';

class USDT0BridgeViewModel = USDT0BridgeViewModelBase with _$USDT0BridgeViewModel;

abstract class USDT0BridgeViewModelBase extends WalletChangeListenerViewModel with Store {
  USDT0BridgeViewModelBase(AppStore appStore) : super(appStore: appStore);

  void Function()? onBridgeSuccess;

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
      await pending.commit();
      runInAction(() {
        quote = null;
        bridgeSuccess = true;
      });
      onBridgeSuccess?.call();
    } catch (e) {
      executeError = e.toString();
    } finally {
      isExecuting = false;
    }
  }

  @action
  void clearBridgeSuccess() => bridgeSuccess = false;
}
