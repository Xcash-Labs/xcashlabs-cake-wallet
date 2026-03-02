import 'package:cake_wallet/new-ui/widgets/coins_page/action_row/coin_action_row.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/cards/balance_card.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_list_view_model.dart';
import 'package:cw_core/card_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class CompactWalletHeader extends StatelessWidget {
  const CompactWalletHeader(
      {super.key,
      required this.dashboardViewModel,
      this.accountListViewModel,
      required this.lightningMode,
        required this.onHeaderTapped,
      required this.showSwap});

  final DashboardViewModel dashboardViewModel;
  final bool lightningMode;
  final bool showSwap;
  final VoidCallback onHeaderTapped;
  final MoneroAccountListViewModel? accountListViewModel;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    Theme.of(context).colorScheme.surface.withAlpha(5),
                    Theme.of(context).colorScheme.surface.withAlpha(25),
                    Theme.of(context).colorScheme.surface.withAlpha(50),
                    Theme.of(context).colorScheme.surface.withAlpha(100),
                    Theme.of(context).colorScheme.surface.withAlpha(150),
                    Theme.of(context).colorScheme.surface.withAlpha(175),
                    Theme.of(context).colorScheme.surface.withAlpha(200),
                  ],
                ),
              )),
            ),
          ),
          SafeArea(
            child: Observer(builder: (context) {
              final account =
                  accountListViewModel?.accounts.where((item) => item.isSelected).firstOrNull;

              final String accountName = account == null ? "" : account.label;

              final walletName = dashboardViewModel.wallet.name;

              final BalanceRecord? record =
                  dashboardViewModel.balanceViewModel.formattedBalances.firstOrNull;
              final String balance = record?.availableBalance ?? "0.00";
              final String currency = record?.asset.title ?? "";

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GestureDetector(
                      onTap: onHeaderTapped,
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).colorScheme.surfaceContainer),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                spacing: 8,
                                children: [
                                  BalanceCard(
                                    width: 80,
                                    design: dashboardViewModel.cardDesigns
                                            .elementAtOrNull(account?.id ?? 0) ??
                                        CardDesign.genericDefault,
                                    borderRadius: 7,
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (accountName.isNotEmpty)
                                        Text(
                                          accountName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.primary),
                                        ),
                                      Text(
                                        walletName,
                                        style: TextStyle(
                                            fontWeight: accountName.isEmpty
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: accountName.isEmpty
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.onSurfaceVariant),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                spacing: 12,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                  ),
                                  Text("$balance $currency")
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  CompactCoinActionRow(
                    lightningMode: lightningMode,
                    showSwap: showSwap,
                  )
                ],
              );
            }),
          )
        ],
      ),
    );
  }
}
