import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_list_view_model.dart';
import 'package:flutter/material.dart';

class CompactWalletHeader extends StatelessWidget {
  const CompactWalletHeader(
      {super.key, required this.dashboardViewModel, this.accountListViewModel});

  final DashboardViewModel dashboardViewModel;
  final MoneroAccountListViewModel? accountListViewModel;

  @override
  Widget build(BuildContext context) {
    final account = accountListViewModel?.accounts.where((item) => item.isSelected).firstOrNull;

    late final String accountName;
    if (account == null) {
      accountName = "";
    } else {
      accountName = account.label;
    }

    final walletName = dashboardViewModel.wallet.name;

    final BalanceRecord? record = dashboardViewModel.balanceViewModel.formattedBalances.firstOrNull;
    final String balance = record?.availableBalance ?? "0.00";
    final String currency = record?.asset.title ?? "";

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (accountName.isNotEmpty) Text(accountName,style: TextStyle(fontWeight: FontWeight.w500,color: Theme.of(context).colorScheme.primary),),
            Text(
              walletName,
              style: TextStyle(
                  fontWeight: accountName.isEmpty ? FontWeight.w500 : FontWeight.w400,
                  color: accountName.isEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            )
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
    );
  }
}
