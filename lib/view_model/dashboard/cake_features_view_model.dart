import 'package:cake_wallet/cake_pay/src/services/cake_pay_service.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:mobx/mobx.dart';

part 'cake_features_view_model.g.dart';

class CakeFeaturesViewModel = CakeFeaturesViewModelBase with _$CakeFeaturesViewModel;

abstract class CakeFeaturesViewModelBase with Store {
  final CakePayService _cakePayService;

  CakeFeaturesViewModelBase(this._cakePayService);

  Future<bool> isIoniaUserAuthenticated() async {
    return await _cakePayService.isLogged();
  }

  bool hasUSDT0Tokens(WalletBase wallet) {
    if (!isEVMCompatibleChain(wallet.type)) return false;
    try {
      final tokens = wallet.balance.keys.whereType<Erc20Token>();
      return tokens.any((t) => evm!.isUSDT0Token(wallet, t));
    } catch (_) {
      return false;
    }
  }
}
