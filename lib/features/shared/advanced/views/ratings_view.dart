import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/repositories/account_repository.dart';
import '../view_models/advanced_cubits.dart';

/// Ratings, which both sides give each other.
///
/// The `dimension` vocabulary is a server-side enum that is not readable from
/// the validators, so the picker is built from the dimensions this
/// relationship has actually been rated on rather than a guessed list.
class RatingsView extends StatelessWidget {
  final int relationshipId;

  const RatingsView({super.key, required this.relationshipId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => RatingsCubit(getIt<AccountRepository>(), relationshipId)..load(),
        child: const _RatingsBody(),
      );
}

class _RatingsBody extends StatefulWidget {
  const _RatingsBody();

  @override
  State<_RatingsBody> createState() => _RatingsBodyState();
}

class _RatingsBodyState extends State<_RatingsBody> {
  final _note = TextEditingController();
  final _customDimension = TextEditingController();

  String? _dimension;
  int _score = 5;

  @override
  void dispose() {
    _note.dispose();
    _customDimension.dispose();
    super.dispose();
  }

  Future<void> _submit(RatingsCubit cubit) async {
    final dimension =
        _dimension == _otherDimension ? _customDimension.text.trim() : _dimension;
    if (dimension == null || dimension.isEmpty) return;

    final ok = await cubit.rate(
      dimension: dimension,
      score: _score,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (ok && mounted) _note.clear();
  }

  static const _otherDimension = '__other__';

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<RatingsCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    // Always offer a free-text option, since the enum cannot be enumerated.
    final dimensions = [...state.dimensions, _otherDimension];

    return Scaffold(
      appBar: AppBar(title: Text('rating.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && state.aggregate == null) return const DetailSkeleton();
          if (state.aggregate == null && state.errorMessage != null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage!;
            return AppErrorState(
              message: message.isEmpty ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          final aggregate = state.aggregate;
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                FormMessage(
                  message: state.action.message,
                  success: state.action.isSuccess,
                ),

                if (aggregate != null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          aggregate.average.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: AppType.ledgerLarge(t.textPrimary),
                        ),
                        const SizedBox(height: AppTokens.space1),
                        Center(child: _Stars(value: aggregate.average, size: 22)),
                        const SizedBox(height: AppTokens.space1),
                        Text(
                          'rating.count'.tr(namedArgs: {'count': '${aggregate.count}'}),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (aggregate.byDimension.isNotEmpty) ...[
                          Divider(height: AppTokens.space6, color: t.divider),
                          for (final entry in aggregate.byDimension.entries)
                            _DimensionBar(label: entry.key, score: entry.value),
                        ],
                      ],
                    ),
                  ),

                AppSectionLabel('rating.give'.tr()),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CodePicker(
                        label: 'rating.dimension'.tr(),
                        value: _dimension,
                        codes: dimensions,
                        labelOf: (code) =>
                            code == _otherDimension ? 'rating.other_dimension'.tr() : code,
                        onChanged: (value) => setState(() => _dimension = value),
                      ),
                      if (_dimension == _otherDimension)
                        AppField(
                          controller: _customDimension,
                          label: 'rating.dimension_code'.tr(),
                          helper: 'rating.dimension_hint'.tr(),
                          textDirection: TextDirection.ltr,
                        ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (var star = 1; star <= 5; star++)
                            IconButton(
                              iconSize: 34,
                              tooltip: '$star',
                              icon: Icon(
                                star <= _score ? Icons.star_rounded : Icons.star_border_rounded,
                                color: star <= _score ? t.warning : t.iconMuted,
                              ),
                              onPressed: () => setState(() => _score = star),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      AppField(
                        controller: _note,
                        label: 'profile.notes'.tr(),
                        maxLines: 3,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        serverError: state.action.fieldError('note'),
                      ),
                      SubmitButton(
                        busy: state.action.isSubmitting,
                        label: 'rating.submit'.tr(),
                        onPressed: _dimension == null ? null : () => _submit(cubit),
                      ),
                    ],
                  ),
                ),

                if (state.ratings.isNotEmpty) ...[
                  AppSectionLabel('rating.history'.tr()),
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < state.ratings.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: AppTokens.space5,
                              ),
                              child: Divider(height: 1, color: t.divider),
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTokens.space5,
                              vertical: AppTokens.space4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.ratings[i].dimension,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    const SizedBox(width: AppTokens.space2),
                                    _Stars(value: state.ratings[i].score.toDouble(), size: 16),
                                  ],
                                ),
                                if (state.ratings[i].note.isNotEmpty) ...[
                                  const SizedBox(height: AppTokens.space1),
                                  Text(state.ratings[i].note, style: theme.textTheme.bodySmall),
                                ],
                                if (state.ratings[i].createdAt != null) ...[
                                  const SizedBox(height: AppTokens.space1),
                                  Text(
                                    AppDates.date(state.ratings[i].createdAt, locale),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Five stars, filled to the nearest half of [value].
class _Stars extends StatelessWidget {
  final double value;
  final double size;

  const _Stars({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final halves = (value * 2).round();
    return Semantics(
      label: value.toStringAsFixed(1),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              halves >= star * 2
                  ? Icons.star_rounded
                  : halves == star * 2 - 1
                      ? Icons.star_half_rounded
                      : Icons.star_border_rounded,
              size: size,
              color: halves >= star * 2 - 1 ? t.warning : t.iconMuted,
            ),
        ],
      ),
    );
  }
}

/// One rated dimension as a label, its score and a bar out of five.
class _DimensionBar extends StatelessWidget {
  final String label;
  final double score;

  const _DimensionBar({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              const SizedBox(width: AppTokens.space2),
              Text(
                score.toStringAsFixed(1),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1 + 2),
          ClipRRect(
            borderRadius: AppTokens.fullRadius,
            child: LinearProgressIndicator(
              value: (score / 5).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: t.neutralTint,
              color: t.primary,
            ),
          ),
        ],
      ),
    );
  }
}
