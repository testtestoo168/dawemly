import 'package:flutter/material.dart';

/// Reusable shimmer loading effect — no external packages needed.
/// Uses AnimationController + LinearGradient to produce a "shine" sweep.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 6,
    this.baseColor = const Color(0xFFE5E7EB),
    this.highlightColor = const Color(0xFFF3F4F6),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer placeholder for a stat card (admin dashboard).
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerLoading(width: 80, height: 12),
          SizedBox(height: 10),
          ShimmerLoading(width: 50, height: 24, borderRadius: 4),
          SizedBox(height: 8),
          ShimmerLoading(width: 60, height: 10),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for an employee card (admin employees list).
class ShimmerEmployeeCard extends StatelessWidget {
  const ShimmerEmployeeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          // Left side placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(width: 60, height: 10),
                SizedBox(height: 6),
                ShimmerLoading(width: 80, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Right side: name + dept
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShimmerLoading(width: 120, height: 14),
                SizedBox(height: 6),
                ShimmerLoading(width: 80, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Avatar placeholder
          ShimmerLoading(width: 40, height: 40, borderRadius: 20),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for the attendance record card (emp home).
class ShimmerAttendanceCard extends StatelessWidget {
  const ShimmerAttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ShimmerLoading(height: 14)),
              SizedBox(width: 40),
              ShimmerLoading(width: 100, height: 14),
            ],
          ),
          SizedBox(height: 16),
          ShimmerLoading(height: 1),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerLoading(width: 80, height: 12),
              Spacer(),
              ShimmerLoading(width: 100, height: 12),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              ShimmerLoading(width: 80, height: 12),
              Spacer(),
              ShimmerLoading(width: 100, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}
