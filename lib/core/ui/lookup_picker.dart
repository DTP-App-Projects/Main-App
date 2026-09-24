import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/models/lookups/lookup_item.dart';
import '../../data/repositories/lookups_repository.dart';
import '../error/api_failure_ui.dart';
import '../network/api_result.dart';
import '../utils/services/remote_services/service_locator.dart';
import '../utils/theme/tokens.dart';
import 'app_dialogs.dart';
import 'app_inputs.dart';
import 'form_fields.dart';
import 'skeleton/skeleton_variants.dart';
import 'states/state_views.dart';

/// Opens a picker backed by one of the `/v2/lookups/*` endpoints.
///
/// [lookup] is a name from [Lookup]; [query] carries that lookup's own
/// filters. Returns the chosen row, or `null` if the sheet was dismissed.
Future<LookupItem?> showLookupPicker({
  required BuildContext context,
  required String title,
  required String lookup,
  Map<String, dynamic>? query,
  bool searchable = true,
}) =>
    showModalBottomSheet<LookupItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LookupSheet(
        title: title,
        lookup: lookup,
        query: query,
        searchable: searchable,
      ),
    );

class _LookupSheet extends StatefulWidget {
  final String title;
  final String lookup;
  final Map<String, dynamic>? query;
  final bool searchable;

  const _LookupSheet({
    required this.title,
    required this.lookup,
    required this.query,
    required this.searchable,
  });

  @override
  State<_LookupSheet> createState() => _LookupSheetState();
}

class _LookupSheetState extends State<_LookupSheet> {
  /// The global budget is 60 requests a minute, so a keystroke is never a
  /// request. 400 ms is the floor the API notes call for.
  static const _debounce = Duration(milliseconds: 400);

  final _search = TextEditingController();

  Timer? _debounceTimer;
  CancelToken? _inFlight;

  bool _loading = true;
  bool _offline = false;
  String? _errorMessage;
  List<LookupItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Nobody is listening for this answer any more.
    _inFlight?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _fetch(search: value));
  }

  Future<void> _fetch({String? search}) async {
    // One search in flight at a time; a stale answer must not overwrite a
    // fresher query.
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _offline = false;
    });

    final result = await getIt<LookupsRepository>().items(
      widget.lookup,
      cancelToken: token,
      query: {
        ...?widget.query,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    if (!mounted || token.isCancelled) return;

    setState(() {
      _loading = false;
      if (result case Ok(:final data)) {
        _items = data;
      } else {
        _offline = result.isOffline;
        _errorMessage = result.failureMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter),
              child: AppSheetHeader(title: widget.title),
            ),
            if (widget.searchable)
              AppSearchField(
                controller: _search,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => _fetch(search: value),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.gutter,
                  0,
                  AppTokens.gutter,
                  AppTokens.space3,
                ),
              ),
            Expanded(child: _body(controller, locale)),
          ],
        ),
      ),
    );
  }

  Widget _body(ScrollController controller, String locale) {
    if (_loading) return const ListSkeleton(rows: 6);
    if (_offline) return AppOfflineState(onRetry: () => _fetch(search: _search.text));
    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: () => _fetch(search: _search.text),
      );
    }
    if (_items.isEmpty) {
      return AppEmptyState(
        title: 'lookup.empty'.tr(),
        body: _search.text.isEmpty ? null : 'lookup.empty_search'.tr(),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space2,
        0,
        AppTokens.space2,
        AppTokens.space6,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space4),
        child: Divider(height: 1),
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.label(locale), style: Theme.of(context).textTheme.bodyLarge),
          subtitle: item.code.isEmpty ? null : Text(item.code),
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }
}

/// A form field whose value is chosen from a lookup.
class LookupField extends StatelessWidget {
  final String label;
  final String lookup;
  final LookupItem? value;
  final Map<String, dynamic>? query;
  final String? error;
  final bool enabled;
  final bool required;
  final ValueChanged<LookupItem?> onChanged;

  const LookupField({
    super.key,
    required this.label,
    required this.lookup,
    required this.value,
    required this.onChanged,
    this.query,
    this.error,
    this.enabled = true,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    return AppFieldShell(
      label: label,
      required: required,
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await showLookupPicker(
                  context: context,
                  title: label,
                  lookup: lookup,
                  query: query,
                );
                if (picked != null) onChanged(picked);
              }
            : null,
        borderRadius: AppTokens.mdRadius,
        child: InputDecorator(
          decoration: InputDecoration(
            errorText: error,
            enabled: enabled,
            suffixIcon: Icon(Icons.expand_more_rounded, color: t.textSecondary),
          ),
          child: Text(
            value?.label(locale) ?? 'lookup.choose'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: value == null ? t.textTertiary : t.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
