import 'dart:async';
import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_mnemonics_bip39.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum.dart' as electrum;
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

  // KB -- new batched function fetches unspents from multiple addresses at once
  // Uses batchGetData from electrum client
  Future<List<BitcoinUnspent>?> batchFetchUnspentDoge(List<BitcoinAddressRecord> addresses) async {
    List<BitcoinUnspent> updatedUnspentCoins = [];
    // script hashes needed for all unspent coins
    final List<String> scriptHashes = [];
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = addressRecord.getScriptHash(network);
      scriptHashes.add(sh);
    }
    // We now have a batch of script hashes, invoke batchGetData with the method blockchain.scripthash.listunspent
    // batchGetData returns a list sorted by id, so it aligns with the list of unspents
    var batchResult = await batchGetDogeData(scriptHashes, 'blockchain.scripthash.listunspent');

    return batchResult;
    // TODO: Batch result handling time
  }

  // This function wraps one in electrum.dart due to socket writes
  // Future<Map<String, Map<String, dynamic>>> batchGetData(
  Future<dynamic> batchGetDogeData(List<String> scriptHashes, String method) async {
    var batchData = await electrumClient.batchGetData(scriptHashes, method);
    printV("Dogecoin batchGetData prepped scripthashes: $batchData");
    return await electrumClient.batchGetData(scriptHashes, method);
  }

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

  // Overrides electrum_wallet to implement try-catch method
  Future<void> updateBalance() async {
    try {
      balance[currency] = await batchFetchDogeBalances();
      await save();
      printV("Batch fetch works!");
    } catch (e) {
      printV("Batch fetch broke!");
      balance[currency] = await fetchBalances();
      await save();
    }
  }

  @override
  Future<ElectrumBalance> fetchBalances() async {
    try {
      balance[currency] = await batchFetchDogeBalances();
      await save();
      printV("Batch fetch works! Yay!");
    } catch (e) {
      printV("Batch fetch broke! Sad!");
      printV("Batch failed: $e");
      // We use the original method of iterating through each address and making a call
      final addresses = walletAddresses.allAddresses
          .where((address) => address.address.isNotEmpty)
          .where(
              (address) => RegexUtils.addressTypeFromStr(address.address, network) is! MwebAddress)
          .toList();

      printV("fetchBalances: Found ${addresses.length} addresses");

      if (addresses.isEmpty) {
        printV("fetchBalances: No addresses found, returning zero balance");
        return ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
      }

      // Create map of scriptHash -> addressRecord for batching
      final Map<String, BitcoinAddressRecord> scriptHashToAddress = {};
      final List<String> scriptHashes = [];

      for (var i = 0; i < addresses.length; i++) {
        final addressRecord = addresses[i];
        final sh = addressRecord.getScriptHash(network);
        scriptHashToAddress[sh] = addressRecord;
        scriptHashes.add(sh);
      }

      printV("fetchBalances: Initiated non-batched balance fetch for all addresses");

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
      printV("Fetching balances using batch method");

      // Use batched request instead of individual futures
      final balances =
          await electrumClient.batchGetData(scriptHashes, 'blockchain.scripthash.get_balance');

      if (balances.isNotEmpty && balances.first['confirmed'] == null) {
        // if we got null balance responses from the server, set our connection status to lost and return our last known balance:
        printV("got null balance responses from the server, setting connection status to lost");
        syncStatus = LostConnectionSyncStatus();
        return balance[currency] ?? ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
      }

      for (var i = 0; i < balances.length; i++) {
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

    throw Exception("This should never be possible without it being handled above");
  }

  // We're having problems retrieving balances now. This will be due to _parseResponse
  // The intention of the batch functions is for them to be called instead of singles, and if it fails, call the method for single requests.
  // This allows for a simple try-catch usage pattern
  // While this isn't the history (which would give us better performance enhancements), it's still good to batch this to optimise balance fetching
  // Future<void> batchFetchDogeBalances() async {
  Future<ElectrumBalance> batchFetchDogeBalances() async {
    final addresses = walletAddresses.allAddresses
        .where((address) => address.address.isNotEmpty)
        .where((address) => RegexUtils.addressTypeFromStr(address.address, network) is! MwebAddress)
        .toList();
    printV("KB: Address is ${addresses[0].address}");
    printV("KB: Current balance is: ${addresses[0].balance}");
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

    var balanceResponse = await getIsolateBatch(scriptHashes, method);

    printV('Total script hashes to query: ${scriptHashes.length}');
    printV('Script hashes list: $scriptHashes');

    var totalFrozen = 0;
    var totalConfirmed = 0;
    var totalUnconfirmed = 0;

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
    // final balancesList =
    //     await electrumClient.batchGetData(scriptHashes, 'blockchain.scripthash.get_balance');
    final balancesBatch = await getIsolateBatch(scriptHashes, 'blockchain.scripthash.get_balance');
    var balancesList = json.decode(balancesBatch);

    if (balancesList.isEmpty && scriptHashes.isNotEmpty) {
      // Don't be surprised if this code fires if we scan a large enough wallet. It'll get disconnected in the middle of responses,
      // leaving us in a difficult situation if we got empty response from the
      // server, set our connection status to lost and return our last known balance:
      printV("got empty batch balance response from the server, setting connection status to lost");
      syncStatus = LostConnectionSyncStatus();
      return balance[currency] ?? ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    }
    // Process results - balancesList is an array of response objects
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = scriptHashes[i];

      // Get the response object at index i and extract the 'result' field
      final responseObj = balancesList[i] as Map<String, dynamic>?;
      final balanceData = responseObj?['result'] as Map<String, dynamic>? ?? {};

      // printV("KB: result being processed: $i for ${addressRecord.address}");
      if (balanceData.isEmpty || balanceData['confirmed'] == null) {
        // printV('Warning: No balance data for address ${addressRecord.address} (sh: $sh)');
        continue;
      }

      final confirmed = balanceData['confirmed'] as int? ?? 0;
      final unconfirmed = balanceData['unconfirmed'] as int? ?? 0;

      // printV('Address ${addressRecord.address}: confirmed=$confirmed, unconfirmed=$unconfirmed');

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

  Future<String> getIsolateBatch(
    List<String> addressToScriptHashes,
    String method, {
    bool? useSSL,
    int batchSize = 30,
    void Function(int current, int total)? onProgress,
  }) async {
    // Initialize Tor for proxy support
    // CakeTor.instance = await CakeTorInstance.getInstance();

    // Create ElectrumClient instance
    final client = electrum.ElectrumClient();
    batchGetDogeData(scriptHashes, method);
    try {
      // Connect using electrum.dart's connectToUri method
      printV("KB: GetIsolateBatch: connecting");
      var node = super.node!;
      var uri = node.uri;

      await client.connectToUri(uri, useSSL: useSSL).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timeout after 15s');
        },
      );

      client.onConnectionStatusChange?.call(electrum.ConnectionStatus.connected);

      printV("KB: GetIsolateBatch: Waiting 1 seconds...");
      await Future.delayed(Duration(seconds: 1));

      // Split scriptHashes into batches of size batchSize.

      final totalScriptHashes = addressToScriptHashes.length;
      final numBatches = (totalScriptHashes / batchSize).ceil();
      printV(
          "KB: GetIsolateBatch: Processing $totalScriptHashes script hashes in $numBatches batches of $batchSize");

      final List<dynamic> allResponses = [];

      for (int i = 0; i < numBatches; i++) {
        final startIndex = i * batchSize;
        final endIndex = (startIndex + batchSize).clamp(0, totalScriptHashes);
        final batch = addressToScriptHashes.sublist(startIndex, endIndex);

        printV(
            "KB: GetIsolateBatch: Processing batch ${i + 1}/$numBatches (${batch.length} items)");

        // Call progress callback if provided
        //onProgress?.call(i + 1, numBatches);

        // Use electrum.dart's batchGetData method for this batch
        final response = await client.batchGetData(batch, method);
        printV("KB: Response mutation");
        printV(response);
        final decodedResponse = jsonDecode(response);
        printV(decodedResponse);
        printV("KB: GetIsolateBatch: Batch ${i + 1} response received");

        if (response != null) {
          allResponses.addAll(response);
        }

        // Delay 2 seconds between batches (except for the last batch)
        if (i < numBatches - 1) {
          printV("KB: GetIsolateBatch: Waiting 2 seconds before next batch...");
          await Future.delayed(Duration(seconds: 1));
        }
      }

      printV("KB: GetIsolateBatch: All batches processed. Total responses: ${allResponses.length}");

      // Close connection
      await client.closeIsolateBatch();

      return allResponses.join();
    } catch (e) {
      printV('[IsolateBatcher] Error: $e');
      await client.closeIsolateBatch();
      rethrow;
    }
  }
}
