import 'package:flutter/material.dart';

class NavigationUtils {
  static void navigateTo({required BuildContext context, required Widget destinationScreen}) =>
      Navigator.push(context, MaterialPageRoute(builder: (context) => destinationScreen));

  static void navigateReplacement({required BuildContext context, required Widget destinationScreen}) =>
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => destinationScreen));

  static void navigateToWithCallback({
    required BuildContext context,
    required Widget destinationScreen,
    required VoidCallback callback,
  }) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => destinationScreen)).then((value) => callback());
  }

  static void navigateAndClearStack({required BuildContext context, required Widget destinationScreen}) {
    // Predicate stops at the first route. With go_router as the root
    // navigator the bottom of the stack is a page-based route, which the
    // imperative API cannot remove — `(_) => false` would trigger
    // `'!pageBased || isWaitingForExitingDecision'`. `route.isFirst`
    // removes every imperative route on top while leaving the page-based
    // root in place.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
      (Route<dynamic> route) => route.isFirst,
    );
  }

  static void navigateBack({required BuildContext context}) {
    FocusScope.of(context).unfocus();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
