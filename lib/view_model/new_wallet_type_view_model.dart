import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/view_model/advanced_privacy_settings_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'new_wallet_type_view_model.g.dart';

class NewWalletTypeViewModel = NewWalletTypeViewModelBase
    with _$NewWalletTypeViewModel;

abstract class NewWalletTypeViewModelBase with Store {
  NewWalletTypeViewModelBase(this.hasExisitingWallet, this.appStore) {
    itemSelection = ObservableMap<WalletType, bool>.of({
      WalletType.monero: false,
      WalletType.bitcoin: false,
      WalletType.ethereum: false,
      WalletType.litecoin: false,
      WalletType.dogecoin: false,
      WalletType.bitcoinCash: false,
      WalletType.polygon: false,
      WalletType.solana: false,
      WalletType.tron: false,
      WalletType.nano: false,
    });
  }


  final bool hasExisitingWallet;
  final AppStore appStore;

  late final ObservableMap<WalletType, bool> itemSelection;

  bool isPassPhraseSupported(WalletType type) {
    return AdvancedPrivacySettingsViewModelBase
        .hasPassphraseOptionWalletTypes
        .contains(type);
  }


  @computed
  bool get hasAnySelected => selectedTypes.isNotEmpty;

  @computed
  List<WalletType> get selectedTypes =>
      itemSelection.entries.where((e) => e.value).map((e) => e.key).toList();

  @action
  void deselectAll () {
    for (var type in itemSelection.keys) {
      itemSelection[type] = false;
    }
  }
}
