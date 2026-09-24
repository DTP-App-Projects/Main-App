import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/ui/skeleton/skeleton.dart';
import 'package:digital_trade_portal/core/ui/skeleton/skeleton_variants.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:shimmer/shimmer.dart';

import '../core/fake_backend.dart';

/// A skeleton is part of the deliverable, so it gets a test like anything
/// else: it must render the *shape* of the real layout, and — the brand being
/// fixed — look the same in either workspace.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  /// A hybrid organization, so both workspaces are reachable.
  final hybrid = Organization.fromJson(const {
    'id': 3,
    'display_name': 'Test Org',
    'business_mode': 'hybrid',
    'is_owner': true,
    'approved_workspaces': ['trader', 'supplier'],
  });

  Future<Widget> wrap(Widget child, {Workspace? workspace}) async {
    final (client, _) = clientWith(FakeAdapter.json(const {'theme': {}, 'quick_actions': []}));
    final cubit = WorkspaceCubit(SessionStore(), OpsRepository(client));
    if (workspace != null) {
      await cubit.hydrate(hybrid);
      await cubit.switchTo(workspace);
    }
    return BlocProvider.value(
      value: cubit,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('a list skeleton renders one placeholder row per item', (tester) async {
    await tester.pumpWidget(await wrap(const ListSkeleton(rows: 4)));

    // Four boxes per row: leading square, two text lines, trailing amount.
    expect(find.byType(Skeleton), findsNWidgets(4 * 4));
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('the KPI skeleton matches the four-tile home grid', (tester) async {
    await tester.pumpWidget(await wrap(const KpiGridSkeleton()));
    expect(find.byType(Skeleton), findsNWidgets(4));
  });

  testWidgets('the form skeleton pairs a label with each field, plus a button',
      (tester) async {
    await tester.pumpWidget(await wrap(const FormSkeleton(fields: 3)));
    // 3 labels + 3 fields + 1 submit button.
    expect(find.byType(Skeleton), findsNWidgets(7));
  });

  testWidgets('the shimmer is brand-neutral: the same in both workspaces', (tester) async {
    // Hydrating a workspace reads the server palette. `testWidgets` runs in
    // fake async, where a real network future never settles — so the setup
    // runs in runAsync and only the pumping happens on the fake clock.
    late Widget supplierTree;
    late Widget traderTree;
    await tester.runAsync(() async {
      supplierTree = await wrap(const ListSkeleton(rows: 1), workspace: Workspace.supplier);
      traderTree = await wrap(const ListSkeleton(rows: 1), workspace: Workspace.trader);
    });

    await tester.pumpWidget(supplierTree);
    final supplier = tester.widget<Shimmer>(find.byType(Shimmer));

    await tester.pumpWidget(traderTree);
    final trader = tester.widget<Shimmer>(find.byType(Shimmer));

    // Decision D1: the server palette no longer colours the UI (only the role
    // badge), so loading looks identical on either side.
    expect(supplier.gradient.colors, equals(trader.gradient.colors));
  });

  testWidgets('with no workspace resolved yet it still renders', (tester) async {
    // Cold start: the splash shows skeletons before bootstrap has answered.
    await tester.pumpWidget(await wrap(const DetailSkeleton()));
    expect(find.byType(Shimmer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
