import 'dart:math' as math;

import 'package:flutter/material.dart';

/// L'orbe d'Aoussi — son visage, dans le vert de l'application.
///
/// Elle doit paraître VIVANTE, sans s'agiter :
///
/// - **elle respire** : elle gonfle et dégonfle à peine, lentement ;
/// - **la lumière tourne** : un reflet balaie sa surface, comme un liquide
///   qu'on regarde à travers le verre ;
/// - **elle rayonne** : un halo vert s'étend et se resserre avec le souffle.
///
/// Quand Aoussi réfléchit, tout s'accélère — souffle court, lumière qui
/// tourne vite, halo plus vif. On lit « il travaille » sans un mot ni un
/// sablier.
///
/// En petit (avatar de liste, à côté d'une réponse), seul le souffle reste :
/// une lumière qui tourne dans un rond de 28 points se voit à peine, et
/// coûte autant qu'en grand.
class AssistantOrb extends StatefulWidget {
  const AssistantOrb({super.key, this.size = 96, this.thinking = false});

  final double size;
  final bool thinking;

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

/// Le vert de l'application, de la lumière à l'ombre.
const _light = Color(0xFFE39A6B);
const _mid = Color(0xFF93491F);
const _brand = Color(0xFFA65527);
const _deep = Color(0xFF7A3A18);

class _AssistantOrbState extends State<AssistantOrb>
    with TickerProviderStateMixin {
  static const _breathRest = Duration(milliseconds: 3200);
  static const _breathThinking = Duration(milliseconds: 800);
  static const _spinRest = Duration(seconds: 9);
  static const _spinThinking = Duration(milliseconds: 1600);

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: widget.thinking ? _breathThinking : _breathRest,
  )..repeat(reverse: true);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.thinking ? _spinThinking : _spinRest,
  )..repeat();

  bool get _detailed => widget.size >= 56;

  @override
  void didUpdateWidget(AssistantOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thinking != widget.thinking) {
      _breath
        ..duration = widget.thinking ? _breathThinking : _breathRest
        ..reset()
        ..repeat(reverse: true);
      // La rotation garde sa position : seul son tempo change, sans saut.
      _spin
        ..duration = widget.thinking ? _spinThinking : _spinRest
        ..repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final thinking = widget.thinking;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _spin]),
        builder: (context, _) {
          final t = Curves.easeInOutSine.transform(_breath.value);
          final scale = 1 + (thinking ? 0.05 : 0.035) * (t - 0.5) * 2;
          final glow = (thinking ? 0.45 : 0.28) + (thinking ? 0.2 : 0.12) * t;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 1.1,
                  colors: [_light, _mid, _brand, _deep],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brand.withValues(alpha: glow),
                    blurRadius: size * (0.35 + 0.15 * t),
                    spreadRadius: size * 0.02 * t,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_detailed)
                      // La lumière qui tourne : un balayage clair, très
                      // doux, entraîné par la rotation.
                      Transform.rotate(
                        angle: _spin.value * 2 * math.pi,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: SweepGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(
                                  alpha: thinking ? 0.32 : 0.22,
                                ),
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.18, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    // Le reflet, qui monte et descend avec le souffle.
                    Align(
                      alignment: Alignment.lerp(
                        const Alignment(-0.35, -0.2),
                        const Alignment(-0.35, -0.6),
                        t,
                      )!,
                      child: Container(
                        width: size * 0.38,
                        height: size * 0.22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
