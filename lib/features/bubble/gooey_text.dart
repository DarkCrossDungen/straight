import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GooeyText extends StatefulWidget {
  final List<String> texts;
  final double morphTime;
  final double cooldownTime;
  final TextStyle? style;

  const GooeyText({
    super.key,
    required this.texts,
    this.morphTime = 1.0,
    this.cooldownTime = 0.25,
    this.style,
  });

  @override
  State<GooeyText> createState() => _GooeyTextState();
}

class _GooeyTextState extends State<GooeyText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _currentIndex = 0;
  String _text1 = '';
  String _text2 = '';
  double _text1Blur = 0;
  double _text1Opacity = 1;
  double _text2Blur = 100;
  double _text2Opacity = 0;
  double _morph = 0;
  double _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _text1 = widget.texts.isNotEmpty ? widget.texts[0] : '';
    _text2 = widget.texts.length > 1 ? widget.texts[1] : '';
    _cooldown = widget.cooldownTime;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    const dt = 1 / 60;

    if (_cooldown > 0) {
      _cooldown -= dt;
      if (_cooldown <= 0) {
        _cooldown = 0;
        _currentIndex = (_currentIndex + 1) % widget.texts.length;
        _text1 = widget.texts[_currentIndex % widget.texts.length];
        _text2 = widget.texts[(_currentIndex + 1) % widget.texts.length];
        _morph = 0;
      } else {
        _morph = 0;
        _text2Blur = 0;
        _text2Opacity = 1;
        _text1Blur = 100;
        _text1Opacity = 0;
      }
    }

    if (_cooldown <= 0) {
      _morph += dt;
      final fraction = (_morph / widget.morphTime).clamp(0.0, 1.0);

      final blurIn = ((8.0 / math.max(fraction, 0.001) - 8.0).clamp(0.0, 100.0)).toDouble();
      final opacityIn = math.pow(fraction, 0.4).toDouble();

      final outFraction = 1 - fraction;
      final blurOut = ((8.0 / math.max(outFraction, 0.001) - 8.0).clamp(0.0, 100.0)).toDouble();
      final opacityOut = math.pow(outFraction, 0.4).toDouble();

      _text2Blur = blurIn;
      _text2Opacity = opacityIn;
      _text1Blur = blurOut;
      _text1Opacity = opacityOut;

      if (fraction >= 1) {
        _cooldown = widget.cooldownTime;
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontFamily: 'SF Mono',
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
      letterSpacing: 0,
    );
    final textStyle = widget.style ?? defaultStyle;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 255, -140,
      ]),
      child: SizedBox(
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _text1Opacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _text1Blur.clamp(0, 100),
                  sigmaY: _text1Blur.clamp(0, 100),
                ),
                child: Text(_text1, style: textStyle, textAlign: TextAlign.center),
              ),
            ),
            Opacity(
              opacity: _text2Opacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _text2Blur.clamp(0, 100),
                  sigmaY: _text2Blur.clamp(0, 100),
                ),
                child: Text(_text2, style: textStyle, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
