import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_dates.dart';
import '../../../core/session/session_store.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/shop/cart.dart';
import '../../../data/repositories/shop_repository.dart';
import '../view_models/shop_cubits.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Time of day for today, the date otherwise.
String _listStamp(DateTime value, String locale) {
  if (_sameDay(value, DateTime.now())) return DateFormat.jm(locale).format(value);
  return AppDates.date(value, locale);
}

/// Conversations, newest activity first.
class ShopChatListView extends StatelessWidget {
  const ShopChatListView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ChatListCubit(getIt<ShopRepository>())..load(),
        child: Builder(
          builder: (context) {
            final cubit = context.watch<ChatListCubit>();
            final state = cubit.state;
            final theme = Theme.of(context);
            final t = context.tokens;
            final locale = context.locale.toString();

            return Scaffold(
              appBar: AppBar(title: Text('shop.chat'.tr())),
              body: Builder(
                builder: (context) {
                  if (state.loading) return const ListSkeleton(rows: 6);
                  if (state.offline) {
                    return RefreshIndicator(
                      onRefresh: cubit.load,
                      child: AppOfflineState(onRetry: cubit.load),
                    );
                  }
                  if (state.errorMessage != null) {
                    return RefreshIndicator(
                      onRefresh: cubit.load,
                      child: AppErrorState(
                        message: _messageOr(state.errorMessage),
                        onRetry: cubit.load,
                      ),
                    );
                  }
                  if (state.threads.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: cubit.load,
                      child: AppEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'shop.no_chats'.tr(),
                        body: 'shop.no_chats_hint'.tr(),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: cubit.load,
                    child: ListView.builder(
                      padding: AppTokens.pagePadding,
                      itemCount: state.threads.length,
                      itemBuilder: (context, index) {
                        final thread = state.threads[index];
                        final latest = thread.latest;
                        return AppCard.item(
                          onTap: () => context.push(
                            AppRoutes.shopChatWith(thread.id),
                            extra: thread.displayName,
                          ),
                          child: Row(
                            children: [
                              _Avatar(name: thread.displayName, image: thread.image),
                              const SizedBox(width: AppTokens.space3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            thread.displayName,
                                            style: theme.textTheme.titleSmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (latest?.sentAt != null) ...[
                                          const SizedBox(width: AppTokens.space2),
                                          Text(
                                            _listStamp(latest!.sentAt!, locale),
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (latest != null && latest.text.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        latest.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTokens.space2),
                              DirectionalChevron(size: 20, color: t.iconMuted),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}

/// One conversation.
///
/// There is no socket here yet — the thread reloads on open and after each
/// send. A polling loop would burn the 60-requests-a-minute budget for very
/// little, so it waits on a push instead.
class ShopChatRoomView extends StatefulWidget {
  final int withId;
  final String? title;

  const ShopChatRoomView({super.key, required this.withId, this.title});

  @override
  State<ShopChatRoomView> createState() => _ShopChatRoomViewState();
}

class _ShopChatRoomViewState extends State<ShopChatRoomView> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The send button follows the text, so it is off while there is nothing
    // to send.
    _input.addListener(_onText);
  }

  @override
  void dispose() {
    _input
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  Future<void> _send(BuildContext context) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;

    final cubit = context.read<ChatRoomCubit>();
    // Clear optimistically: the reload after a successful send brings the
    // message back from the server.
    _input.clear();
    final ok = await cubit.send(text);
    if (ok || !context.mounted) return;

    _input.text = text;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageOr(cubit.state.action.message))),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ChatRoomCubit(
          getIt<ShopRepository>(),
          getIt<SessionStore>(),
          widget.withId,
        )..load(),
        child: Builder(
          builder: (context) {
            final cubit = context.watch<ChatRoomCubit>();
            final state = cubit.state;
            final canSend = _input.text.trim().isNotEmpty && !state.action.isSubmitting;

            return Scaffold(
              appBar: AppBar(title: Text(widget.title ?? 'shop.chat'.tr())),
              body: Column(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (state.loading) return const ListSkeleton(rows: 6);
                        if (state.offline) {
                          return AppOfflineState(onRetry: cubit.load);
                        }
                        if (state.errorMessage != null && state.messages.isEmpty) {
                          return AppErrorState(
                            message: _messageOr(state.errorMessage),
                            onRetry: cubit.load,
                          );
                        }
                        if (state.messages.isEmpty) {
                          return AppEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'shop.no_messages'.tr(),
                          );
                        }

                        final messages = state.messages;
                        return ListView.builder(
                          // The server sends newest first, so the list is
                          // reversed rather than the data.
                          reverse: true,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppTokens.gutter,
                            AppTokens.space4,
                            AppTokens.gutter,
                            AppTokens.space4,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final older = index + 1 < messages.length ? messages[index + 1] : null;
                            // A day label above the first message of each day.
                            final sentAt = message.sentAt;
                            final showDay = sentAt != null &&
                                (older?.sentAt == null || !_sameDay(older!.sentAt!, sentAt));
                            final bubble = _Bubble(
                              message: message,
                              mine: message.isMine(cubit.myUserId),
                            );
                            if (!showDay) return bubble;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [_DaySeparator(day: sentAt), bubble],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _Composer(
                    controller: _input,
                    canSend: canSend,
                    onSend: () => _send(context),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _DaySeparator extends StatelessWidget {
  final DateTime day;

  const _DaySeparator({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final locale = context.locale.toString();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final label = _sameDay(day, now)
        ? 'shop.today'.tr()
        : _sameDay(day, yesterday)
            ? 'shop.yesterday'.tr()
            : AppDates.date(day, locale);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space3),
      child: Center(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppTokens.space3,
            vertical: AppTokens.space1,
          ),
          decoration: BoxDecoration(color: t.neutralTint, borderRadius: AppTokens.fullRadius),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

/// The message field as a pill, and a round send button that is only live
/// when there is something to send.
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const pill = AppTokens.fullRadius;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: pill,
          borderSide: BorderSide(color: color),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        boxShadow: t.shadowNav,
        border: t.isDark ? Border(top: BorderSide(color: t.border)) : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.space4,
            AppTokens.space2,
            AppTokens.space3,
            AppTokens.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'shop.message_hint'.tr(),
                    filled: true,
                    fillColor: t.inputFill,
                    isDense: true,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTokens.space4,
                      vertical: AppTokens.space3,
                    ),
                    border: border(t.inputBorder),
                    enabledBorder: border(t.inputBorder),
                    focusedBorder: border(t.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Semantics(
                button: true,
                enabled: canSend,
                label: 'shop.send'.tr(),
                child: Tooltip(
                  message: 'shop.send'.tr(),
                  child: Material(
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    color: canSend ? Colors.transparent : t.neutralTint,
                    child: Ink(
                      decoration: canSend
                          ? const BoxDecoration(
                              gradient: AppTokens.brandGradient,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: InkWell(
                        onTap: canSend ? onSend : null,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: AppTokens.touchTarget,
                          height: AppTokens.touchTarget,
                          child: Icon(
                            Icons.send_rounded,
                            size: 22,
                            color: canSend ? Colors.white : t.iconMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    const round = Radius.circular(AppTokens.radiusLg);
    const tail = Radius.circular(AppTokens.space1);
    final locale = context.locale.toString();

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space1),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.space3 + 2,
            AppTokens.space2,
            AppTokens.space3 + 2,
            AppTokens.space2,
          ),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.78),
          decoration: BoxDecoration(
            color: mine ? t.primaryTint : t.surface,
            border: mine ? null : Border.all(color: t.border),
            // The tail corner points at the sender's side.
            borderRadius: BorderRadiusDirectional.only(
              topStart: round,
              topEnd: round,
              bottomStart: mine ? round : tail,
              bottomEnd: mine ? tail : round,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.textPrimary),
                ),
              ),
              if (message.sentAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat.jm(locale).format(message.sentAt!),
                  style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture when there is one, the initial otherwise.
class _Avatar extends StatelessWidget {
  final String name;
  final String image;

  const _Avatar({required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    if (image.isEmpty) return AppInitialAvatar(name: name, size: size);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => AppInitialAvatar(name: name, size: size),
      ),
    );
  }
}
