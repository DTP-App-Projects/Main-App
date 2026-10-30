import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:digital_trade_portal/features/shared/compliance/terms/terms_cubit.dart';
import 'package:digital_trade_portal/features/shared/compliance/terms/terms_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The shell stacks the terms notice above every tab. Hidden, it must take
/// no room at all — a SafeArea around it used to pad the status bar anyway,
/// pushing the More tab's gradient header off the status-bar strip.
void main() {
  testWidgets('a hidden notice takes zero height under a status bar', (tester) async {
    await useFakeStorage();
    await getIt.reset();
    getIt.registerSingleton<TermsCubit>(TermsCubit(ComplianceRepository(clientWith(FakeAdapter.json(const {})).$1)));

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: 24)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [TermsNoticeBanner(), Expanded(child: SizedBox.expand())]),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TermsNoticeBanner)).height, 0);
  });
}
