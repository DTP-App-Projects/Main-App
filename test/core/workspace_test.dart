import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_state.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The workspace rules are where a hybrid organization breaks an app that
/// treats "which side am I on" as a detail.
void main() {
  WorkspaceState stateFor(
    String businessMode, {
    Workspace active = Workspace.trader,
    Set<String> permissions = const {},
    bool isOwner = false,
  }) =>
      WorkspaceState(
        organizationId: 3,
        organizationName: 'Test Org',
        businessMode: businessMode,
        active: active,
        permissions: permissions,
        isOwner: isOwner,
        approvedWorkspaces: const {'trader'},
        theme: ThemeTokens.fallbackFor(active),
      );

  group('switching', () {
    test('only a hybrid org may switch', () {
      expect(stateFor(BusinessMode.hybrid).canSwitch, isTrue);
      expect(stateFor(BusinessMode.trader).canSwitch, isFalse);
      expect(stateFor(BusinessMode.supplier).canSwitch, isFalse);
    });

    test('a single-mode org offers exactly one workspace', () {
      expect(stateFor(BusinessMode.trader).availableWorkspaces, [Workspace.trader]);
      expect(stateFor(BusinessMode.supplier).availableWorkspaces, [Workspace.supplier]);
      expect(stateFor(BusinessMode.hybrid).availableWorkspaces,
          [Workspace.trader, Workspace.supplier]);
    });
  });

  group('query params', () {
    test('role and workspace both follow the active side', () {
      final trader = stateFor(BusinessMode.hybrid);
      expect(trader.roleParam, 'trader');
      expect(trader.workspaceParam, 'trader');

      final supplier = stateFor(BusinessMode.hybrid, active: Workspace.supplier);
      expect(supplier.roleParam, 'supplier');
      expect(supplier.workspaceParam, 'supplier');
    });
  });

  group('permissions', () {
    test('the owner bypasses every check, exactly as the server does', () {
      final owner = stateFor(BusinessMode.hybrid, isOwner: true);
      expect(owner.can('collections.manage'), isTrue);
      expect(owner.canAny(['anything.at.all']), isTrue);
    });

    test('a member is limited to the granted list', () {
      final member = stateFor(BusinessMode.trader, permissions: {'purchase_orders.manage'});
      expect(member.can('purchase_orders.manage'), isTrue);
      expect(member.can('collections.manage'), isFalse);
      expect(member.canAny(['collections.manage', 'purchase_orders.manage']), isTrue);
    });
  });

  group('initial workspace', () {
    Organization org(String mode) => Organization.fromJson({
          'id': 3,
          'display_name': 'Test',
          'business_mode': mode,
          'approved_workspaces': ['trader', 'supplier'],
        });

    test('a single-mode org ignores whatever was remembered', () {
      expect(org(BusinessMode.trader).initialWorkspace(Workspace.supplier), Workspace.trader);
      expect(org(BusinessMode.supplier).initialWorkspace(Workspace.trader), Workspace.supplier);
    });

    test('hybrid honours the remembered choice', () {
      expect(org(BusinessMode.hybrid).initialWorkspace(Workspace.supplier), Workspace.supplier);
    });

    test('hybrid defaults to trader, not to the server default of supplier', () {
      // Omitting `?workspace=` drops a hybrid org on the supplier home. The
      // client picks trader instead and always sends the param explicitly.
      expect(org(BusinessMode.hybrid).initialWorkspace(null), Workspace.trader);
    });
  });

  group('theme tokens', () {
    test('each workspace has its own palette', () {
      expect(ThemeTokens.fallbackFor(Workspace.trader).primary, const Color(0xFFF26A1F));
      expect(ThemeTokens.fallbackFor(Workspace.supplier).primary, const Color(0xFF1E56A0));
    });

    test('the server palette wins when it answers', () {
      final tokens = ThemeTokens.fromJson(
        {
          'primary_color': '#1E56A0',
          'primary_on': '#FFFFFF',
          'secondary_color': '#F26A1F',
          'accent_color': '0C2D57',
          'surface_color': '#F5F8FB',
        },
        workspace: Workspace.supplier,
      );
      expect(tokens.primary, const Color(0xFF1E56A0));
      // Without the leading hash, too.
      expect(tokens.accent, const Color(0xFF0C2D57));
    });

    test('an unparseable colour keeps the fallback rather than throwing', () {
      final tokens = ThemeTokens.fromJson(
        {'primary_color': 'not-a-colour'},
        workspace: Workspace.trader,
      );
      expect(tokens.primary, ThemeTokens.traderFallback.primary);
    });
  });
}
