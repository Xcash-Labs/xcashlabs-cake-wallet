import 'dart:async';

import 'package:cake_wallet/entities/bridge_transfer.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

part 'bridge_transfers_store.g.dart';

class BridgeTransfersStore = BridgeTransfersStoreBase with _$BridgeTransfersStore;

abstract class BridgeTransfersStoreBase with Store {
  BridgeTransfersStoreBase({required this.bridgeTransfersSource})
      : bridgeTransfers = [] {
    _onBridgeTransfersChanged =
        bridgeTransfersSource.watch().listen((_) => updateList());
    updateList();
  }

  Box<BridgeTransfer> bridgeTransfersSource;
  StreamSubscription<BoxEvent>? _onBridgeTransfersChanged;

  @observable
  List<BridgeTransfer> bridgeTransfers;

  @action
  void updateList() {
    if (!bridgeTransfersSource.isOpen) return;
    final list = bridgeTransfersSource.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    bridgeTransfers = list;
  }

  @action
  void addTransfer(BridgeTransfer transfer) {
    if (!bridgeTransfersSource.isOpen) return;
    try {
      bridgeTransfersSource.add(transfer);
      updateList();
    } catch (_) {}
  }

  @action
  void updateTransfer(BridgeTransfer transfer) {
    if (!bridgeTransfersSource.isOpen) return;
    try {
      if (bridgeTransfersSource.isOpen) {
        transfer.save();
        updateList();
      }
    } catch (_) {}
  }

  @computed
  List<BridgeTransfer> get activeTransfers =>
      bridgeTransfers.where((b) => b.isActive).toList(growable: false);

  @computed
  List<BridgeTransfer> get pastTransfers =>
      bridgeTransfers.where((b) => !b.isActive).toList(growable: false);

  void dispose() {
    _onBridgeTransfersChanged?.cancel();
  }
}
