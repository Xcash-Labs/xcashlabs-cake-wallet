import 'package:cake_wallet/entities/bridge_transfer.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/themes/core/custom_theme_colors.dart';
import 'package:cake_wallet/view_model/bridge_history_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

class BridgeHistoryPage extends BasePage {
  BridgeHistoryPage(this.viewModel);

  final BridgeHistoryViewModel viewModel;

  @override
  String get title => S.current.bridge_history_title;

  @override
  Widget body(BuildContext context) {
    return Observer(
      builder: (_) {
        if (viewModel.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                S.current.bridge_history_empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final active = viewModel.activeTransfers;
        final past = viewModel.pastTransfers;
        final items = <Widget>[];

        if (active.isNotEmpty) {
          items.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                S.current.bridge_history_active,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
          for (final transfer in active) {
            items.add(
              BridgeTransferRow(
                transfer: transfer,
                onTap: () => Navigator.of(context).pushNamed(
                  Routes.usdt0BridgeDetail,
                  arguments: transfer,
                ),
              ),
            );
          }
        }

        if (past.isNotEmpty) {
          items.add(
            Padding(
              padding: EdgeInsets.fromLTRB(24, active.isNotEmpty ? 16 : 8, 24, 4),
              child: Text(
                S.current.bridge_history_past,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
          for (final transfer in past) {
            items.add(
              BridgeTransferRow(
                transfer: transfer,
                onTap: () => Navigator.of(context).pushNamed(
                  Routes.usdt0BridgeDetail,
                  arguments: transfer,
                ),
              ),
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: items,
        );
      },
    );
  }
}

class BridgeTransferRow extends StatelessWidget {
  const BridgeTransferRow({
    required this.transfer,
    required this.onTap,
    super.key,
  });

  final BridgeTransfer transfer;
  final VoidCallback onTap;

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

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'completed':
        return CustomThemeColors.syncGreen;
      case 'failed':
        return Theme.of(context).colorScheme.error;
      case 'submitted':
      case 'confirming':
      case 'initiated':
      default:
        return CustomThemeColors.syncYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceName =
        evm?.getChainNameByChainId(transfer.sourceChainId) ?? '${transfer.sourceChainId}';
    final destName =
        evm?.getChainNameByChainId(transfer.destinationChainId) ?? '${transfer.destinationChainId}';
    final formattedDate = DateFormat('HH:mm').format(transfer.createdAt);
    final statusText = transfer.statusMessage?.isNotEmpty == true
        ? '${_statusLabel(transfer.status)} · ${transfer.statusMessage}'
        : _statusLabel(transfer.status);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: _statusColor(context, transfer.status),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '$sourceName → $destName',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${transfer.amount} ${transfer.tokenSymbol}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          statusText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
