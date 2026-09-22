import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({super.key, required this.title, this.withBack = true});

  final String title;
  final bool withBack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: withBack
                  ? () {
                      NavigationUtils.navigateBack(context: context);
                    }
                  : null,
              icon: withBack
                  ? RotatedBox(
                      quarterTurns: CacheKeysManger.getUserLanguage() == "en" ? 0 : 2,
                      child: SvgPicture.asset(AssetData.back),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font18SemiBoldBlack(context),
                ),
              ),
            ),
            SizedBox(width: AppConstants.width30(context) * 1.5),
          ],
        );
      },
    );
  }
}
