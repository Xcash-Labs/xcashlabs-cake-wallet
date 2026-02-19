import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/new-ui/modal_navigator.dart';
import 'package:cake_wallet/new-ui/pages/account_customizer.dart';
import 'package:cake_wallet/new-ui/pages/card_customizer.dart';
import 'package:cake_wallet/new-ui/pages/settings_page.dart';
import 'package:cake_wallet/new-ui/viewmodels/card_customizer/card_customizer_bloc.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/action_row/coin_action_row.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/assets_history/assets_history_section.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/cards/cards_view.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/compact_wallet_header.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/top_bar_widget/top_bar.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/unconfirmed_balance_widget.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/wallet_info.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/nft_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_edit_or_create_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_list_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class NewHomePage extends StatefulWidget {
  NewHomePage({super.key, required this.dashboardViewModel, required this.nftViewModel});

  final DashboardViewModel dashboardViewModel;
  final NFTViewModel nftViewModel;

  @override
  State<NewHomePage> createState() => _NewHomePageState();
}

class _NewHomePageState extends State<NewHomePage> {
  MoneroAccountListViewModel? accountListViewModel;
  bool _lightningMode = false;

  @override
  void initState() {
    super.initState();
    _setAccountViewModel();
    reaction((_)=>widget.dashboardViewModel.wallet, (_) {
      _setAccountViewModel();
      setState(() {
        _lightningMode = false;
      });
    });
  }

