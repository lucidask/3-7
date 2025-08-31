import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef CardBuilder = Widget Function();

class GameAnimations {
  static Rect _rectOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return Rect.zero;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return Rect.zero;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  static Future<void> _fly({
    required BuildContext context,
    required TickerProvider vsync,
    required Rect from,
    required Rect to,
    required Duration duration,
    required Curve curve,
    required Widget child,
    double startScale = 1,
    double endScale = 1,
    double startOpacity = 1,
    double endOpacity = 1,
  }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final ctrl = AnimationController(vsync: vsync, duration: duration);
    final anim = CurvedAnimation(parent: ctrl, curve: curve);

    final pos = RectTween(begin: from, end: to).animate(anim);
    final scale = Tween<double>(begin: startScale, end: endScale).animate(anim);
    final alpha = Tween<double>(begin: startOpacity, end: endOpacity).animate(anim);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        final r = pos.value ?? from;
        return IgnorePointer(
          ignoring: true,
          child: Stack(children: [
            Positioned(
              left: r.left,
              top: r.top,
              width: r.width,
              height: r.height,
              child: Opacity(
                opacity: alpha.value.clamp(0, 1),
                child: Transform.scale(
                  scale: scale.value,
                  child: child,
                ),
              ),
            ),
          ]),
        );
      },
    );

    overlay.insert(entry);
    void tick() => entry.markNeedsBuild();
    ctrl.addListener(tick);
    await ctrl.forward();
    ctrl.removeListener(tick);
    entry.remove();
    ctrl.dispose();
  }

  // API
  static Future<void> deal({
    required BuildContext context,
    required TickerProvider vsync,
    required GlobalKey deckKey,
    required List<GlobalKey> targets,
    required CardBuilder cardBuilder,
    Duration perCard = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOutCubic,
    double w = 46, double h = 64,
  }) async {
    final fromRect = _rectOf(deckKey);
    final from = Rect.fromCenter(center: fromRect.center, width: w, height: h);
    for (final t in targets) {
      final toRect = _rectOf(t);
      final to = Rect.fromCenter(center: toRect.center, width: w, height: h);
      await _fly(
        context: context,
        vsync: vsync,
        from: from,
        to: to,
        duration: perCard,
        curve: curve,
        child: cardBuilder(),
      );
    }
  }

  static Future<void> drawFromDeck({
    required BuildContext context,
    required TickerProvider vsync,
    required GlobalKey deckKey,
    required GlobalKey handKey,
    required CardBuilder cardBuilder,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double w = 46, double h = 64,
  }) {
    final from = Rect.fromCenter(center: _rectOf(deckKey).center, width: w, height: h);
    final to = Rect.fromCenter(center: _rectOf(handKey).center, width: w, height: h);
    return _fly(context: context, vsync: vsync, from: from, to: to, duration: duration, curve: curve, child: cardBuilder());
  }

  static Future<void> playToTable({
    required BuildContext context,
    required TickerProvider vsync,
    required GlobalKey fromHandKey,
    required GlobalKey tableCenterKey,
    required CardBuilder cardBuilder,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOutCubic,
    double w = 46, double h = 64,
  }) {
    final from = Rect.fromCenter(center: _rectOf(fromHandKey).center, width: w, height: h);
    final to = Rect.fromCenter(center: _rectOf(tableCenterKey).center, width: w, height: h);
    return _fly(context: context, vsync: vsync, from: from, to: to, duration: duration, curve: curve, child: cardBuilder());
  }

  static Future<void> collectTrick({
    required BuildContext context,
    required TickerProvider vsync,
    required List<GlobalKey> tableCardKeys,
    required GlobalKey winnerPileKey,
    required CardBuilder cardBuilder,
    Duration perCard = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
    double w = 46, double h = 64,
  }) async {
    final to = Rect.fromCenter(center: _rectOf(winnerPileKey).center, width: w, height: h);
    for (final k in tableCardKeys) {
      final from = Rect.fromCenter(center: _rectOf(k).center, width: w, height: h);
      await _fly(
        context: context,
        vsync: vsync,
        from: from,
        to: to,
        duration: perCard,
        curve: curve,
        child: cardBuilder(),
        endOpacity: 0,
      );
    }
  }

  static Future<void> celebrateWinner({
    required BuildContext context,
    required TickerProvider vsync,
    required GlobalKey anchorKey,
    Duration duration = const Duration(milliseconds: 2000),
  }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final ctrl = AnimationController(vsync: vsync, duration: duration);
    final fade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
    final rect = _rectOf(anchorKey);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        ignoring: true,
        child: AnimatedBuilder(
          animation: fade,
          builder: (_, __) => CustomPaint(
            painter: _BurstPainter(center: rect.center, t: fade.value),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await ctrl.forward();
    entry.remove();
    ctrl.dispose();
  }
}

class _BurstPainter extends CustomPainter {
  final Offset center;
  final double t;
  _BurstPainter({required this.center, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.amber.withOpacity(1 - t);
    final r = 30 + 120 * t;
    canvas.drawCircle(center, r, p);
    for (int i = 0; i < 10; i++) {
      final angle = i * 36.0 * (math.pi / 180);
      final len = r * 0.7 * t;
      final dx = len * math.cos(angle);
      final dy = len * math.sin(angle);
      canvas.drawLine(center, center.translate(dx, dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t || old.center != center;
}
