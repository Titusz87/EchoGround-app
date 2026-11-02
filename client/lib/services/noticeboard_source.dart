import '../models/community_notice.dart';

/// Backend handoff (no deployed routes are assumed):
/// - loadContext: derive the linked community and posting permission from the
///   authenticated account. Never grant access from a dropdown selection.
/// - fetchPosts: return only notices this account is allowed to read.
/// - publish: verify permission/membership on the server, save once using the
///   requestId, then enqueue one notification job for linked households.
/// - Keep FCM service-account credentials on the server. Use a generic push
///   title/body and data {type: community_notice, post_id, community_id}.
/// - Notification opens must re-check login and membership before loading a post.
/// - Existing incident listeners must exclude type=community_notice so notices
///   are not inserted into the incident cache or displayed as official warnings.
abstract class NoticeboardSource {
  bool get isPreview => false;
  Future<NoticeboardContext> loadContext();
  Future<List<CommunityNotice>> fetchPosts();
  Future<NoticePublishResult> publish(NoticeDraft draft);
}

/// Existing backend services can supply these callbacks without replacing auth
/// or notification_service.dart. This adapter does not invent endpoint paths.
class ConnectedNoticeboardSource extends NoticeboardSource {
  ConnectedNoticeboardSource({
    required this.contextLoader,
    required this.postsLoader,
    required this.postPublisher,
  });
  final Future<NoticeboardContext> Function() contextLoader;
  final Future<List<CommunityNotice>> Function() postsLoader;
  final Future<NoticePublishResult> Function(NoticeDraft) postPublisher;
  @override
  Future<NoticeboardContext> loadContext() => contextLoader();
  @override
  Future<List<CommunityNotice>> fetchPosts() => postsLoader();
  @override
  Future<NoticePublishResult> publish(NoticeDraft draft) {
    draft.validate();
    return postPublisher(draft);
  }
}

/// Defensive presentation checks; backend access checks remain essential.
List<CommunityNotice> visibleNotices(
  NoticeboardContext context,
  List<CommunityNotice> posts,
) {
  if (context.communityId == null) {
    if (posts.isNotEmpty)
      throw StateError('Unlinked household cannot read community notices.');
    return [];
  }
  if (posts.any((p) => p.communityId != context.communityId)) {
    throw StateError(
      'The feed returned a notice outside the linked community.',
    );
  }
  final byId = <String, CommunityNotice>{};
  for (final p in posts) {
    byId[p.id] = p;
  }
  final result = byId.values.toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return result;
}

/// Isolated demonstration data shared by publisher/household preview screens.
/// Never uses SQLite, real accounts, HTTP or Firebase.
class NoticeboardPreviewStore {
  final List<CommunityNotice> posts = [];
  final Map<String, NoticePublishResult> requests = {};
  int sequence = 0;
}

class PreviewNoticeboardSource extends NoticeboardSource {
  PreviewNoticeboardSource(this.store, {required this.context});
  final NoticeboardPreviewStore store;
  final NoticeboardContext context;
  @override
  bool get isPreview => true;
  @override
  Future<NoticeboardContext> loadContext() async => context;
  @override
  Future<List<CommunityNotice>> fetchPosts() async => [
    for (final post in store.posts)
      if (post.communityId == context.communityId) post,
  ];
  @override
  Future<NoticePublishResult> publish(NoticeDraft draft) async {
    draft.validate();
    if (!context.canPublish || context.communityId == null)
      throw StateError('Posting is not permitted.');
    final key = '${context.communityId}:${draft.requestId}';
    if (store.requests.containsKey(key)) return store.requests[key]!;
    final post = CommunityNotice(
      id: 'preview-${++store.sequence}',
      communityId: context.communityId!,
      title: draft.title.trim(),
      body: draft.body.trim(),
      authorLabel: 'Community coordinator (example)',
      publishedAt: DateTime.now().toUtc(),
    );
    final result = NoticePublishResult(
      post: post,
      notificationState: NoticeNotificationState.previewOnly,
    );
    store.posts.add(post);
    store.requests[key] = result;
    return result;
  }
}
