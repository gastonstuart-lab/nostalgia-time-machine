import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/models/quiz_question.dart';
import 'package:nostalgia_time_machine/models/quiz_score.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';
import 'package:nostalgia_time_machine/widgets/error_state.dart';

class WeeklyQuizScreen extends StatefulWidget {
  const WeeklyQuizScreen({super.key});

  @override
  State<WeeklyQuizScreen> createState() => _WeeklyQuizScreenState();
}

class _WeeklyQuizScreenState extends State<WeeklyQuizScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isRegenerating = false;
  List<QuizQuestion> _questions = [];
  List<int?> _selectedAnswers = [];
  QuizScore? _existingScore;

  String? _groupId;
  String? _weekId;
  String? _userId;
  int? _currentYear;
  String _quizDifficulty = 'medium';
  String _displayName = 'Anonymous';
  String? _yearLockError;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final provider = context.read<NostalgiaProvider>();
    final group = provider.currentGroup;
    final weekId = provider.currentWeekId;
    final userId = provider.currentUserId;
    final displayName = provider.currentUserProfile?.displayName ?? 'Anonymous';

    if (group == null || weekId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    _groupId = group.id;
    _weekId = weekId;
    _userId = userId;
    _currentYear = group.currentYear;
    _quizDifficulty = group.quizDifficulty;
    _displayName = displayName;

    try {
      final definitionBeforeFetch =
          await _firestoreService.getQuizDefinition(group.id, weekId);
      final initialStrictQuiz = _filterStrictYearLockedQuestions(
        definitionBeforeFetch,
        group.currentYear,
      );
      final bool loadedFromDefinition = initialStrictQuiz.length == 20;
      List<QuizQuestion> strictQuiz = initialStrictQuiz;

      if (!loadedFromDefinition) {
        await _firestoreService.fetchWeeklyQuiz(
          group.id,
          weekId,
          year: group.currentYear,
          difficulty: group.quizDifficulty,
        );
        final latestDefinition =
            await _firestoreService.getQuizDefinition(group.id, weekId);
        strictQuiz = _filterStrictYearLockedQuestions(
          latestDefinition,
          group.currentYear,
        );
      }
      debugPrint(
          '[QUIZ_SCREEN] year=${group.currentYear} weekId=$weekId source=${loadedFromDefinition ? 'definition' : 'generated'}');
      final existing =
          await _firestoreService.getUserQuizScore(group.id, weekId, userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = strictQuiz;
        _selectedAnswers = List<int?>.filled(strictQuiz.length, null);
        _existingScore = existing;
        _yearLockError = strictQuiz.length < 20
            ? 'This quiz is not locked to YEAR ${group.currentYear} yet. Please regenerate.'
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load the weekly quiz right now. Try again.'),
        ),
      );
    }
  }

  Future<void> _submitQuiz() async {
    if (_groupId == null || _weekId == null || _userId == null) return;
    if (_selectedAnswers.any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please answer all questions before submitting.')),
      );
      return;
    }

    final score = _questions
        .asMap()
        .entries
        .where(
            (entry) => _selectedAnswers[entry.key] == entry.value.correctIndex)
        .length;

    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.submitQuizScore(
        groupId: _groupId!,
        weekId: _weekId!,
        userId: _userId!,
        score: score,
        displayName: _displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Quiz submitted! Score: $score/${_questions.length}')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('QUIZ_ALREADY_TAKEN')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already took this week\'s quiz.')),
        );
        await _loadQuiz();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit quiz: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _regenerateQuiz() async {
    if (_groupId == null ||
        _weekId == null ||
        _currentYear == null ||
        _isRegenerating) {
      return;
    }

    setState(() => _isRegenerating = true);
    try {
      await _firestoreService.fetchWeeklyQuiz(
        _groupId!,
        _weekId!,
        year: _currentYear!,
        difficulty: _quizDifficulty,
        forceRegenerate: true,
      );
      final latestDefinition =
          await _firestoreService.getQuizDefinition(_groupId!, _weekId!);
      final strictQuiz = _filterStrictYearLockedQuestions(
        latestDefinition,
        _currentYear!,
      );
      if (!mounted) return;
      setState(() {
        _questions = strictQuiz;
        _selectedAnswers = List<int?>.filled(strictQuiz.length, null);
        _yearLockError = strictQuiz.length < 20
            ? 'This quiz is not locked to YEAR $_currentYear yet. Please regenerate.'
            : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strictQuiz.length < 20
                ? 'Regenerated, but quiz is still not year-locked.'
                : 'Quiz regenerated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not regenerate quiz: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  List<QuizQuestion> _filterStrictYearLockedQuestions(
    Map<String, dynamic>? definition,
    int year,
  ) {
    final rawQuestions = definition?['questions'] as List<dynamic>?;
    if (rawQuestions == null) return [];
    final strict = rawQuestions.whereType<Map>().map((q) {
      final map = Map<String, dynamic>.from(q);
      final qYear = (map['year'] as num?)?.toInt();
      final options = (map['choices'] as List?) ?? (map['options'] as List?);
      final placeholderPrefixes = options
          ?.map((o) => RegExp(r'^(.+)\s+[A-D]$').firstMatch('$o')?.group(1))
          .whereType<String>()
          .map((s) => s.toLowerCase())
          .toList();
      final hasPlaceholderOptions = placeholderPrefixes != null &&
          placeholderPrefixes.length == 4 &&
          placeholderPrefixes.toSet().length == 1;
      return (qYear == year && !hasPlaceholderOptions)
          ? QuizQuestion.fromJson(map)
          : null;
    }).whereType<QuizQuestion>().toList();
    return strict;
  }

  Future<void> _resetQuizForThisWeek() async {
    if (!kDebugMode || _groupId == null || _weekId == null) return;
    await _firestoreService.deleteQuizDefinition(_groupId!, _weekId!);
    await _regenerateQuiz();
  }

  @override
  Widget build(BuildContext context) {
    final optionTextColor = AppTheme.lightPrimaryText;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spacingSm),
              Text('Generating quiz...'),
            ],
          ),
        ),
      );
    }

    if (_groupId == null || _weekId == null || _userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weekly Quiz')),
        body: const Center(child: Text('No active group or week found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Regenerate quiz',
            onPressed:
                (_isSubmitting || _isRegenerating) ? null : _regenerateQuiz,
            icon: _isRegenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
        title: Text(
          'Weekly Quiz',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_yearLockError != null) ...[
                ErrorState(
                  message: _yearLockError!,
                  onRetry: _regenerateQuiz,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ElevatedButton(
                  onPressed: _isRegenerating ? null : _regenerateQuiz,
                  child: const Text('Regenerate quiz'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _isRegenerating ? null : _resetQuizForThisWeek,
                    child: const Text('Reset quiz for this week'),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingLg),
              ],
              Text(
                'Quiz Year: ${_currentYear ?? '-'} • Difficulty: $_quizDifficulty',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              if (_yearLockError == null && _existingScore != null)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.lightDivider, width: 2),
                  ),
                  child: Text(
                    'You already completed this week\'s quiz. Score: ${_existingScore!.score}/${_questions.length}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.lightPrimaryText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                )
              else if (_yearLockError == null) ...[
                ..._questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border:
                          Border.all(color: AppTheme.lightDivider, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ${question.question}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.lightPrimaryText,
                                  ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        ...question.options.asMap().entries.map((option) {
                          return RadioListTile<int>(
                            value: option.key,
                            groupValue: _selectedAnswers[index],
                            onChanged: _isSubmitting
                                ? null
                                : (value) => setState(
                                    () => _selectedAnswers[index] = value),
                            activeColor: AppTheme.lightPrimary,
                            title: Text(
                              option.value,
                              style: TextStyle(color: optionTextColor),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppTheme.spacingSm),
                ElevatedButton(
                  onPressed:
                      (_isSubmitting || _questions.isEmpty) ? null : _submitQuiz,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Quiz'),
                ),
              ],
              const SizedBox(height: AppTheme.spacingLg),
              _LeaderboardList(
                groupId: _groupId!,
                weekId: _weekId!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final String groupId;
  final String weekId;

  const _LeaderboardList({
    required this.groupId,
    required this.weekId,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightOnSurface, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Leaderboard',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightPrimaryText,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          StreamBuilder<List<QuizScore>>(
            stream: firestoreService.listenToLeaderboard(groupId, weekId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final scores = snapshot.data ?? [];
              if (scores.isEmpty) {
                return Text(
                  'No quiz scores yet this week.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                );
              }

              return Column(
                children: scores.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final score = entry.value;
                  return ListTile(
                    dense: true,
                    leading: Text('#$rank',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    title: Text(score.displayName,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text('${score.score}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
