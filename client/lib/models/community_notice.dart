class NoticeboardContext {
  const NoticeboardContext({
    required this.communityId,
    required this.communityName,
    required this.canPublish,
  });
  final String? communityId;
  final String communityName;

  /// A server-verified permission, not a role selected by the user in production.
  final bool canPublish;
}

class CommunityNotice {
  const CommunityNotice({
    required this.id,
    required this.communityId,
    required this.title,
    required this.body,
    required this.authorLabel,
    required this.publishedAt,
  });
  final String id, communityId, title, body, authorLabel;
  final DateTime publishedAt;
}

class NoticeDraft {
  const NoticeDraft({
    required this.title,
    required this.body,
    required this.requestId,
  });
  final String title, body;

  /// Reuse for retries. Backend must deduplicate posts and notification jobs.
  final String requestId;
  void validate() {
    if (title.trim().isEmpty ||
        title.length > 120 ||
        body.trim().isEmpty ||
        body.length > 4000 ||
        requestId.isEmpty) {
      throw ArgumentError(
        'A title and message within the field limits are required.',
      );
    }
  }
}

enum NoticeNotificationState { queued, failed, unknown, previewOnly }

class NoticePublishResult {
  const NoticePublishResult({
    required this.post,
    required this.notificationState,
  });
  final CommunityNotice post;
  final NoticeNotificationState notificationState;
}
