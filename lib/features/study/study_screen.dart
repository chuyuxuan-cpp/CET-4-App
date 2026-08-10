import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/providers/study_provider.dart';
import 'package:cet4_app/core/services/tts_service.dart';
import 'package:cet4_app/features/study/widgets/word_card.dart';
import 'package:cet4_app/features/study/widgets/study_buttons.dart';

/// The main study (背单词) screen.
///
/// Displays a flipping word card, a progress bar, action buttons for marking
/// the word known / unknown, a bookmark toggle, and a TTS speaker control.
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with WidgetsBindingObserver {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.initialize().catchError((_) {});

    // Kick-off loading after the first frame so the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyProvider.notifier).loadTodayWords();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _tts.stop();
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final studyState = ref.watch(studyProvider);
    final notifier = ref.read(studyProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('背单词'), centerTitle: true),
      body: _buildBody(studyState, notifier),
    );
  }

  Widget _buildBody(StudyState state, StudyNotifier notifier) {
    // ---- Loading ----
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ---- Error ----
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => notifier.loadTodayWords(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // ---- Session completed ----
    if (state.completed) {
      return _buildCompletedView(state);
    }

    // ---- Active session ----
    final word = state.currentWord;
    if (word == null) {
      return const Center(child: Text('暂无单词'));
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildProgressBar(state),
          const SizedBox(height: 16),
          // Word card
          Expanded(
            child: WordCard(
              word: word,
              isFlipped: state.isFlipped,
              onTap: () => notifier.flipCard(),
              onSpeakerTap: () => _speak(word.word),
            ),
          ),
          // Action buttons – only visible when the card is flipped
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: state.isFlipped
                ? Column(
                    children: [
                      StudyButtons(
                        onUnknown: () => notifier.markUnknown(),
                        onKnown: () => notifier.markKnown(),
                        onBookmark: () => notifier.toggleBookmark(),
                        isBookmarked: state.isBookmarked,
                      ),
                      const SizedBox(height: 24),
                    ],
                  )
                : const SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Progress bar
  // -----------------------------------------------------------------------

  Widget _buildProgressBar(StudyState state) {
    final total = state.words.length;
    final current = (state.currentIndex + 1).clamp(0, total);
    final value = total > 0 ? current / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '学习进度',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                state.progress,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Completed view
  // -----------------------------------------------------------------------

  Widget _buildCompletedView(StudyState state) {
    final theme = Theme.of(context);
    final notifier = ref.read(studyProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '今日学习完成！',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              '今日已学 ${state.wordsLearnedToday + state.words.length} 个新词',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每天 ${state.dailyQuota} 个，明天继续加油',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed:
                  state.hasMoreNewWords
                      ? () => notifier.loadExtraWords()
                      : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                state.hasMoreNewWords ? '再来 10 词' : '当前词书已无新词',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => notifier.loadTodayWords(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // TTS
  // -----------------------------------------------------------------------

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } on TtsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}
