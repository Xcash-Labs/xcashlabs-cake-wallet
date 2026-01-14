import 'dart:io';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_zcash/src/util/hex_uint8list.dart';
import 'package:cw_zcash/src/warp_api/models.dart';
import 'package:convert/src/hex.dart';
import 'package:zkool/src/rust/api/account.dart' as zkool_account;
import 'package:zkool/src/rust/api/coin.dart' as zkool_coin;
import 'package:zkool/src/rust/api/sync.dart' as zkool_sync;
import 'package:zkool/src/rust/api/pay.dart' as zkool_pay;
import 'package:zkool/src/rust/api/key.dart' as zkool_key;
import 'package:zkool/src/rust/api/network.dart' as zkool_network;
import 'package:zkool/src/rust/pay.dart' as zkool_paydart;
import 'package:zkool/src/rust/frb_generated.dart' as zkool_frb;

class WarpApi {
  static var c = zkool_coin.Coin();

  static bool _init = false;
  static Future<void> init(final Directory dbFile) async {
    if (_init) return;
    _init = true;
    printV("WarpApi: .init()");
    await zkool_frb.RustLib.init();
    await zkool_network.initDatadir(directory: dbFile.parent.path);
    final c2 = await c.openDatabase(dbFilepath: dbFile.path, password: 'cw_zcash');
    c = c2;
    printV("WarpApi: .init(): Done");
  }

  // static final Map<int, zkool_coin.Coin> _accountMap = {};
  static Future<zkool_account.Addresses> getAddress(
    final int _,
    final int id,
    final int uaType,
  ) async {
    c = await c.setAccount(account: id);
    final addr = (await zkool_account.getAddresses(uaPools: uaType, c: c));
    printV("addr: ${addr.ua} / ${addr.taddr} / ${addr.oaddr} / ${addr.saddr}");
    return addr;
  }

  static Future<String> getTAddr(final int _, final int id) async {
    c = await c.setAccount(account: id);
    final addr = await getAddress(0, id, 1);
    return addr.taddr ?? 'getTaddr null';
  }

  static Future<void> cancelSync() => zkool_sync.cancelSync();

  static Future<void> updateLWD(final int _, final int id, final String url) async {
    c = await c.setAccount(account: id);
    final c2 = c.setLwd(url: url, serverType: 0); // 0 - light node
    c = c2;
  }

  static PaymentURI? decodePaymentURI(final int _, final String uri) {
    final recipients = zkool_pay.parsePaymentUri(uri: uri);
    if (recipients == null) {
      return null;
    }
    if (recipients.length != 1) {
      printV("recipients.length != 1");
      return null;
    }
    return PaymentURI(address: recipients[0].address, amount: recipients[0].amount.toInt());
  }

  static bool validAddress(final int _, final String address) {
    return zkool_key.isValidAddress(address: address);
  }

  static Future<String> prepareTx(
    final int _,
    final int account,
    final List<Recipient> recipients,
    final int pools,
    final int senderUAType,
    final int anchorOffset,
    final FeeT fee,
  ) async {
    c = await c.setAccount(account: account);
    final pcztPackage = await zkool_pay.prepare(
      recipients: recipients
          .map(
            (final oldR) =>
                zkool_paydart.Recipient(address: oldR.address!, amount: BigInt.from(oldR.amount)),
          )
          .toList(),
      options: zkool_pay.PaymentOptions(
        srcPools: senderUAType,
        recipientPaysFee: recipients.first.feeIncluded,
        smartTransparent: false,
      ),
      c: c,
    );
    _pcztPackages[pcztPackage.toString()] = pcztPackage;
    assert(_pcztPackages[pcztPackage.toString()] != null, "toString is not stable");
    return pcztPackage.toString();
  }

  static final Map<String, zkool_pay.PcztPackage> _pcztPackages = {};

  static Future<List<ShieldedTx>> getTxs(final int _, final int id) async {
    c = await c.setAccount(account: id);
    final txs = await zkool_account.listTxHistory(c: c);
    final List<ShieldedTx> retList = [];
    for (int i = 0; i < txs.length; i++) {
      final zTx = txs[i];
      retList.add(
        ShieldedTx(
          id: zTx.id,
          txId: uint8ListToHex(zTx.txid),
          height: zTx.height,
          timestamp: zTx.time,
          name: "UnimplementedError()",
          value: zTx.value,
          address: "UnimplementedError()",
          memo: (await _getMemoForTx(id, zTx))?.memo,
        ),
      );
    }
    return retList;
  }

  static Future<zkool_account.Memo?> _getMemoForTx(final int id, final zkool_account.Tx tx) async {
    c = await c.setAccount(account: id);
    final memos = await zkool_account.listMemos(c: c);
    for (int i = 0; i < memos.length; i++) {
      final memo = memos[i];
      if (memo.idTx == tx.id) {
        return memo;
      }
    }
    return null;
  }

  static Future<int> getLatestHeight(final int accountId) async {
    c = await c.setAccount(account: accountId);
    try {
      return await zkool_network.getCurrentHeight(c: c);
    } catch (e) {
      printV("getLatestHeight: $e");
    }
    return 0;
  }

  static Future<void> rescanFrom(final int _, final accountId, final int height) async {
    c = await c.setAccount(account: accountId);
    return zkool_sync.rewindSync(height: height, account: accountId, c: c);
  }

  static Future<Backup> getBackup(final int _, final int id) async {
    c = await c.setAccount(account: id);
    final accounts = await zkool_account.listAccounts(c: c);
    final acc = accounts.firstWhere((final a) => a.id == id);
    return Backup(
      name: acc.name,
      seed: acc.seed,
      index: acc.aindex,
      // sk: sk,
      // fvk: fvk,
      // uvk: uvk,
      // tsk: tsk,
      saved: acc.saved,
    );
  }

