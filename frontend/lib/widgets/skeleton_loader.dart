import 'package:flutter/material.dart';

/// A shimmer animation widget for skeleton loading effects
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = widget.baseColor ??
        (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                0.0,
                0.5 + _animation.value * 0.25,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

/// A skeleton placeholder box with rounded corners
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A skeleton circle (for avatars, icons)
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton loader for scan history cards
class ScanHistoryCardSkeleton extends StatelessWidget {
  const ScanHistoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon, title, chip
              Row(
                children: [
                  const SkeletonCircle(size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: SkeletonBox(height: 20)),
                  const SizedBox(width: 16),
                  SkeletonBox(width: 80, height: 24, borderRadius: 12),
                ],
              ),
              const SizedBox(height: 12),
              // Scan ID
              SkeletonBox(width: 280, height: 14, borderRadius: 2),
              const SizedBox(height: 8),
              // Date
              const SkeletonBox(width: 120, height: 12),
              const SizedBox(height: 16),
              // Divider
              const SkeletonBox(height: 1),
              const SizedBox(height: 16),
              // Result badges
              Row(
                children: [
                  SkeletonBox(width: 80, height: 32, borderRadius: 8),
                  const SizedBox(width: 8),
                  SkeletonBox(width: 80, height: 32, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for scan history list
class ScanHistoryListSkeleton extends StatelessWidget {
  final int itemCount;

  const ScanHistoryListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ScanHistoryCardSkeleton(),
    );
  }
}

/// Skeleton loader for results summary stats
class ResultsSummarySkeleton extends StatelessWidget {
  const ResultsSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 100, height: 18),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatSkeleton()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatSkeleton()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatSkeleton()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Pie chart placeholder
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SkeletonBox(width: 80, height: 18),
                    const SizedBox(height: 24),
                    Center(
                      child: SkeletonCircle(size: 200),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SkeletonBox(width: 60, height: 14),
                        const SizedBox(width: 24),
                        const SkeletonBox(width: 60, height: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Probe results section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 18),
                    const SizedBox(height: 16),
                    ...List.generate(4, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProbeRowSkeleton(),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Column(
      children: const [
        SkeletonBox(width: 40, height: 32),
        SizedBox(height: 4),
        SkeletonBox(width: 50, height: 12),
      ],
    );
  }

  Widget _buildProbeRowSkeleton() {
    return Row(
      children: const [
        SkeletonCircle(size: 16),
        SizedBox(width: 12),
        Expanded(child: SkeletonBox(height: 16)),
        SizedBox(width: 16),
        SkeletonBox(width: 60, height: 24, borderRadius: 12),
      ],
    );
  }
}

/// Skeleton loader for charts tab
class ResultsChartsSkeleton extends StatelessWidget {
  const ResultsChartsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar chart card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 140, height: 18),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) =>
                          SkeletonBox(
                            width: 32,
                            height: 40.0 + (index * 25),
                            borderRadius: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Second chart card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 160, height: 18),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: SkeletonCircle(size: 180),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for probe selection list
class ProbeSelectionSkeleton extends StatelessWidget {
  const ProbeSelectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: [
          // Search bar skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: const SkeletonBox(height: 56, borderRadius: 8),
          ),
          // Filter chips skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SkeletonBox(width: 70, height: 32, borderRadius: 16),
                )),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Select all skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SkeletonBox(width: 24, height: 24, borderRadius: 4),
                SizedBox(width: 12),
                SkeletonBox(width: 100, height: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Probe categories skeleton
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Category header
                    ListTile(
                      leading: const SkeletonCircle(size: 24),
                      title: SkeletonBox(width: 120, height: 16),
                      trailing: const SkeletonBox(width: 24, height: 24, borderRadius: 12),
                    ),
                    // Probe items (collapsed, so just show header)
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
