import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/open_crypto_pay/open_cryptopay_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/qr_scanner.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/new-ui/modal_navigator.dart';
import 'package:cake_wallet/new-ui/pages/send_page.dart';
import 'package:cake_wallet/new-ui/pages/swap_page.dart';
import 'package:cake_wallet/new-ui/widgets/modern_button.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../pages/receive_page.dart';
import '../../../pages/scan_page.dart';
import 'coin_action_button.dart';

class CoinAction {
  final String name;
  final String iconPath;
  final Function(BuildContext, bool) action;

  CoinAction({required this.name, required this.iconPath, required this.action});

  static final send = CoinAction(
      name: S.current.send,
      iconPath: "assets/new-ui/send.svg",
      action: (context, lightningMode) {
        if (FeatureFlag.hasNewUiExtraPages) {
          final sendPage = getIt.get<NewSendPage>(
            param1: SendPageParams(
              unspentCoinType: lightningMode ? UnspentCoinType.lightning : UnspentCoinType.any,
            ),
          );

          CupertinoScaffold.showCupertinoModalBottomSheet(
            context: context,
            barrierColor: Colors.black.withAlpha(60),
            builder: (context) {
              return Material(
                child: ModalNavigator(
                  rootPage: sendPage,
                  parentContext: context,
                ),
              );
            },
          );
        } else {
          Map<String, dynamic>? args;
          if (lightningMode) args = {'coinTypeToSpendFrom': UnspentCoinType.lightning};
          Navigator.of(context).pushNamed(Routes.send, arguments: args);
        }
      });

  static final receive = CoinAction(
      name: S.current.receive,
      iconPath: "assets/new-ui/receive.svg",
      action: (context, lightningMode) async {
        if (FeatureFlag.hasNewUiExtraPages) {
          final page = getIt.get<NewReceivePage>(param1: lightningMode);
          CupertinoScaffold.showCupertinoModalBottomSheet(
            context: context,
            barrierColor: Colors.black.withAlpha(60),
            builder: (context) {
              return Material(child: ModalNavigator(parentContext: context, rootPage: page));
            },
          );
        } else {
          // ToDo: (Konsti) refactor as part of the derivation PR (I hate myself for it)
          if (lightningMode) {
            await getIt<WalletAddressListViewModel>().setAddressType(
                bitcoin!.getOptionToType(bitcoin!.getBitcoinLightningReceivePageOption()));
          } else {
            await getIt<WalletAddressListViewModel>()
                .setAddressType(bitcoin!.getOptionToType(bitcoin!.getBitcoinSegwitPageOption()));
          }
          Navigator.of(context).pushNamed(Routes.addressPage);
        }
      });

  static final swap = CoinAction(
      name: S.current.swap,
      iconPath: "assets/new-ui/exchange.svg",
      action: (context, lightningMode) {
        final page = getIt.get<NewSwapPage>();
        if (FeatureFlag.hasNewUiExtraPages) {
          CupertinoScaffold.showCupertinoModalBottomSheet(
            context: context,
            barrierColor: Colors.black.withAlpha(85),
            builder: (context) => FractionallySizedBox(
                heightFactor: 0.97,
                child: Material(
                    child: ModalNavigator(
                  rootPage: page,
                  parentContext: context,
                ))),
          );
        } else {
          Navigator.of(context).pushNamed(Routes.exchange);
        }
      });

  static final scan = CoinAction(
      name: S.current.scan,
      iconPath: "assets/new-ui/scan.svg",
      action: (context, lightningMode) async {
        if (FeatureFlag.hasNewUiExtraPages) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => FractionallySizedBox(
              heightFactor: 0.9,
              child: ScanPage(),
            ),
          );
        } else {
          final code = await presentQRScanner(context);

          if (code == null || code.isEmpty) return;

          if (SendViewModelBase.isNonZeroAmountLightningInvoice(code) ||
              OpenCryptoPayService.isOpenCryptoPayQR(code)) {
            Navigator.of(context).pushNamed(Routes.send,
                arguments: {"paymentRequest": PaymentRequest(code, "", "", "", "")});
            return;
          }

          final uri = Uri.tryParse(code);
          if (uri == null) return;
          rootKey.currentState?.handleDeepLinking(uri);
        }
        ;
      });

  static final all = [send, receive, swap, scan];
}

class CoinActionRow extends StatelessWidget {
  const CoinActionRow({super.key, this.lightningMode = false});

  final bool lightningMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: MediaQuery.of(context).size.width * 0.05,
          children: CoinAction.all
              .map((item) => CoinActionButton(
                  icon: SvgPicture.asset(
                    item.iconPath,
                    colorFilter:
                        ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
                  ),
                  label: item.name,
                  action: () => item.action(context, lightningMode)))
              .toList()),
    );
  }
}

class CompactCoinActionRow extends StatelessWidget {
  const CompactCoinActionRow({super.key, required this.lightningMode});

  final bool lightningMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 20,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: CoinAction.all
          .map((item) => ModernButton.svg(
                svgPath: item.iconPath,
                size: 36,
                iconSize: 20,
                onPressed: () => item.action(context, lightningMode),
                backgroundColor: Theme.of(context).colorScheme.primary,
                iconColor: Theme.of(context).colorScheme.onPrimary,
              ))
          .toList(),
    );
  }
}
