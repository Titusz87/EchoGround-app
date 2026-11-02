import 'dart:math';

import 'package:flutter/material.dart';

import '../models/community_notice.dart';
import '../services/noticeboard_source.dart';

class CommunityNoticeboardPage extends StatefulWidget {
  const CommunityNoticeboardPage({super.key, required this.source});
  final NoticeboardSource source;
  @override
  State<CommunityNoticeboardPage> createState() => _NoticeboardState();
}

class _NoticeboardState extends State<CommunityNoticeboardPage> {
  NoticeboardContext? audience;
  List<CommunityNotice> posts = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      posts = [];
      audience = null;
    });
    try {
      final context = await widget.source.loadContext();
      final rows = context.communityId == null
          ? <CommunityNotice>[]
          : visibleNotices(context, await widget.source.fetchPosts());
      if (mounted)
        setState(() {
          audience = context;
          posts = rows;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'The community noticeboard could not be loaded. Check your connection and account access, then try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> compose() async {
    final context = audience;
    if (context == null || !context.canPublish || context.communityId == null)
      return;
    final posted = await Navigator.push<bool>(
      this.context,
      MaterialPageRoute(
        builder: (_) =>
            _ComposeNotice(source: widget.source, audience: context),
      ),
    );
    if (posted == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Community noticeboard'),
      actions: [
        IconButton(
          tooltip: 'Refresh notices',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.source.isPreview) const _PreviewNotice(),
            const Text(
              'Updates from your community',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Community posts are separate from official emergency warnings on Home.',
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LinearProgressIndicator(),
              ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!),
              TextButton(onPressed: load, child: const Text('Try again')),
            ],
            if (audience != null) ...[
              const SizedBox(height: 16),
              if (audience!.communityId == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No community is linked to this household yet. Link your household through the authorised community membership process to view its notices.',
                    ),
                  ),
                )
              else ...[
                Text(
                  audience!.communityName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (audience!.canPublish) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : compose,
                    icon: const Icon(Icons.edit_square),
                    label: const Text('Create a community post'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.source.isPreview
                        ? 'Preview publishing adds a local example. It does not send notifications.'
                        : 'New posts are sent to households linked to this community. Device notification permissions affect push delivery.',
                  ),
                ],
                const SizedBox(height: 18),
                if (posts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No community posts yet. New posts will appear here.',
                      ),
                    ),
                  ),
                for (final post in posts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(18),
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(
                        post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${post.authorLabel} · ${post.publishedAt.toLocal()}',
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ReadNotice(
                            source: widget.source,
                            postId: post.id,
                            communityId: post.communityId,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 18),
    child: ColoredBox(
      color: Color(0xFFFFE3AA),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'DESIGN PREVIEW • Fictional community • Posts reset on reload • No push notifications are sent.',
        ),
      ),
    ),
  );
}

class _ReadNotice extends StatefulWidget {
  const _ReadNotice({
    required this.source,
    required this.postId,
    required this.communityId,
  });
  final NoticeboardSource source;
  final String postId, communityId;
  @override
  State<_ReadNotice> createState() => _ReadNoticeState();
}

class _ReadNoticeState extends State<_ReadNotice> {
  CommunityNotice? post;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final audience = await widget.source.loadContext();
      if (audience.communityId != widget.communityId)
        throw StateError('Membership changed');
      final posts = visibleNotices(audience, await widget.source.fetchPosts());
      final matching = posts.where((p) => p.id == widget.postId);
      if (matching.isEmpty) throw StateError('Post unavailable');
      if (mounted) setState(() => post = matching.first);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'This post is unavailable or your community access has changed. Return to the noticeboard and refresh.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community post')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.source.isPreview) const _PreviewNotice(),
            if (error != null) Text(error!),
            if (post == null && error == null) const LinearProgressIndicator(),
            if (post != null) ...[
              Text(
                post!.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${post!.authorLabel}\nPosted: ${post!.publishedAt.toLocal()}',
              ),
              const Divider(height: 32),
              SelectableText(
                post!.body,
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ComposeNotice extends StatefulWidget {
  const _ComposeNotice({required this.source, required this.audience});
  final NoticeboardSource source;
  final NoticeboardContext audience;
  @override
  State<_ComposeNotice> createState() => _ComposeNoticeState();
}

class _ComposeNoticeState extends State<_ComposeNotice> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), body = TextEditingController();
  final requestId =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  bool busy = false;
  String? error;
  NoticeDraft? attemptedDraft;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> publish() async {
    if (busy || !form.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.source.isPreview
              ? 'Add preview post?'
              : 'Publish this community post?',
        ),
        content: Text(
          widget.source.isPreview
              ? 'This adds an example to the household preview. No notifications are sent.'
              : 'This post will be visible to linked households in ${widget.audience.communityName}. The backend will queue a notification. Do not include private household details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final current = await widget.source.loadContext();
      if (!current.canPublish ||
          current.communityId != widget.audience.communityId)
        throw StateError('Posting access changed');
      attemptedDraft ??= NoticeDraft(
        title: title.text.trim(),
        body: body.text.trim(),
        requestId: requestId,
      );
      final result = await widget.source.publish(attemptedDraft!);
      if (result.post.communityId != current.communityId)
        throw StateError('Invalid publication result');
      if (!mounted) return;
      final message = switch (result.notificationState) {
        NoticeNotificationState.queued => 'Post published. Notifications are queued; delivery is not guaranteed.',
        NoticeNotificationState.failed => 'Post published, but notifications could not be queued. Do not repost the same notice.',
        NoticeNotificationState.unknown =>
          'Post published. Notification delivery status is not available.',
        NoticeNotificationState.previewOnly =>
          'Preview post added. No notifications were sent.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Publishing could not be confirmed. Your draft is kept and locked for a safe retry. Retry this form with the same request; check the board before starting another post.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Create community post')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.source.isPreview) const _PreviewNotice(),
                Text(
                  'To: ${widget.audience.communityName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only authorised publishers can post. Household names, phone numbers and resident whereabouts should not be included.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: title,
                  enabled: !busy && attemptedDraft == null,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Post title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a title.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: body,
                  enabled: !busy && attemptedDraft == null,
                  maxLength: 4000,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a message.' : null,
                ),
                if (error != null) Text(error!),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy ? null : publish,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    busy
                        ? 'Publishing…'
                        : widget.source.isPreview
                        ? 'Publish preview post'
                        : 'Publish & notify households',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
