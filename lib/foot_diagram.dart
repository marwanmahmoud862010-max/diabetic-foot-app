import 'package:flutter/material.dart';

class FootDiagram extends StatelessWidget {
  final int? highlightedToe;
  final String? highlightedRegion;
  final double size;
  final bool showLabels;
  final String footSide;

  const FootDiagram({
    super.key,
    this.highlightedToe,
    this.highlightedRegion,
    this.size = 100,
    this.showLabels = true,
    this.footSide = 'right',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.5,
      child: CustomPaint(
        painter: _FootPainter(
          highlightedToe: highlightedToe,
          highlightedRegion: highlightedRegion,
          showLabels: showLabels,
          isLeft: footSide == 'left',
          greyFill: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        size: Size(size, size * 1.5),
      ),
    );
  }
}

class _FootPainter extends CustomPainter {
  final int? highlightedToe;
  final String? highlightedRegion;
  final bool showLabels;
  final bool isLeft;
  final Color greyFill;

  _FootPainter({
    this.highlightedToe,
    this.highlightedRegion,
    this.showLabels = true,
    this.isLeft = false,
    required this.greyFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokeColor = Colors.black;
    final hlOrange = Colors.orange.shade300;
    final sw = w * 0.03;

    final ballR = Rect.fromLTWH(w * 0.10, h * 0.06, w * 0.78, h * 0.52);
    final archR = Rect.fromLTWH(w * 0.20, h * 0.38, w * 0.58, h * 0.28);
    final heelR = Rect.fromLTWH(w * 0.20, h * 0.52, w * 0.58, h * 0.40);

    Path buildBody() {
      Path b = Path()..addOval(ballR);
      b = Path.combine(PathOperation.union, b, Path()..addRect(archR));
      b = Path.combine(PathOperation.union, b, Path()..addOval(heelR));
      final cut = Path()..addOval(Rect.fromLTWH(
        isLeft ? w * 0.62 : w * 0.03,
        h * 0.30,
        w * 0.35,
        h * 0.35,
      ));
      return Path.combine(PathOperation.difference, b, cut);
    }

    final bodyPath = buildBody();

    canvas.drawPath(bodyPath, Paint()..color = greyFill);

    if (highlightedRegion == 'mid') {
      canvas.save();
      canvas.clipPath(bodyPath);
      canvas.drawOval(ballR, Paint()..color = hlOrange);
      canvas.drawRect(archR, Paint()..color = hlOrange);
      canvas.restore();
    } else if (highlightedRegion == 'heel') {
      canvas.save();
      canvas.clipPath(bodyPath);
      canvas.drawOval(heelR, Paint()..color = hlOrange);
      canvas.restore();
    }

    canvas.drawPath(bodyPath, Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw.clamp(1.5, 4.0)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    final toeX = isLeft
        ? [0.70, 0.58, 0.44, 0.30, 0.18]
        : [0.18, 0.30, 0.44, 0.58, 0.70];
    final toeR = [0.082, 0.065, 0.053, 0.048, 0.040];
    final toeY = h * 0.04;

    for (int i = 0; i < 5; i++) {
      final hl = highlightedToe == i + 1 || highlightedRegion == 'toes';
      final c = Offset(w * toeX[i], toeY);

      canvas.drawCircle(c, w * toeR[i], Paint()..color = hl ? hlOrange : greyFill);
      canvas.drawCircle(c, w * toeR[i], Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw.clamp(1.5, 3.5));

      if (showLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: hl ? Colors.orange.shade800 : Colors.grey.shade600,
              fontSize: w * 0.085,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + w * toeR[i] + 3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FootPainter old) =>
      old.highlightedToe != highlightedToe ||
      old.highlightedRegion != highlightedRegion ||
      old.isLeft != isLeft;
}
