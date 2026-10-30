import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/i18n/app_dates.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/repositories/organization_repository.dart';

/// «بروفايل» — the organization's public face in the directory (guide Part
/// 4.3): logo, cover, «نبذة» and posts. The API cannot read back the current
/// logo, cover or bio yet, so this screen shows what is uploaded here.
class PublicProfileView extends StatefulWidget {
  const PublicProfileView({super.key});

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView> {
  final _repo = getIt<OrganizationRepository>();
  final _bio = TextEditingController();
  final _post = TextEditingController();

  String? _logoUrl;
  String? _coverUrl;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;
  bool _savingBio = false;
  bool _posting = false;
  String? _message;
  bool _messageIsError = false;

  late Future<ApiResult<({List<OrgPost> items, bool hasMore})>> _posts = _repo.posts();

  @override
  void dispose() {
    _bio.dispose();
    _post.dispose();
    super.dispose();
  }

  void _say(String? message, {bool error = false}) => setState(() {
        _message = message;
        _messageIsError = error;
      });

  Future<void> _upload({required bool cover}) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null || !mounted) return;
    setState(() => cover ? _uploadingCover = true : _uploadingLogo = true);
    final result = await _repo.uploadImage(cover: cover, filePath: image.path);
    if (!mounted) return;
    setState(() {
      _uploadingCover = false;
      _uploadingLogo = false;
      if (result case Ok(:final data)) cover ? _coverUrl = data : _logoUrl = data;
    });
    _say(result is Ok ? 'profile_page.saved'.tr() : result.failureMessage, error: result is! Ok);
  }

  Future<void> _saveBio() async {
    setState(() => _savingBio = true);
    final result = await _repo.saveBio(_bio.text.trim());
    if (!mounted) return;
    setState(() => _savingBio = false);
    _say(result is Ok ? 'profile_page.bio_saved'.tr() : result.failureMessage, error: result is! Ok);
  }

  Future<void> _publish() async {
    final body = _post.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    final result = await _repo.createPost(body);
    if (!mounted) return;
    setState(() {
      _posting = false;
      if (result is Ok) {
        _post.clear();
        _posts = _repo.posts();
      }
    });
    if (result is! Ok) _say(result.failureMessage, error: true);
  }

  Future<void> _delete(OrgPost post) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'profile_page.delete_post'.tr(),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
    );
    if (!confirmed) return;
    final result = await _repo.deletePost(post.id);
    if (!mounted) return;
    if (result is Ok || result is NoContent) {
      setState(() => _posts = _repo.posts());
    } else {
      _say(result.failureMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    Widget image(String? url, {required double height, required IconData icon}) => ClipRRect(
          borderRadius: AppTokens.mdRadius,
          child: Container(
            height: height,
            color: t.neutralTint,
            alignment: Alignment.center,
            child: url == null ? Icon(icon, color: t.iconMuted, size: 32) : Image.network(url, fit: BoxFit.cover, width: double.infinity),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('profile_page.title'.tr())),
      body: ListView(
        padding: AppTokens.pagePadding,
        children: [
          if (_message != null)
            AppBanner(message: _message!, tone: _messageIsError ? AppTone.danger : AppTone.brand),
          AppBanner(message: 'profile_page.no_read_hint'.tr(), tone: AppTone.info),
          AppSectionLabel('profile_page.cover'.tr(), padding: EdgeInsetsDirectional.zero),
          const SizedBox(height: AppTokens.space2),
          image(_coverUrl, height: 120, icon: Icons.panorama_outlined),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton.text(
              label: 'profile_page.change_cover'.tr(),
              icon: Icons.upload_rounded,
              busy: _uploadingCover,
              onPressed: _uploadingCover ? null : () => _upload(cover: true),
            ),
          ),
          AppSectionLabel('profile_page.logo'.tr()),
          Row(
            children: [
              SizedBox(width: 72, child: image(_logoUrl, height: 72, icon: Icons.storefront_outlined)),
              const SizedBox(width: AppTokens.space3),
              AppButton.text(
                label: 'profile_page.change_logo'.tr(),
                icon: Icons.upload_rounded,
                busy: _uploadingLogo,
                onPressed: _uploadingLogo ? null : () => _upload(cover: false),
              ),
            ],
          ),
          AppSectionLabel('profile_page.bio'.tr()),
          AppField(
            controller: _bio,
            label: 'profile_page.bio'.tr(),
            helper: 'profile_page.bio_hint'.tr(),
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
          ),
          AppButton.outline(
            label: 'profile_page.save_bio'.tr(),
            busy: _savingBio,
            onPressed: _savingBio ? null : _saveBio,
          ),
          AppSectionLabel('profile_page.posts'.tr()),
          AppField(
            controller: _post,
            label: 'profile_page.new_post'.tr(),
            maxLines: 3,
            maxLength: 4000,
            textInputAction: TextInputAction.newline,
          ),
          AppButton.primary(
            label: 'profile_page.publish'.tr(),
            busy: _posting,
            onPressed: _posting ? null : _publish,
          ),
          const SizedBox(height: AppTokens.space4),
          FutureBuilder<ApiResult<({List<OrgPost> items, bool hasMore})>>(
            future: _posts,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Skeleton(height: 56);
              final posts = snapshot.data?.dataOrNull?.items ?? const <OrgPost>[];
              if (posts.isEmpty) {
                return Text('profile_page.no_posts'.tr(), style: theme.textTheme.bodySmall);
              }
              return Column(
                children: [
                  for (final post in posts)
                    AppCard.item(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.body, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: AppTokens.space1),
                                Text(AppDates.dateTime(post.createdAt, locale), style: theme.textTheme.labelSmall),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'common.delete'.tr(),
                            icon: Icon(Icons.delete_outline_rounded, color: t.danger),
                            onPressed: () => _delete(post),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
