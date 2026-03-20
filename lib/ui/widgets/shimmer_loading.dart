import 'package:flutter/material.dart';
import 'package:kameti/ui/theme/theme.dart';

/// A shimmer/skeleton loading effect widget.
/// Wraps its child in a shimmering animation to indicate loading state.
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                AppColors.cFF2A2A2E,
                AppColors.cFF3A3A40,
                AppColors.cFF2A2A2E,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Skeleton placeholder box for shimmer effects
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cFF2A2A2E,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton loading for the dashboard welcome card
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: [
          // Welcome card skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cFF2A2A2E,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 180, height: 24),
                const SizedBox(height: 8),
                const SkeletonBox(width: 120, height: 16),
              ],
            ),
          ),
          // Action card skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const SkeletonBox(height: 72, borderRadius: 16),
          ),
          // Section title skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const SkeletonBox(width: 160, height: 18),
          ),
          // Committee card skeletons
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const _CommitteeCardSkeleton(),
          )),
        ],
      ),
    );
  }
}

/// Skeleton loading for a single committee card
class _CommitteeCardSkeleton extends StatelessWidget {
  const _CommitteeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cFF1E1E22,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 48, height: 48, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 140, height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 12),
              ],
            ),
          ),
          const SkeletonBox(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton loading for payment sheet
class PaymentSheetSkeleton extends StatelessWidget {
  const PaymentSheetSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats row skeleton
            Row(
              children: List.generate(3, (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cFF1E1E22,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      SkeletonBox(width: 40, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 60, height: 20),
                    ],
                  ),
                ),
              )),
            ),
            const SizedBox(height: 20),
            // Member payment rows
            ...List.generate(5, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cFF1E1E22,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    SkeletonBox(width: 40, height: 40, borderRadius: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 80, height: 10),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 60, height: 30, borderRadius: 15),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading for member list
class MemberListSkeleton extends StatelessWidget {
  const MemberListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(6, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cFF1E1E22,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  SkeletonBox(width: 44, height: 44, borderRadius: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 130, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 90, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ),
      ),
    );
  }
}
