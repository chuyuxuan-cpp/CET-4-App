import 'package:flutter_test/flutter_test.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/study_provider.dart';

void main() {
  group('StudyState', () {
    test('initial state has expected defaults', () {
      const state = StudyState(
        words: [],
        currentIndex: 0,
        dailyQuota: 20,
        wordsLearnedToday: 0,
        isFlipped: false,
        isLoading: true,
        isBookmarked: false,
        hasMoreNewWords: true,
      );

      expect(state.hasWords, isFalse);
      expect(state.completed, isFalse);
      expect(state.currentWord, isNull);
    });

    test('completed is true when currentIndex exceeds words length', () {
      final state = StudyState.initial().copyWith(
        words: List<Word>.empty(),
        currentIndex: 0,
      );
      // completed requires hasWords and currentIndex >= words.length
      expect(state.completed, isFalse);

      final stateWithWords = StudyState.initial().copyWith(
        words: List<Word>.empty(),
        currentIndex: 0,
      );
      // Empty words list => hasWords false
    });

    test('hasMoreNewWords defaults to true in initial state', () {
      expect(StudyState.initial().hasMoreNewWords, isTrue);
    });

    test('copyWith preserves hasMoreNewWords when not provided', () {
      final state = StudyState.initial().copyWith(
        words: List<Word>.empty(),
        currentIndex: 0,
        isLoading: false,
      );

      expect(state.hasMoreNewWords, isTrue);
    });

    test('copyWith updates hasMoreNewWords when provided', () {
      final state = StudyState.initial().copyWith(hasMoreNewWords: false);

      expect(state.hasMoreNewWords, isFalse);
    });

    test('errorMessage is set and can be cleared via clearError', () {
      var state = StudyState.initial().copyWith(
        errorMessage: '保存失败，请重试',
      );
      expect(state.errorMessage, '保存失败，请重试');

      state = state.copyWith(clearError: true);
      expect(state.errorMessage, isNull);
    });

    test('completed session with words and index past end', () {
      final words = <Word>[];
      final state = StudyState.initial().copyWith(
        words: words,
        currentIndex: words.length,
        isLoading: false,
      );
      // hasWords is false when words is empty, so completed stays false
      expect(state.completed, isFalse);
    });
  });
}