  static Future<int> warpSync(
    final int _,
    final int account,
    final bool getTx,
    final int anchorOffset,
    final int maxCost,
    final int port,
  ) async {
    c = await c.setAccount(account: account);
    final currentHeight = await getLatestHeight(account);
    final sync = zkool_sync.synchronize(
      accounts: [account],
      currentHeight: currentHeight,
      actionsPerSync: 10000,
      transparentLimit: 100,
      checkpointAge: 200,
      c: c,
    );
    sync.listen(
      (final syncProgress) {
        printV("sync: ${syncProgress.height} / ${syncProgress.time}");
      },
      onError: (final e) {
        printV("sync err: $e");
      },
      onDone: () {
        printV("sync done");
      },
    );
    return 0;
  }

  static Future<Height> getDbHeight(final int _, final int accountId) async {
    c = await c.setAccount(account: accountId);
    final sh = await zkool_sync.getDbHeight(c: c);
    return Height(height: sh.height, timestamp: sh.time);
  }

  static Future<String> getDiversifiedAddress(
    final int _,
    final int account,
    final int uaType,
    final int time,
  ) async {
    c = await c.setAccount(account: account);
    return (await getAddress(-1, account, uaType)).ua ?? 'unknown';
  }

  static Future<PoolBalance> getPoolBalances(
    final int _,
    final int account,
    final int confirmations,
    final bool include_unconfirmed,
  ) async {
    c = await c.setAccount(account: account);
    final b = await zkool_sync.balance(c: c);
    return PoolBalance(
      transparent: b.field0[0].toInt(),
      sapling: b.field0[1].toInt(),
      orchard: b.field0[2].toInt(),
    );
  }

  static Future<String> signAndBroadcast(final int _, final int account, final String plan) async {
    c = await c.setAccount(account: account);
    final tx = _pcztPackages[plan];
    if (tx == null) {
      throw UnimplementedError("unknown dummy txplan");
    }
    printV("signAndBroadcast: init");
    final height = await getLatestHeight(account);
    printV("signAndBroadcast: height $height");
    final signTx = await zkool_pay.signTransaction(pczt: tx, c: c);
    printV("signAndBroadcast: signTx $signTx");
    final txBytes = await zkool_pay.extractTransaction(package: signTx);
    printV("signAndBroadcast: txBytes $txBytes");
    final result = await zkool_pay.broadcastTransaction(height: height, txBytes: txBytes, c: c);
    printV("signAndBroadcast: result $result");
    if (result.isNotEmpty) {
      throw Exception(result);
    }
    // try {
    //   final txidHex = hex.decode(result);
    //   await zkool_pay.storePendingTx(
    //     height: height,
    //     txid: txidHex,
    //     price: null,
    //     category: null,
    //     c: c,
    //   );
    // } catch (e) {
    //   printV("signAndBroadcast: $e");
    // }
    return result;
  }

  static Future<int> newAccount(
    final int _, {
    required final String name,
    required final String key,
    required final String? passphrase,
    required final int? height,
    required final int index,
  }) async {
    final id = await zkool_account.newAccount(
      na: zkool_account.NewAccount(
        name: name,
        restore: key != '',
        passphrase: passphrase,
        key: key,
        aindex: index,
        birth: height,
        folder: '',
        useInternal: true,
        internal: false,
        ledger: false,
      ),
      c: c,
    );
    c = await c.setAccount(account: id);
    return id;
  }

  static void setDbPasswd(final int _, final String s) {}

  static void initWallet(final int _, final String s) {}

  static void migrateData(final int _) {}
  static Future<int> getBlockHeightByTime(final int _, final DateTime time) async {
    final genesisTime = DateTime.utc(2016, 10, 28);
    const genesisHeight = 0;

    final firstHalvingTime = DateTime.utc(2020, 11, 18);
    const firstHalvingHeight = 1046400;

    final secondHalvingTime = DateTime.utc(2024, 11, 23);
    const secondHalvingHeight = 2726400;

    final t = time.toUtc().millisecondsSinceEpoch;
    final t0 = genesisTime.millisecondsSinceEpoch;
    final t1 = firstHalvingTime.millisecondsSinceEpoch;
    final t2 = secondHalvingTime.millisecondsSinceEpoch;

    if (t <= t0) return genesisHeight;

    if (t < t1) {
      return _interpolate(genesisHeight, firstHalvingHeight, t0, t1, t);
    }

    if (t < t2) {
      return _interpolate(firstHalvingHeight, secondHalvingHeight, t1, t2, t);
    }

    final secondsSince2 = (t - t2) / 1000.0;
    final blocksSince2 = (secondsSince2 / 76.0).floor();
    return secondHalvingHeight + blocksSince2;
  }

  static int _interpolate(
    final int hStart,
    final int hEnd,
    final int tStart,
    final int tEnd,
    final int t,
  ) {
    if (tEnd == tStart) return hStart;
    final ratio = (t - tStart) / (tEnd - tStart);
    return (hStart + (hEnd - hStart) * ratio).round();
  }

  static Future<List<Account>> getAccountList(final int _) async {
    final list = await zkool_account.listAccounts(c: c);
    return list
        .map(
          (final zkoolA) => Account(
            coin: 0,
            id: zkoolA.id,
            keyType: 0,
            balance: zkoolA.balance.toInt(),
            saved: zkoolA.saved,
          ),
        )
        .toList();
  }

  static Future<bool> transparentSync(final int _, final int account, final int height) async {
    return true;
  }

  static Future<int> getTBalance(final int _, final int account) async {
    c = await c.setAccount(account: account);
    final balance = await getPoolBalances(-1, account, 3, false);
    return balance.transparent;
  }
}
