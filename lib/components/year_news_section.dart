import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/year_news.dart';
import '../screens/story_detail_page.dart';
import '../theme.dart';

class YearNewsSection extends StatefulWidget {
  final YearNewsPackage package;

  const YearNewsSection({
    super.key,
    required this.package,
  });

  @override
  State<YearNewsSection> createState() => _YearNewsSectionState();
}

class _YearNewsSectionState extends State<YearNewsSection> {
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final ScrollController _monthRailController = ScrollController();
  Timer? _heroTimer;
  Timer? _resumeAutoTimer;
  Timer? _monthRailTimer;
  Timer? _monthRailResumeTimer;
  int _selectedMonth = 1;
  int _heroIndex = 0;
  bool _isUserInteracting = false;
  bool _isMonthRailInteracting = false;

  List<YearNewsItem> get _heroItems => widget.package.hero;
  List<YearNewsItem> get _storiesForSelectedMonth =>
      widget.package.storiesForMonth(_selectedMonth);
  List<YearNewsItem> get _storiesForRail {
    final stories = _storiesForSelectedMonth;
    if (stories.length <= 1) {
      return stories;
    }
    return [...stories, ...stories, ...stories];
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = _initialMonth();
    _startAutoAdvance();
    _startMonthRailAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMonthRailPosition();
    });
  }

  @override
  void didUpdateWidget(covariant YearNewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.package.year != widget.package.year) {
      _selectedMonth = _initialMonth();
      _heroIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetMonthRailPosition();
      });
    }
  }

  Future<void> _openStoryDetail(YearNewsItem item) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailPage(
          year: widget.package.year,
          item: item,
        ),
      ),
    );
  }

  int _initialMonth() {
    final nowMonth = DateTime.now().month;
    if (widget.package.byMonth[nowMonth]?.isNotEmpty == true) {
      return nowMonth;
    }
    final monthWithStories = widget.package.byMonth.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    return monthWithStories.isEmpty ? 1 : monthWithStories.first;
  }

  void _startAutoAdvance() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || _isUserInteracting || _heroItems.length < 2) {
        return;
      }
      setState(() {
        _heroIndex = (_heroIndex + 1) % _heroItems.length;
      });
    });
  }

  void _previousHero() {
    if (_heroItems.length < 2) return;
    setState(() {
      _heroIndex = (_heroIndex - 1 + _heroItems.length) % _heroItems.length;
    });
  }

  void _nextHero() {
    if (_heroItems.length < 2) return;
    setState(() {
      _heroIndex = (_heroIndex + 1) % _heroItems.length;
    });
  }

  void _onUserInteractionStart() {
    _resumeAutoTimer?.cancel();
    if (!_isUserInteracting) {
      setState(() => _isUserInteracting = true);
    }
  }

  void _onUserInteractionEnd() {
    _resumeAutoTimer?.cancel();
    _resumeAutoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
      }
    });
  }

  void _startMonthRailAutoScroll() {
    _monthRailTimer?.cancel();
    _monthRailTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (!mounted ||
          _isMonthRailInteracting ||
          !_monthRailController.hasClients ||
          _storiesForSelectedMonth.length < 2) {
        return;
      }
      final position = _monthRailController.position;
      if (position.maxScrollExtent <= 0) return;

      final segment = position.maxScrollExtent / 3;
      final loopStart = segment;
      final loopEnd = segment * 2;
      final next = position.pixels + 0.55;
      if (next >= loopEnd) {
        _monthRailController.jumpTo(loopStart);
      } else {
        _monthRailController.jumpTo(next);
      }
    });
  }

  void _resetMonthRailPosition() {
    if (!_monthRailController.hasClients) return;
    if (_storiesForSelectedMonth.length < 2) {
      _monthRailController.jumpTo(0);
      return;
    }
    final maxExtent = _monthRailController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _monthRailController.jumpTo(maxExtent / 3);
  }

  void _onMonthRailInteractionStart() {
    _monthRailResumeTimer?.cancel();
    if (!_isMonthRailInteracting) {
      setState(() => _isMonthRailInteracting = true);
    }
  }

  void _onMonthRailInteractionEnd() {
    _monthRailResumeTimer?.cancel();
    _monthRailResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isMonthRailInteracting = false);
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _resumeAutoTimer?.cancel();
    _monthRailTimer?.cancel();
    _monthRailResumeTimer?.cancel();
    _monthRailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = theme.brightness == Brightness.dark
        ? AppTheme.darkPrimaryText
        : AppTheme.lightPrimaryText;
    final secondaryText = theme.brightness == Brightness.dark
        ? AppTheme.darkSecondaryText
        : AppTheme.lightSecondaryText;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.tertiary.withValues(alpha: 0.18),
          ],
        ),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border:
                      Border.all(color: theme.colorScheme.onSurface, width: 2),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year News ${widget.package.year}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                      ),
                    ),
                    Text(
                      'Stories across all 12 months',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          SizedBox(
            height: 228,
            child: Listener(
              onPointerDown: (_) => _onUserInteractionStart(),
              onPointerUp: (_) => _onUserInteractionEnd(),
              child: GestureDetector(
                onHorizontalDragStart: (_) => _onUserInteractionStart(),
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < 0) {
                    _nextHero();
                  } else if (velocity > 0) {
                    _previousHero();
                  }
                  _onUserInteractionEnd();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _heroItems.isEmpty
                      ? const _HeroPlaceholderCard(
                          key: ValueKey<String>('hero_empty'),
                        )
                      : _HeroStoryCard(
                          key: ValueKey<String>('hero_${_heroIndex}_card'),
                          item: _heroItems[_heroIndex],
                          resolvedImageUrl: _heroItems[_heroIndex].imageUrl,
                          onOpen: () => _openStoryDetail(_heroItems[_heroIndex]),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _heroItems.isEmpty ? 1 : _heroItems.length,
              (index) => Container(
                width: index == _heroIndex ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _heroIndex
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected = _selectedMonth == month;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMonth = month);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _resetMonthRailPosition();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.onSecondary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _months[index],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? theme.colorScheme.onSecondary
                              : primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          SizedBox(
            height: 220,
            child: _storiesForSelectedMonth.isEmpty
                ? _EmptyMonthStories(monthLabel: _months[_selectedMonth - 1])
                : MouseRegion(
                    onEnter: (_) => _onMonthRailInteractionStart(),
                    onExit: (_) => _onMonthRailInteractionEnd(),
                    child: Listener(
                      onPointerDown: (_) => _onMonthRailInteractionStart(),
                      onPointerUp: (_) => _onMonthRailInteractionEnd(),
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          if (notification.direction == ScrollDirection.idle) {
                            _onMonthRailInteractionEnd();
                          } else {
                            _onMonthRailInteractionStart();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          controller: _monthRailController,
                          scrollDirection: Axis.horizontal,
                          itemCount: _storiesForRail.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppTheme.spacingSm),
                          itemBuilder: (context, index) {
                            final sourceStories = _storiesForSelectedMonth;
                            final item = sourceStories.isEmpty
                                ? _storiesForRail[index]
                                : _storiesForRail[index % sourceStories.length];
                            return _MonthStoryCard(
                              item: item,
                              month: _selectedMonth,
                              onOpen: () => _openStoryDetail(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class YearNewsSectionSkeleton extends StatelessWidget {
  const YearNewsSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final highlight = theme.colorScheme.onSurface.withValues(alpha: 0.2);

    Widget box({
      required double width,
      required double height,
      double radius = AppTheme.radiusMd,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: highlight, width: 1),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(width: 180, height: 16),
          const SizedBox(height: AppTheme.spacingSm),
          box(width: double.infinity, height: 220, radius: AppTheme.radiusLg),
          const SizedBox(height: AppTheme.spacingSm),
          Row(
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: box(width: 44, height: 30),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              box(width: 220, height: 180, radius: AppTheme.radiusLg),
              const SizedBox(width: AppTheme.spacingSm),
              box(width: 220, height: 180, radius: AppTheme.radiusLg),
            ],
          ),
        ],
      ),
    );
  }
}

class YearNewsTicker extends StatefulWidget {
  final List<String> headlines;

  const YearNewsTicker({
    super.key,
    required this.headlines,
  });

  @override
  State<YearNewsTicker> createState() => _YearNewsTickerState();
}

class _YearNewsTickerState extends State<YearNewsTicker> {
  final ScrollController _scrollController = ScrollController();
  Timer? _tickerTimer;

  List<String> get _tickerItems {
    if (widget.headlines.isEmpty) return const <String>[];
    return [...widget.headlines, ...widget.headlines, ...widget.headlines];
  }

  @override
  void initState() {
    super.initState();
    _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTickerPosition();
    });
  }

  @override
  void didUpdateWidget(covariant YearNewsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headlines != widget.headlines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeTickerPosition();
      });
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;

      if (widget.headlines.length > 1) {
        final segment = position.maxScrollExtent / 3;
        final loopStart = segment;
        final loopEnd = segment * 2;
        if (position.pixels < loopStart) {
          _scrollController.jumpTo(loopStart);
          return;
        }

        final next = position.pixels + 0.42;
        if (next >= loopEnd) {
          _scrollController.jumpTo(loopStart);
        } else {
          _scrollController.jumpTo(next);
        }
        return;
      }

      final next = position.pixels + 0.42;
      if (next >= position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(next);
      }
    });
  }

  void _initializeTickerPosition() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    if (widget.headlines.length > 1) {
      _scrollController.jumpTo(max / 3);
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _showHeadlinesSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _HeadlinesSheet(headlines: widget.headlines),
    );
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _tickerItems;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: theme.colorScheme.onSurface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.campaign_rounded, color: theme.colorScheme.surface),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final headline = items[index];
                  return InkWell(
                    onTap: _showHeadlinesSheet,
                    child: Center(
                      child: Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: _showHeadlinesSheet,
              child: Text(
                'All',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.surface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _HeroStoryCard extends StatelessWidget {
  final YearNewsItem item;
  final String resolvedImageUrl;
  final VoidCallback onOpen;

  const _HeroStoryCard({
    super.key,
    required this.item,
    required this.resolvedImageUrl,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = resolvedImageUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: 1.05),
            duration: const Duration(seconds: 7),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: hasImage
                ? Image.network(
                    resolvedImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.68),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    item.source.isEmpty ? 'Top Story' : item.source,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.title.isEmpty ? 'Untitled story' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholderCard extends StatelessWidget {
  const _HeroPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          'Hero stories are not ready yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MonthStoryCard extends StatelessWidget {
  final YearNewsItem item;
  final int month;
  final VoidCallback onOpen;

  const _MonthStoryCard({
    required this.item,
    required this.month,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = theme.brightness == Brightness.dark
        ? AppTheme.darkPrimaryText
        : AppTheme.lightPrimaryText;
    final secondaryText = theme.brightness == Brightness.dark
        ? AppTheme.darkSecondaryText
        : AppTheme.lightSecondaryText;
    final gradients = <List<Color>>[
      [const Color(0xFF2D2A20), const Color(0xFF5E3A14)],
      [const Color(0xFF243447), const Color(0xFF4F6D7A)],
      [const Color(0xFF3A2E39), const Color(0xFF6F4E7C)],
      [const Color(0xFF2C3A2D), const Color(0xFF4D6A50)],
      [const Color(0xFF373221), const Color(0xFF7A5A2B)],
      [const Color(0xFF27354A), const Color(0xFF57749D)],
      [const Color(0xFF2F2F2F), const Color(0xFF636363)],
      [const Color(0xFF2E3A2F), const Color(0xFF5A7A5E)],
      [const Color(0xFF322D40), const Color(0xFF655A88)],
      [const Color(0xFF3A2525), const Color(0xFF7A4747)],
      [const Color(0xFF2C3642), const Color(0xFF5D7184)],
      [const Color(0xFF3C3021), const Color(0xFF7A613D)],
    ];
    final headerGradient = gradients[(month - 1).clamp(0, 11)];

    return SizedBox(
      width: 260,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: headerGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: headerGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'Untitled story' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: primaryText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Open'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: 0.26),
            theme.colorScheme.primary.withValues(alpha: 0.26),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }
}

class _EmptyMonthStories extends StatelessWidget {
  final String monthLabel;

  const _EmptyMonthStories({
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
      ),
      child: Center(
        child: Text(
          'No stories loaded for $monthLabel yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HeadlinesSheet extends StatelessWidget {
  final List<String> headlines;

  const _HeadlinesSheet({
    required this.headlines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Year News Headlines',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: headlines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: theme.colorScheme.onSurface, width: 1.5),
                  ),
                  child: Text(
                    headlines[index],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
