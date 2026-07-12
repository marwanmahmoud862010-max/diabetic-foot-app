import 'package:flutter/material.dart';

Route<dynamic> _buildRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => _BrandedTransition(
      page: page,
      animation: animation,
    ),
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 800),
  );
}

Future<dynamic> pushPage(BuildContext context, Widget page) {
  return Navigator.push<dynamic>(context, _buildRoute(page));
}

Future<dynamic> pushReplacementPage(BuildContext context, Widget page) {
  return Navigator.pushReplacement<dynamic, dynamic>(context, _buildRoute(page));
}

class _BrandedTransition extends StatelessWidget {
  final Widget page;
  final Animation<double> animation;

  const _BrandedTransition({
    required this.page,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final status = animation.status;
        final bool isForward = status == AnimationStatus.forward;
        final bool isReverse = status == AnimationStatus.reverse;
        final logoVisible = isForward
            ? (animation.value < 0.5 ? 1.0 : 0.0)
            : isReverse
                ? (animation.value > 0.5 ? 1.0 : 0.0)
                : 0.0;
        final pageSlide = 30 * (1 - _interval(0.55, 1.0, animation.value));
        final pageFade = _interval(0.55, 1.0, animation.value);
        final isRtl = Directionality.of(context) == TextDirection.rtl;

        return Stack(
          children: [
            Container(),
            Transform.translate(
              offset: Offset(isRtl ? -pageSlide : pageSlide, 0),
              child: Opacity(
                opacity: pageFade,
                child: page,
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: logoVisible,
                  child: Transform.scale(
                    scale: 3.0,
                    child: Image.asset(
                      'assets/image-removebg-preview.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _interval(double start, double end, double t) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }
}
