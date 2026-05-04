import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/view_model/settings/link_list_item.dart';
import 'package:cake_wallet/view_model/settings/settings_list_item.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:mobx/mobx.dart';

part 'support_view_model.g.dart';

class SupportViewModel = SupportViewModelBase with _$SupportViewModel;

abstract class SupportViewModelBase with Store {
  final AppStore _appStore;

  SupportViewModelBase(this._appStore)
      : items = [
          LinkListItem(
              title: 'Website',
              icon: 'assets/images/global.png',
              linkTitle: 'xcashlabs.org',
              link: 'https://xcashlabs.org/'),
          LinkListItem(
              title: 'GitHub',
              icon: 'assets/images/github.png',
              hasIconColor: true,
              linkTitle: S.current.apk_update,
              link: 'https://github.com/Xcash-Labs/xcashlabs-cake-wallet/releases'),
          LinkListItem(
              title: 'Discord',
              icon: 'assets/images/discord.png',
              linkTitle: 'chat.xcashlabs.org',
              link: 'https://chat.xcashlabs.org'),
        ];

  final docsUrl = 'https://docs.xcashlabs.org/';

  String fetchUrl({String locale = "en", String authToken = ""}) {
    var supportUrl =
        "https://app.chatwoot.com/widget?website_token=${secrets.chatwootWebsiteToken}&locale=${locale}";

    if (authToken.isNotEmpty) supportUrl += "&cw_conversation=$authToken";

    return supportUrl;
  }

  String get appVersion =>
      "${isMoneroOnly ? "xcashlabs.org" : "Cake Wallet"} - ${_appStore.settingsStore.appVersion}";

  String get fiatApiMode => _appStore.settingsStore.fiatApiMode.title;

  String get walletType => _appStore.wallet?.type.name ?? 'Unknown';

  String get walletSyncState => _appStore.wallet?.syncStatus.toString() ?? 'Unknown';

  String get builtInTorState => _appStore.settingsStore.currentBuiltinTor ? 'Enabled' : 'Disabled';

  List<SettingsListItem> items;
}
