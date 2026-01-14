import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_mnemonics_bip39.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

import 'dogecoin_wallet_addresses.dart';

part 'dogecoin_wallet.g.dart';

class DogeCoinWallet = DogeCoinWalletBase with _$DogeCoinWallet;

abstract class DogeCoinWalletBase extends ElectrumWallet with Store {
  DogeCoinWalletBase({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required DerivationInfo derivationInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Uint8List seedBytes,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    BitcoinAddressType? addressPageType,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
  }) : super(
            mnemonic: mnemonic,
            password: password,
            walletInfo: walletInfo,
            derivationInfo: derivationInfo,
            unspentCoinsInfo: unspentCoinsInfo,
            network: DogecoinNetwork.mainnet,
            initialAddresses: initialAddresses,
            initialBalance: initialBalance,
            seedBytes: seedBytes,
            currency: CryptoCurrency.doge,
            encryptionFileUtils: encryptionFileUtils,
            passphrase: passphrase) {
    walletAddresses = DogeCoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      mainHd: hd,
      sideHd: accountHD.childKey(Bip32KeyIndex(1)),
      network: network,
      initialAddressPageType: addressPageType,
      isHardwareWallet: walletInfo.isHardwareWallet,
    );
    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  @override
  int get networkDustAmount => 100000000; // 1 DOGE = 1e8 koinu

  static int estimatedDogeCoinTransactionSize(int inputsCount, int outputsCounts) =>
      inputsCount * 180 + outputsCounts * 34 + 10;

  @override
  int feeAmountForPriority(TransactionPriority priority, int inputsCount, int outputsCount,
          {int? size}) =>
      feeRate(priority) * (size ?? estimatedDogeCoinTransactionSize(inputsCount, outputsCount));

  @override
  int feeAmountWithFeeRate(int feeRate, int inputsCount, int outputsCount, {int? size}) =>
      feeRate * (size ?? estimatedDogeCoinTransactionSize(inputsCount, outputsCount));

