import 'package:flutter/foundation.dart';

import 'workspace.dart';

/// Everything a screen needs to know about "which side am I acting as, and
/// what may I do". Built from `/v2/bootstrap`, re-themed from `/ops/panel`.
@immutable
class WorkspaceState {
  final int organizationId;
  final String organizationName;

  /// `trader` | `supplier` | `hybrid`. Read this, never `users.type`.
  final String businessMode;

  final Workspace active;
  final Set<String> permissions;
  final bool isOwner;

  /// Which profiles actually passed review.
  final Set<String> approvedWorkspaces;

  final ThemeTokens theme;

  const WorkspaceState({
    required this.organizationId,
    required this.organizationName,
    required this.businessMode,
    required this.active,
    required this.permissions,
    required this.isOwner,
    required this.approvedWorkspaces,
    required this.theme,
  });

  bool get canSwitch => businessMode == BusinessMode.hybrid;
  bool get isTrader => active == Workspace.trader;
  bool get isSupplier => active == Workspace.supplier;

  /// The owner bypasses every permission check — the server behaves that way,
  /// so the UI must too or owners see disabled buttons that would have worked.
  bool can(String permission) => isOwner || permissions.contains(permission);

  bool canAny(List<String> perms) => isOwner || perms.any(permissions.contains);

  /// ALWAYS send these explicitly. Omitting `role` merges both sides into one
  /// list; omitting `workspace` drops a hybrid org onto the supplier home.
  String get roleParam => active.api;
  String get workspaceParam => active.api;

  /// Which workspaces this org may render at all.
  List<Workspace> get availableWorkspaces {
    switch (businessMode) {
      case BusinessMode.trader:
        return const [Workspace.trader];
      case BusinessMode.supplier:
        return const [Workspace.supplier];
      case BusinessMode.hybrid:
        return const [Workspace.trader, Workspace.supplier];
      default:
        return const [Workspace.trader];
    }
  }

  /// The active profile is still in review — the shell renders, but write
  /// actions should point at onboarding instead of failing server-side.
  bool get activeWorkspaceApproved => approvedWorkspaces.contains(active.api);

  WorkspaceState copyWith({
    Workspace? active,
    ThemeTokens? theme,
    Set<String>? permissions,
    Set<String>? approvedWorkspaces,
  }) =>
      WorkspaceState(
        organizationId: organizationId,
        organizationName: organizationName,
        businessMode: businessMode,
        active: active ?? this.active,
        permissions: permissions ?? this.permissions,
        isOwner: isOwner,
        approvedWorkspaces: approvedWorkspaces ?? this.approvedWorkspaces,
        theme: theme ?? this.theme,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceState &&
      other.organizationId == organizationId &&
      other.organizationName == organizationName &&
      other.businessMode == businessMode &&
      other.active == active &&
      other.isOwner == isOwner &&
      other.theme == theme &&
      setEquals(other.permissions, permissions) &&
      setEquals(other.approvedWorkspaces, approvedWorkspaces);

  @override
  int get hashCode => Object.hash(
        organizationId,
        organizationName,
        businessMode,
        active,
        isOwner,
        theme,
        permissions.length,
        approvedWorkspaces.length,
      );
}
