import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../session/session_store.dart';
import '../utils/services/remote_services/service_locator.dart';
import '../utils/theme/tokens.dart';

/// Switching the app language, in one place.
///
/// Two things have to move together, which is why this is not a one-liner at
/// the call site: easy_localization owns what the UI renders, and
/// [SessionStore] owns the `Accept-Language` every request carries. Setting
/// one without the other gives you an Arabic screen full of English server
/// strings.
Future<void> toggleAppLocale(BuildContext context) async {
  final next = context.locale.languageCode == 'ar'
      ? const Locale('en')
      : const Locale('ar');

  await context.setLocale(next);
  await getIt<SessionStore>().setLocale(next.languageCode);
}

/// The name of the language this button would switch *to*.
String otherLocaleName(BuildContext context) =>
    context.locale.languageCode == 'ar' ? 'common.english'.tr() : 'common.arabic'.tr();

/// A compact language switch for screens with no More tab to reach for.
///
/// The unauthenticated screens need this: until now the only toggle lived
/// behind sign-in, so anyone who could not read the current locale could not
/// get far enough to change it.
class LocaleToggleButton extends StatelessWidget {
  const LocaleToggleButton({super.key});

  /// The Driver language pill: white, hairline, translate icon + the name of
  /// the language it switches to.
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      shape: StadiumBorder(side: BorderSide(color: t.isDark ? t.inputBorder : const Color(0xFFDEDEDE))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => toggleAppLocale(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate_rounded, size: 18, color: t.textTertiary),
                const SizedBox(width: AppTokens.space2),
                Text(
                  otherLocaleName(context),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
