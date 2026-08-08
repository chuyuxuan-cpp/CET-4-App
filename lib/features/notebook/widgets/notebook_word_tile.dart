import 'package:flutter/material.dart';

import 'package:cet4_app/core/database/database.dart';

/// A list-tile representation of a notebook word.
///
/// Displays the word (bold, large), phonetic, and Chinese meaning.
/// Designed to be wrapped in a [Dismissible] by the parent screen for
/// swipe-to-delete behaviour, but can also show a trailing remove icon.
class NotebookWordTile extends StatelessWidget {
  /// The notebook word data to display.
  final NotebookWord notebookWord;

  /// Called when the user taps the trailing remove icon.
  ///
  /// When null the trailing icon is hidden – the parent is expected to
  /// handle removal via a [Dismissible] wrapper instead.
  final VoidCallback? onRemove;

  const NotebookWordTile({
    super.key,
    required this.notebookWord,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final word = notebookWord.word;
    final firstLetter =
        word.word.isNotEmpty ? word.word.characters.first.toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        child: Text(
          firstLetter,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      title: Text(
        word.word,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      subtitle: _buildSubtitle(theme, cs, word),
      trailing: onRemove != null
          ? IconButton(
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              tooltip: '移出生词本',
              onPressed: onRemove,
            )
          : Icon(
              Icons.swipe_left_rounded,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              size: 20,
            ),
    );
  }

  Widget _buildSubtitle(ThemeData theme, ColorScheme cs, Word word) {
    final parts = <String>[];

    if (word.phonetic != null && word.phonetic!.isNotEmpty) {
      parts.add(word.phonetic!);
    }
    if (word.pos != null && word.pos!.isNotEmpty) {
      parts.add(word.pos!);
    }

    final header = parts.isNotEmpty ? parts.join('  ') : null;
    final meaning = word.meaning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Text(
            header,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        if (meaning != null && meaning.isNotEmpty)
          Text(
            meaning,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
      ],
    );
  }
}
