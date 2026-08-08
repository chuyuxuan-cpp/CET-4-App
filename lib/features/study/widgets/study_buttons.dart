import 'package:flutter/material.dart';

/// The row of action buttons shown below the word card after it is flipped.
///
/// Three buttons:
/// - [onUnknown]  – "不认识" (warm coral)
/// - [onBookmark] – star icon to toggle notebook (amber when active)
/// - [onKnown]    – "认识" (warm green)
///
/// [isBookmarked] drives the visual state of the star button.
class StudyButtons extends StatelessWidget {
  final VoidCallback onUnknown;
  final VoidCallback onKnown;
  final VoidCallback onBookmark;
  final bool isBookmarked;

  const StudyButtons({
    super.key,
    required this.onUnknown,
    required this.onKnown,
    required this.onBookmark,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "不认识"
          _ActionButton(
            label: '不认识',
            backgroundColor: const Color(0xFFFF6B6B),
            onBackground: Colors.white,
            onPressed: onUnknown,
          ),
          const SizedBox(width: 20),
          // Bookmark star
          _BookmarkButton(isBookmarked: isBookmarked, onPressed: onBookmark),
          const SizedBox(width: 20),
          // "认识"
          _ActionButton(
            label: '认识',
            backgroundColor: const Color(0xFF66BB6A),
            onBackground: Colors.white,
            onPressed: onKnown,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color onBackground;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onBackground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: onBackground,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onPressed;

  const _BookmarkButton({required this.isBookmarked, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = isBookmarked
        ? const Color(0xFFFFB74D) // warm amber when active
        : Theme.of(context).colorScheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isBookmarked
                ? const Color(0xFFFFB74D).withValues(alpha: 0.15)
                : Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: isBookmarked
                  ? const Color(0xFFFFB74D)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Icon(
            isBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 28,
            color: color,
          ),
        ),
      ),
    );
  }
}
