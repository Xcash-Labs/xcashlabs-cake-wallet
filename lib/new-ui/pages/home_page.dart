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
import 'package:cake_wallet/new-ui/widgets/coins_page/mweb_ad.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/top_bar_widget/top_bar.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/unconfirmed_balance_widget.dart';
import 'package:cake_wallet/new-ui/widgets/coins_page/wallet_info.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/nft_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_edit_or_create_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_list_view_model.dart';
import 'package:cw_core/wallet_type.dart';
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
  final GlobalKey _cardsViewKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  double _triggerOffset = double.infinity;
  bool _showHeader = false;

  @override
  void initState() {
    super.initState();
    _setAccountViewModel();
    _scrollController.addListener(_onScroll);
    reaction((_)=>widget.dashboardViewModel.wallet, (_) {
      _setAccountViewModel();
      setState(() {
        _lightningMode = false;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTriggerOffset();
    });
  }

  void _calculateTriggerOffset() {
    final RenderBox? renderBox = _cardsViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _triggerOffset = renderBox.size.height;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.offset >= _triggerOffset && !_showHeader) {
      setState(() => _showHeader = true);
    } else if (_scrollController.offset < _triggerOffset && _showHeader) {
      setState(() => _showHeader = false);
    }
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
            controller: _scrollController,
            physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                sliver: CupertinoSliverRefreshControl(
                  refreshTriggerPullDistance: 160,
                  refreshIndicatorExtent: 90,
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
                      builder: (_) => WalletInfoBar(
                          lightningMode: _lightningMode,
                          hardwareWalletType: widget.dashboardViewModel.wallet.hardwareWalletType,
                          name: widget.dashboardViewModel.wallet.name,
                          onCustomizeButtonTap: openCustomizer),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: CardsView(
                  key: _cardsViewKey,
                  showContent: true,
                  dashboardViewModel: widget.dashboardViewModel,
                  accountListViewModel: accountListViewModel,
                  onCompactModeBackgroundCardsTapped: openCustomizer,
                  lightningMode: _lightningMode,
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
                    Observer(
                      builder: (_) {
                        return Column(
                          children: [
                            CoinActionRow(
                              lightningMode: _lightningMode,
                              showSwap: widget.dashboardViewModel.isEnabledSwapAction,
                            ),
                            MwebAd(
                              dashboardViewModel: widget.dashboardViewModel,
                            ),
                          ],
                        );
                      },
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
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              ignoring: !_showHeader,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showHeader ? 1 : 0,
                child: Observer(
                  builder: (_) => CompactWalletHeader(
                    onHeaderTapped: () => _scrollController.animateTo(0,
                        duration: Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                    dashboardViewModel: widget.dashboardViewModel,
                    accountListViewModel: accountListViewModel,
                    lightningMode: _lightningMode,
                    showSwap: widget.dashboardViewModel.isEnabledSwapAction,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  double getCardBoxHeight() {
    final numCards = widget.dashboardViewModel.wallet.type == WalletType.bitcoin
        ? 1
        : widget.dashboardViewModel.cardDesigns.length;
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

    if(accountListViewModel == null) {
      bloc.add(DesignSaved());
      await bloc.stream.firstWhere((s) => s is CardCustomizerSaved);
    }
    widget.dashboardViewModel.loadCardDesigns();
  }
}