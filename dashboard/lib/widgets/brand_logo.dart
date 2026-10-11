import 'package:flutter/material.dart';

/// Renders the official TesterTrack telemetry radar brand icon.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showBadgeBackground;

  const BrandLogo({
    super.key,
    this.size = 28,
    this.showBadgeBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showBadgeBackground
          ? BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(size * 0.25),
              border: Border.all(
                color: const Color(0xFF1E293B),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F5D4).withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Graceful vector fallback if asset loading is delayed
          return Icon(
            Icons.track_changes_rounded,
            color: const Color(0xFF00F5D4),
            size: size * 0.65,
          );
        },
      ),
    );
  }
}

/// Renders the TesterTrack brand wordmark with name and tagline.
class BrandWordmark extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final double taglineSize;
  final bool showTagline;

  const BrandWordmark({
    super.key,
    this.logoSize = 36,
    this.titleSize = 20,
    this.taglineSize = 12,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandLogo(size: logoSize),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
                children: const [
                  TextSpan(text: 'Tester'),
                  TextSpan(
                    text: 'Track',
                    style: TextStyle(
                      color: Color(0xFF00F5D4),
                    ),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                'Know who is actually testing.',
                style: TextStyle(
                  fontSize: taglineSize,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
