import 'dart:async';

import 'package:cake_wallet/entities/bridge_transfer.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cake_wallet/src/screens/trade_details/trade_details_status_item.dart';
import 'package:cake_wallet/src/screens/trade_details/track_trade_list_item.dart';
import 'package:cake_wallet/store/bridge_transfers_store.dart';
import 'package:mobx/mobx.dart';
import 'package:url_launcher/url_launcher.dart';

part 'bridge_details_view_model.g.dart';

class BridgeDetailsViewModel = BridgeDetailsViewModelBase with _$BridgeDetailsViewModel;

abstract class BridgeDetailsViewModelBase with Store {
  BridgeDetailsViewModelBase({
    required BridgeTransfer transferForDetails,
    required this.bridgeTransfersStore,
    required this.walletId,
  })  : items = ObservableList<StandartListItem>(),
        transfer = bridgeTransfersStore.bridgeTransfers
                .firstWhere(
                  (t) => t.id == transferForDetails.id && t.walletId == walletId,
                  orElse: () => transferForDetails,
                ) {
    _updateItems();
    _setupReaction();
  }

  final BridgeTransfersStore bridgeTransfersStore;
  final String walletId;
  ReactionDisposer? _reactionDisposer;

  @observable
  BridgeTransfer transfer;

  @observable
  ObservableList<StandartListItem> items;

  Timer? timer;

  void _setupReaction() {
    _reactionDisposer = reaction(
      (_) => bridgeTransfersStore.bridgeTransfers,
      (_) => updateTransfer(),
    );
  }

  @action
  void updateTransfer() {
    final updatedTransfer = bridgeTransfersStore.bridgeTransfers.firstWhere(
      (t) => t.id == transfer.id && t.walletId == walletId,
      orElse: () => transfer,
    );
    if (updatedTransfer.id == transfer.id) {
      transfer = updatedTransfer;
      _updateItems();
    }
  }

  void dispose() {
    _reactionDisposer?.call();
    timer?.cancel();
  }

  void _updateItems() {
    items.clear();

    final statusText = transfer.statusMessage?.isNotEmpty == true
        ? '${_statusLabel(transfer.status)} · ${transfer.statusMessage}'
        : _statusLabel(transfer.status);

    items.add(
      DetailsListStatusItem(
        title: S.current.bridge_detail_status,
        value: statusText,
        status: transfer.status,
      ),
    );

    final sourceName = evm?.getChainNameByChainId(transfer.sourceChainId) ??
        '${transfer.sourceChainId}';
    final destName = evm?.getChainNameByChainId(transfer.destinationChainId) ??
        '${transfer.destinationChainId}';

    items.add(
      StandartListItem(
        title: S.current.bridge_detail_source_chain,
        value: sourceName,
      ),
    );

    items.add(
      StandartListItem(
        title: S.current.bridge_detail_destination_chain,
        value: destName,
      ),
    );

    items.add(
      StandartListItem(
        title: S.current.bridge_detail_amount,
        value: '${transfer.amount} ${transfer.tokenSymbol}',
      ),
    );

    items.add(
      StandartListItem(
        title: S.current.bridge_detail_recipient,
        value: transfer.recipientAddress,
      ),
    );

    final sourceExplorerUrl = evm?.getExplorerUrlForChainId(transfer.sourceChainId);
    final sourceTxUrl = sourceExplorerUrl != null && sourceExplorerUrl.isNotEmpty
        ? '$sourceExplorerUrl/tx/${transfer.sourceTxHash}'
        : null;

    if (sourceTxUrl != null) {
      items.add(
        TrackTradeListItem(
          title: S.current.bridge_detail_view_on_explorer,
          value: transfer.sourceTxHash,
          onTap: () => _launchUrl(sourceTxUrl),
        ),
      );
    }

    if (transfer.errorMessage != null && transfer.errorMessage!.isNotEmpty) {
      items.add(
        StandartListItem(
          title: S.current.bridge_detail_error,
          value: transfer.errorMessage!,
        ),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return S.current.bridge_status_submitted;
      case 'confirming':
        return S.current.bridge_status_confirming;
      case 'initiated':
        return S.current.bridge_status_initiated;
      case 'completed':
        return S.current.bridge_status_completed;
      case 'failed':
        return S.current.bridge_status_failed;
      default:
        return status;
    }
  }

  void _launchUrl(String url) {
    final uri = Uri.parse(url);
    try {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
