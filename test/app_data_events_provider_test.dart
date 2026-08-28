import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cet4_app/core/providers/app_data_events_provider.dart';

void main() {
  test('initial state has all revisions at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(appDataEventsProvider);

    expect(state.settingsRevision, 0);
    expect(state.studyRevision, 0);
    expect(state.notebookRevision, 0);
  });

  test('settingsChanged increments only settings revision', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appDataEventsProvider.notifier).settingsChanged();

    expect(container.read(appDataEventsProvider).settingsRevision, 1);
    expect(container.read(appDataEventsProvider).studyRevision, 0);
    expect(container.read(appDataEventsProvider).notebookRevision, 0);
  });

  test('studyChanged increments only study revision', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appDataEventsProvider.notifier).studyChanged();

    expect(container.read(appDataEventsProvider).studyRevision, 1);
    expect(container.read(appDataEventsProvider).settingsRevision, 0);
    expect(container.read(appDataEventsProvider).notebookRevision, 0);
  });

  test('notebookChanged increments only notebook revision', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appDataEventsProvider.notifier).notebookChanged();

    expect(container.read(appDataEventsProvider).notebookRevision, 1);
    expect(container.read(appDataEventsProvider).studyRevision, 0);
    expect(container.read(appDataEventsProvider).settingsRevision, 0);
  });

  test('multiple calls accumulate independently', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appDataEventsProvider.notifier).studyChanged();
    container.read(appDataEventsProvider.notifier).studyChanged();
    container.read(appDataEventsProvider.notifier).notebookChanged();

    expect(container.read(appDataEventsProvider).studyRevision, 2);
    expect(container.read(appDataEventsProvider).notebookRevision, 1);
    expect(container.read(appDataEventsProvider).settingsRevision, 0);
  });

  test('state is immutable after copyWith', () {
    const original = AppDataEventsState();

    final copy = original.copyWith(settingsRevision: 5);

    expect(original.settingsRevision, 0);
    expect(copy.settingsRevision, 5);
    expect(copy.studyRevision, 0);
    expect(copy.notebookRevision, 0);
  });
}