  static Future<DogeCoinWallet> create(
      {required String mnemonic,
      required String password,
      required WalletInfo walletInfo,
      required DerivationInfo derivationInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      required EncryptionFileUtils encryptionFileUtils,
      String? passphrase,
      String? addressPageType,
      List<BitcoinAddressRecord>? initialAddresses,
      ElectrumBalance? initialBalance,
      Map<String, int>? initialRegularAddressIndex,
      Map<String, int>? initialChangeAddressIndex}) async {
    return DogeCoinWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      derivationInfo: derivationInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialBalance: initialBalance,
      seedBytes: MnemonicBip39.toSeed(mnemonic, passphrase: passphrase),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: P2pkhAddressType.p2pkh,
      passphrase: passphrase,
    );
  }

  static Future<DogeCoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    ElectrumWalletSnapshot? snp = null;

    try {
      snp = await ElectrumWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo.type,
        password,
        DogecoinNetwork.mainnet,
      );
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      keysData =
          WalletKeysData(mnemonic: snp!.mnemonic, xPub: snp.xpub, passphrase: snp.passphrase);
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    printV('Opening DogeCoinWallet with mnemonic: $keysData.mnemonic!');
    printV(snp?.addresses); // array of [BitcoinAddressRecord]
    printV(snp?.balance); // ElectrumBalance
    printV(snp?.regularAddressIndex); // {P2WPKH: 0}
    printV(snp?.changeAddressIndex); // {P2WPKH: 0} -- ?? TODO: check this - should be 1, right?
    printV(await walletInfo.getDerivationInfo());

    return DogeCoinWallet(
      mnemonic: keysData.mnemonic!,
      password: password,
      walletInfo: walletInfo,
      derivationInfo: await walletInfo.getDerivationInfo(),
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp?.addresses,
      initialBalance: snp?.balance,
      seedBytes: await MnemonicBip39.toSeed(keysData.mnemonic!, passphrase: keysData.passphrase),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: snp?.regularAddressIndex,
      initialChangeAddressIndex: snp?.changeAddressIndex,
      addressPageType: P2pkhAddressType.p2pkh,
      passphrase: keysData.passphrase,
    );
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    int? index;
    try {
      index = address != null
          ? walletAddresses.allAddresses.firstWhere((element) => element.address == address).index
          : null;
    } catch (_) {}
    final HD = index == null ? hd : hd.childKey(Bip32KeyIndex(index));
    final priv = ECPrivate.fromWif(
      WifEncoder.encode(HD.privateKey.raw, netVer: network.wifNetVer),
      netVersion: network.wifNetVer,
    );
    return priv.signMessage(StringUtils.encode(message));
  }

  // KB: Batches start here

  @action // taken from electrum_wallet.dart 1729
  Future<List<BitcoinUnspent>?> fetchUnspent(BitcoinAddressRecord address) async {
    List<BitcoinUnspent> updatedUnspentCoins = [];

    final unspents = await electrumClient.getListUnspent(address.getScriptHash(network));

    // Failed to fetch unspents
    if (unspents == null) return null;

    await Future.wait(unspents.map((unspent) async {
      try {
        final coin = BitcoinUnspent.fromJSON(address, unspent);
        final tx = await fetchTransactionInfo(hash: coin.hash);
        coin.isChange = address.isHidden;
        coin.confirmations = tx?.confirmations;

        updatedUnspentCoins.add(coin);
      } catch (_) {}
    }));

    return updatedUnspentCoins;
  }

  // KB -- new batched function fetches unspents from multiple addresses at once
  // Uses batchGetData from electrum client
  Future<List<BitcoinUnspent>?> batchFetchUnspent(List<BitcoinAddressRecord> addresses) async {
    List<BitcoinUnspent> updatedUnspentCoins = [];
    // script hashes needed for all unspent coins
    final List<String> scriptHashes = [];

    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = addressRecord.getScriptHash(network);
      scriptHashes.add(sh);
    }
    // We now have a batch of script hashes, invoke batchGetData with the method blockchain.scripthash.listunspent
    var batchResult = await batchGetData(scriptHashes, 'blockchain.scripthash.listunspent');
    printV(batchResult);
  }

  // This function had to be implemented in electrumclient due to socket writes
  // Future<Map<String, Map<String, dynamic>>> batchGetData(
  Future<dynamic> batchGetData(List<String> scriptHashes, String method) async {
    var batchData = await electrumClient.batchGetData(scriptHashes, method);
    printV("Dogecoin batchGetData prepped scripthashes: $batchData");
    return await electrumClient.batchGetData(scriptHashes, method);
  }

  Future<void> batchGetListUnspent(List<String> scriptHashes) async {
    // get a list of all addresses and calculate their scriptHashes, batching them

    throw UnimplementedError("batchGetListUnspent is not yet implemented");
  }

  // Original
  // Future<List<Map<String, dynamic>>?> getListUnspent(String scriptHash) async {
  //   try {
  //     final result = await call(method: 'blockchain.scripthash.listunspent', params: [scriptHash]);

  //     if (result is List) {
  //       return result.map((dynamic val) {
  //         if (val is Map<String, dynamic>) {
  //           return val;
  //         }

  //         return <String, dynamic>{};
  //       }).toList();
  //     }

  //     return null;
  //   } catch (e) {

  //     return null;
  // }

  // Original
  Future<void> updateCoins(List<BitcoinUnspent> newUnspentCoins) async {
    if (newUnspentCoins.isEmpty) {
      return;
    }

    newUnspentCoins.forEach((coin) {
      final coinInfoList = unspentCoinsInfo.values.where(
        (element) =>
            element.walletId.contains(id) &&
            element.hash.contains(coin.hash) &&
            element.vout == coin.vout,
      );

      if (coinInfoList.isNotEmpty) {
        final coinInfo = coinInfoList.first;

        coin.isFrozen = coinInfo.isFrozen;
        coin.isSending = coinInfo.isSending;
        coin.note = coinInfo.note;

        if (coin.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord)
          coin.bitcoinAddressRecord.balance += coinInfo.value;
      } else {
        addCoinInfo(coin);
      }
    });
  }

  Future<void> _refreshUnspentCoinsInfo() async {
    try {
      final List<dynamic> keys = [];
      final currentWalletUnspentCoins =
          unspentCoinsInfo.values.where((record) => record.walletId == id);

      for (final element in currentWalletUnspentCoins) {
        if (RegexUtils.addressTypeFromStr(element.address, network) is MwebAddress) continue;

        final existUnspentCoins = unspentCoins.where((coin) => element == coin);

        if (existUnspentCoins.isEmpty) {
          keys.add(element.key);
        }
      }

      if (keys.isNotEmpty) {
        await unspentCoinsInfo.deleteAll(keys);
      }
    } catch (e) {
      printV("refreshUnspentCoinsInfo $e");
    }
  }

  @override
  Future<ElectrumBalance> fetchBalances() async {
    printV("fetchBalances called at ${DateTime.now().toIso8601String()}");
    final addresses = walletAddresses.allAddresses
        .where((address) => address.address.isNotEmpty)
        .where((address) => RegexUtils.addressTypeFromStr(address.address, network) is! MwebAddress)
        .toList();

    printV("fetchBalances: Found ${addresses.length} addresses");

    if (addresses.isEmpty) {
      printV("fetchBalances: No addresses found, returning zero balance");
      return ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    }

    // printV("First address: ${addresses[0].address}");
    // printV("First scripthash: ${addresses[0].getScriptHash(network)}");

    // Let's set up a fall-back based call to batchBalance fetching. If it fails, we'll just continue through all processing in fetchBalances
    try {
      final balances = await batchFetchBalances();
      return balances;
    } catch (e) {
      printV("batchFetchBalances failed with error: $e");
      // Handle this node by not supporting batch calls
    }

    final balanceFutures = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = addressRecord.getScriptHash(network);
      final balanceFuture = electrumClient.getBalance(sh);
      balanceFutures.add(balanceFuture);
    }

    printV("fetchBalances: Initiated balance fetch for all addresses");

    var totalFrozen = 0;
    var totalConfirmed = 0;
    var totalUnconfirmed = 0;

    printV("Calling unspentCoinsInfo processing");
    unspentCoinsInfo.values.forEach((info) {
      unspentCoins.forEach((element) {
        if (element.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) return;

        if (element.hash == info.hash &&
            element.vout == info.vout &&
            element.bitcoinAddressRecord.address == info.address &&
            element.value == info.value) {
          if (info.isFrozen) {
            totalFrozen += element.value;
          }
        }
      });
    });
    printV("Awaiting balance futures");

    final balances = await Future.wait(balanceFutures);
    if (balances.isNotEmpty && balances.first['confirmed'] == null) {
      // if we got null balance responses from the server, set our connection status to lost and return our last known balance:
      printV("got null balance responses from the server, setting connection status to lost");
      syncStatus = LostConnectionSyncStatus();
      return balance[currency] ?? ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    }

    for (var i = 0; i < balances.length; i++) {
      // for each returned value from batchGetData, we need to re-order them to match the deterministic order we pass them in as
      // TODO: Fix this, probably best in electrum.dart
      final addressRecord = addresses[i];
      final balance = balances[i];
      final confirmed = balance['confirmed'] as int? ?? 0;
      final unconfirmed = balance['unconfirmed'] as int? ?? 0;
      totalConfirmed += confirmed;
      totalUnconfirmed += unconfirmed;

      addressRecord.balance = confirmed + unconfirmed;
      if (confirmed > 0 || unconfirmed > 0) {
        addressRecord.setAsUsed();
        walletAddresses.clearLockIfMatches(addressRecord.type, addressRecord.address);
      }
    }

    return ElectrumBalance(
      confirmed: totalConfirmed,
      unconfirmed: totalUnconfirmed,
      frozen: totalFrozen,
    );
  }

  // While this isn't the history (which would give us better performance enhancements), it's still good to batch this to optimise balance fetching
  // Future<void> batchFetchBalances() async {
  Future<ElectrumBalance> batchFetchBalances() async {
    final addresses = walletAddresses.allAddresses
        .where((address) => address.address.isNotEmpty)
        .where((address) => RegexUtils.addressTypeFromStr(address.address, network) is! MwebAddress)
        .toList();

    printV('batchFetchBalances: Processing ${addresses.length} addresses');

    // Collect all script hashes
    final List<String> scriptHashes = [];
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = addressRecord.getScriptHash(network);
      scriptHashes.add(sh);
      printV('Address[$i]: ${addressRecord.address} -> ScriptHash: $sh');
    }
    final String method = "blockchain.scripthash.get_balance";

    var test = await electrumClient.batchGetData(scriptHashes, method);

    printV(test);

    printV('Total script hashes to query: ${scriptHashes.length}');
    printV('Script hashes list: $scriptHashes');

    var totalFrozen = 0;
    var totalConfirmed = 0;
    var totalUnconfirmed = 0;

    // BTC only I believe?
    // if (hasSilentPaymentsScanning) {
    //   // Add values from unspent coins that are not fetched by the address list
    //   // i.e. scanned silent payments
    //   transactionHistory.transactions.values.forEach((tx) {
    //     if (tx.unspents != null) {
    //       tx.unspents!.forEach((unspent) {
    //         if (unspent.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
    //           if (unspent.isFrozen) totalFrozen += unspent.value;
    //           totalConfirmed += unspent.value;
    //         }
    //       });
    //     }
    //   });
    // }

    unspentCoinsInfo.values.forEach((info) {
      unspentCoins.forEach((element) {
        if (element.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) return;

        if (element.hash == info.hash &&
            element.vout == info.vout &&
            element.bitcoinAddressRecord.address == info.address &&
            element.value == info.value) {
          if (info.isFrozen) {
            totalFrozen += element.value;
          }
        }
      });
    });

    // Make single batch call instead of parallel individual calls
    printV('Calling batchGetBalances with ${scriptHashes.length} script hashes...');
    final balancesMap =
        await electrumClient.batchGetData(scriptHashes, 'blockchain.scripthash.get_balance');
    printV('Received batch response with ${balancesMap.length} results');
    printV('Balances map: $balancesMap');

    if (balancesMap.isEmpty && scriptHashes.isNotEmpty) {
      // if we got empty response from the server, set our connection status to lost and return our last known balance:
      printV("got empty batch balance response from the server, setting connection status to lost");
      syncStatus = LostConnectionSyncStatus();
      return balance[currency] ?? ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    }

    // Process results
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = scriptHashes[i];
      final balanceData = balancesMap[sh] ?? {};

      if (balanceData.isEmpty || balanceData['confirmed'] == null) {
        printV('Warning: No balance data for address ${addressRecord.address} (sh: $sh)');
        continue;
      }

      final confirmed = balanceData['confirmed'] as int? ?? 0;
      final unconfirmed = balanceData['unconfirmed'] as int? ?? 0;

      printV('Address ${addressRecord.address}: confirmed=$confirmed, unconfirmed=$unconfirmed');

      totalConfirmed += confirmed;
      totalUnconfirmed += unconfirmed;

      addressRecord.balance = confirmed + unconfirmed;
      if (confirmed > 0 || unconfirmed > 0) {
        addressRecord.setAsUsed();
        walletAddresses.clearLockIfMatches(addressRecord.type, addressRecord.address);
      }
    }

    printV(
        'Final totals - Confirmed: $totalConfirmed, Unconfirmed: $totalUnconfirmed, Frozen: $totalFrozen');

    return ElectrumBalance(
      confirmed: totalConfirmed,
      unconfirmed: totalUnconfirmed,
      frozen: totalFrozen,
    );
  }
}
