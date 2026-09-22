import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';

class ChangeLanguageCubit extends Cubit<ChangeLanguageStates> {
  ChangeLanguageCubit() : super(ChangeLanguageInitState());

  Future<void> changeLanguage({required String lang, required BuildContext context}) async {
    if (lang != CacheKeysManger.getUserLanguage()) {
      context.setLocale(Locale(lang));
      CacheHelper.saveData(key: "lang", value: lang);
      emit(ChangeLanguageSuccessState());
      if (await CacheKeysManger.getToken() != "") {
        // context.read<GetRecommendedServicesCubit>().getRecommendedServices();
        // context.read<GetCartCubit>().getCart();
        // context.read<GetNormalOrdersCubit>().getNormalOrders(statusIndex: 0);
      }
    }

    NavigationUtils.navigateBack(context: context);
  }
}
