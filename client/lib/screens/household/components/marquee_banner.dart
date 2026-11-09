import 'package:flutter/material.dart';

/// An animated text banner that continuously scrolls from right to left linearly.
class MarqueeBanner extends StatefulWidget {
  final String text;
  const MarqueeBanner({super.key, required this.text});

  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner> {
  late ScrollController _scrollController;
  bool _isLooping = false; // Prevents overlapping animation threads

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimationLoop());
  }

  // Detects incoming real-time backend updates and forces the scrolling thread to adapt to the new size
  @override
  void didUpdateWidget(covariant MarqueeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0); // Snap back to the beginning immediately
      }
      // Trigger animation calculation on the next frame pass
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startAnimationLoop(),
      );
    }
  }

  void _startAnimationLoop() async {
    if (_isLooping) return; // Guard against thread duplicates
    _isLooping = true;

    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || !_scrollController.hasClients) {
        _isLooping = false;
        return;
      }

      final double maxScroll = _scrollController.position.maxScrollExtent;

      if (maxScroll > 0) {
        // Linearly crawl text forward. Scale duration based on text length (width * 45ms)
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: (maxScroll * 45).toInt()),
          curve: Curves.linear,
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0); // Snap back to the beginning to loop
        }
      } else {
        // If text is too short to scroll, wait briefly before checking again
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _isLooping = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics:
          const NeverScrollableScrollPhysics(), // Blocks human touch conflict
      child: Row(
        children: [
          const SizedBox(width: 340), // Offscreen right entry buffer
          Text(
            widget.text,
            style: const TextStyle(
              color: Color(0xFF4DB6AC), // Teal theme color match
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 340), // Offscreen left tail-off buffer
        ],
      ),
    );
  }
}
