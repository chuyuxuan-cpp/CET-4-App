import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AppDataEventsState {
  const AppDataEventsState({
    this.settingsRevision = 0,
    this.studyRevision = 0,
    this.notebookRevision = 0,
  });

  final int settingsRevision;
  final int studyRevision;
  final int notebookRevision;

  AppDataEventsState copyWith({
    int? settingsRevision,
    int? studyRevision,
    int? notebookRevision,
  }) {
    return AppDataEventsState(
      settingsRevision: settingsRevision ?? this.settingsRevision,
      studyRevision: studyRevision ?? this.studyRevision,
      notebookRevision: notebookRevision ?? this.notebookRevision,
    );
  }
}

class AppDataEventsNotifier extends Notifier<AppDataEventsState> {
  @override
  AppDataEventsState build() => const AppDataEventsState();

  void settingsChanged() {
    state = state.copyWith(settingsRevision: state.settingsRevision + 1);
  }

  void studyChanged() {
    state = state.copyWith(studyRevision: state.studyRevision + 1);
  }

  void notebookChanged() {
    state = state.copyWith(notebookRevision: state.notebookRevision + 1);
  }
}

final appDataEventsProvider =
    NotifierProvider<AppDataEventsNotifier, AppDataEventsState>(
      AppDataEventsNotifier.new,
    );
