import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/year_news.dart';
import '../models/year_news_story.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

class StoryDetailPage extends StatefulWidget {
  final int year;
  final YearNewsItem item;

  const StoryDetailPage({
    super.key,
    required this.year,
    required this.item,
  });

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<YearNewsStory> _storyFuture;

  @override
  void initState() {
    super.initState();
    _storyFuture = _firestoreService.getOrGenerateYearNewsStory(
      year: widget.year,
      item: widget.item,
    );
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = theme.brightness == Brightness.dark
        ? AppTheme.darkPrimaryText
        : AppTheme.lightPrimaryText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Detail'),
      ),
      body: FutureBuilder<YearNewsStory>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StoryLoadingView();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _StoryErrorView(
              onRetry: () {
                setState(() {
                  _storyFuture = _firestoreService.getOrGenerateYearNewsStory(
                    year: widget.year,
                    item: widget.item,
                  );
                });
              },
            );
          }

          final story = snapshot.data!;
          final imageUrl = story.imageUrl.trim().isNotEmpty
              ? story.imageUrl.trim()
              : widget.item.imageUrl.trim();
          final referenceUrl = story.referenceUrl.trim().isNotEmpty
              ? story.referenceUrl.trim()
              : widget.item.url.trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _FallbackHero(theme: theme),
                        )
                      : _FallbackHero(theme: theme),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  story.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  story.subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: primaryText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    story.source.isEmpty ? 'AI Historical Digest' : story.source,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                ...story.bodyParagraphs.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: primaryText,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        referenceUrl.isEmpty ? null : () => _openExternal(referenceUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Read Related Sources'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryLoadingView extends StatelessWidget {
  const _StoryLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            height: 20,
            width: 240,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            height: 16,
            width: double.infinity,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _StoryErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoryErrorView({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Could not load this story yet.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackHero extends StatelessWidget {
  final ThemeData theme;

  const _FallbackHero({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.tertiary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 54,
        ),
      ),
    );
  }
}
