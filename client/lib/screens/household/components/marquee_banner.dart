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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Start animation immediately after the layout renders its first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimationLoop());
  }

  void _startAnimationLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || !_scrollController.hasClients) return;

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
      }
    }
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
