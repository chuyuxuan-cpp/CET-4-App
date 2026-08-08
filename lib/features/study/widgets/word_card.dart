import 'package:flutter/material.dart';

import 'package:cet4_app/core/database/database.dart';

/// A flip-animated word card for the study screen.
///
/// [isFlipped] controls which face is visible. When the user taps the card,
/// [onTap] is called – typically the parent toggles [isFlipped] and this
/// widget animates to the new face automatically.
class WordCard extends StatefulWidget {
  final Word word;
  final bool isFlipped;
  final VoidCallback onTap;
  final VoidCallback? onSpeakerTap;

  const WordCard({
    super.key,
    required this.word,
    required this.isFlipped,
    required this.onTap,
    this.onSpeakerTap,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    // If the card is already flipped when first built, jump to the end.
    if (widget.isFlipped) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
    // When the word changes, reset to the front face instantly.
    if (widget.word.id != oldWidget.word.id) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.58;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.1415926535; // 0 → π
          final showBack = angle > 3.1415926535 / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showBack
                ? _buildBackFace(context, cardHeight)
                : _buildFrontFace(context, cardHeight),
          );
        },
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Front face – only the English word, large and centered
  // -----------------------------------------------------------------------

  Widget _buildFrontFace(BuildContext context, double height) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: _cardDecoration(theme),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Word text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.word.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          // Speaker button – bottom-right corner
          if (widget.onSpeakerTap != null)
            Positioned(right: 12, bottom: 12, child: _speakerButton(context)),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Back face – phonetic, pos, meaning, example
  // -----------------------------------------------------------------------

  Widget _buildBackFace(BuildContext context, double height) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Transform(
      // Mirror so the back-face text isn't reversed.
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.1415926535),
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: _cardDecoration(theme),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Word (smaller than front)
                    Text(
                      widget.word.word,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Phonetic
                    if (widget.word.phonetic != null &&
                        widget.word.phonetic!.isNotEmpty)
                      Text(
                        widget.word.phonetic!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Divider
                    Divider(color: cs.outlineVariant, thickness: 0.5),
                    const SizedBox(height: 16),

                    // Part of speech + meaning
                    if (widget.word.pos != null &&
                        widget.word.pos!.isNotEmpty) ...[
                      Text(
                        widget.word.pos!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Chinese meaning
                    if (widget.word.meaning != null &&
                        widget.word.meaning!.isNotEmpty)
                      Text(
                        widget.word.meaning!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Example sentence
                    if (widget.word.example != null &&
                        widget.word.example!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.word.example!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Speaker button
            if (widget.onSpeakerTap != null)
              Positioned(right: 12, bottom: 12, child: _speakerButton(context)),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Shared helpers
  // -----------------------------------------------------------------------

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _speakerButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onSpeakerTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.volume_up_rounded,
            size: 22,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
