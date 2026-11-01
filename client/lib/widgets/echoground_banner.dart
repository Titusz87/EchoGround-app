import 'package:flutter/material.dart';

/// The approved Uluru artwork, bundled locally; it makes no network requests.
class EchoGroundBanner extends StatelessWidget {
  const EchoGroundBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'EchoGround. Connected community. Prepared together. Wherever we call home.',
    child: ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1678 / 552,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Crop the presentation margins without changing the approved art.
            final imageWidth = constraints.maxWidth * 1774 / 1678;
            final imageHeight = constraints.maxWidth * 887 / 1678;
            final decodeWidth = (imageWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(640, 1774)
                .toInt();
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: OverflowBox(
                alignment: Alignment.center,
                minWidth: imageWidth,
                maxWidth: imageWidth,
                minHeight: imageHeight,
                maxHeight: imageHeight,
                child: Image.asset(
                  'lib/assets/images/app/echoground_uluru_header.webp',
                  width: imageWidth,
                  height: imageHeight,
                  cacheWidth: decodeWidth,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) => const ColoredBox(
                    color: Color(0xFF293D32),
                    child: Center(
                      child: Text(
                        'EchoGround',
                        style: TextStyle(color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Responsive presentation wrapper, preserving its children's order and state.
class EchoGroundPageBody extends StatelessWidget {
  const EchoGroundPageBody({
    super.key,
    required this.children,
    this.maxWidth = 850,
    this.padding = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}