  void _setAccountViewModel() {
    accountListViewModel = widget.dashboardViewModel.balanceViewModel.hasAccounts
        ? getIt.get<MoneroAccountListViewModel>()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceDim,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          CustomScrollView(
            physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                sliver: CupertinoSliverRefreshControl(
                  onRefresh: () => widget.dashboardViewModel.refreshDashboard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TopBar(
                      dashboardViewModel: widget.dashboardViewModel,
                      lightningMode: _lightningMode,
                      onLightningSwitchPress: () {
                        setState(() {
                          _lightningMode = !_lightningMode;
                        });
                      },
                      onSettingsButtonPress: () {
                        CupertinoScaffold.showCupertinoModalBottomSheet(
                          context: context,
                          barrierColor: Colors.black.withAlpha(85),
                          builder: (context) => FractionallySizedBox(
                              child: Material(
                                  child: NewSettingsPage(
                            dashboardViewModel: widget.dashboardViewModel,
                            authService: getIt.get<AuthService>(),
                          ))),
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    Observer(
                      builder: (_)=>WalletInfoBar(
                          lightningMode: _lightningMode,
                          hardwareWalletType: widget.dashboardViewModel.wallet.hardwareWalletType,
                          name: widget.dashboardViewModel.wallet.name,
                          onCustomizeButtonTap: openCustomizer
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
              Observer(
                builder: (_) => SliverPersistentHeader(
                  pinned: true,
                  delegate: CardsViewHeaderDelegate(
                    maxHeight: getCardBoxHeight(),
                    sideWidget: CompactWalletHeader(dashboardViewModel: widget.dashboardViewModel,accountListViewModel: accountListViewModel,),
                    bottomWidget: CompactCoinActionRow(lightningMode: _lightningMode),
                    minHeight: 100.0,
                    maxWidth: MediaQuery.of(context).size.width * 0.878,
                    minWidth: 80,
                    topPadding: MediaQuery.of(context).padding.top,
                    cardsViewBuilder: (context, dynamicWidth, showText) {
                      return CardsView(
                        cardWidth: dynamicWidth,
                        showContent: showText,
                        key: ValueKey(widget.dashboardViewModel.wallet.name),
                        dashboardViewModel: widget.dashboardViewModel,
                        accountListViewModel: accountListViewModel,
                        onCompactModeBackgroundCardsTapped: openCustomizer,
                        lightningMode: _lightningMode,
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    UnconfirmedBalanceWidget(
                      dashboardViewModel: widget.dashboardViewModel,
                    ),
                    SizedBox(height: 24),
                    CoinActionRow(lightningMode: _lightningMode,
                      showSwap: widget.dashboardViewModel.isEnabledSwapAction,
                    ),
                    SizedBox(height: 24),
                    Observer(
                      builder: (_) => AssetsHistorySection(
                        nftViewModel: widget.nftViewModel,
                        dashboardViewModel: widget.dashboardViewModel,
                      ),
                    ),
                    SizedBox(height: 80.0)
                  ],
                ),
              ),
            ],
          ),
          Container(
            height: (MediaQuery.of(context).padding.top),
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
            ),
          ),
        ],
      ),
    );
  }

  double getCardBoxHeight() {
    final numCards = widget.dashboardViewModel.cardDesigns.length;
    final maxCardHeight = MediaQuery.of(context).size.width * 0.878 * (2/3.2);
    final overlapAmount = numCards > 3 ? 5.0 : 60.0;

    return maxCardHeight + (numCards-1)*overlapAmount;
  }

  void openCustomizer() async {
    final bloc = getIt.get<CardCustomizerBloc>(
        param1: _lightningMode,
        param2: widget.dashboardViewModel.settingsStore.displayAmountsInSatoshi);


    await CupertinoScaffold.showCupertinoModalBottomSheet(
      barrierColor: Colors.black.withAlpha(60),
      context: context,
      builder: (context) {
        return ModalNavigator(
          parentContext: context,
          heightMode: ModalHeightModes.fullScreen,
          rootPage: BlocProvider(
            create: (context) => bloc,
            child: Material(
              child: accountListViewModel == null
                  ? CardCustomizer(
                cryptoTitle: widget.dashboardViewModel.wallet.currency.fullName ??
                    widget.dashboardViewModel.wallet.currency.name,
                cryptoName: widget.dashboardViewModel.wallet.currency.name,
              )
                  : AccountCustomizer(
                accountListViewModel: accountListViewModel!,
                accountEditOrCreateViewModel:
                getIt.get<MoneroAccountEditOrCreateViewModel>(),
                dashboardViewModel: widget.dashboardViewModel,
              ),
            ),
          ),
        );
      },
    );

    bloc.add(DesignSaved());
    await bloc.stream.firstWhere((s) => s is CardCustomizerSaved);
    widget.dashboardViewModel.loadCardDesigns();
  }
}

class CardsViewHeaderDelegate extends SliverPersistentHeaderDelegate {
  CardsViewHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.minWidth,
    required this.maxWidth,
    required this.topPadding,
    required this.sideWidget,
    required this.bottomWidget,
    required this.cardsViewBuilder,
  });

  final double minHeight;
  final double maxHeight;
  final double minWidth;
  final double maxWidth;
  final double topPadding;
  final Widget sideWidget;
  final Widget bottomWidget;
  final Widget Function(BuildContext, double, bool) cardsViewBuilder;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double scrollRange = maxExtent - minExtent;
    final double progress = (shrinkOffset / scrollRange).clamp(0.0, 1.0);

    final double currentCardWidth = maxWidth - (progress * (maxWidth - minWidth));

    final double fadeThreshold = 0.6;
    final double elementsOpacity =
        ((progress - fadeThreshold) / (1.0 - fadeThreshold)).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          child: Stack(
            children: [
              Positioned(
                top:0,bottom:0,left:0,right:0,
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(5),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(25),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(50),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(100),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(150),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(175),
                          Theme.of(context).colorScheme.surfaceDim.withAlpha(200),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 36 * progress,
                bottom: 0,
                left: 18,
                right: 18,
                child: Opacity(
                  opacity: progress,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 74,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 36*progress,
                bottom: 0,
                left: minWidth+42,
                right: 36,
                child: Opacity(
                  opacity: elementsOpacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: sideWidget,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(-progress, 0.0),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 36*progress,
                    left: 30 * progress,
                  ),
                  child: SizedBox(
                    width: currentCardWidth,
                    child: cardsViewBuilder(context, currentCardWidth, progress == 0),
                  ),
                ),
              ),


            ],
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 36,
          child: Opacity(
            opacity: elementsOpacity,
            child: Center(
              child: bottomWidget,
            ),
          ),
        ),
      ],
    );
  }

  @override
  double get maxExtent => maxHeight > minExtent ? maxHeight : minExtent;

  @override
  double get minExtent => minHeight + topPadding + 40;

  @override
  bool shouldRebuild(covariant CardsViewHeaderDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.sideWidget != sideWidget ||
        oldDelegate.bottomWidget != bottomWidget ||
        oldDelegate.cardsViewBuilder != cardsViewBuilder;
  }
}