import 'dart:math';
import 'package:flutter/material.dart';
import 'package:straight/shared/theme/colors.dart';

class MicTestStep extends StatefulWidget {
  const MicTestStep({super.key});

  @override
  State<MicTestStep> createState() => _MicTestStepState();
}

class _MicTestStepState extends State<MicTestStep> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _tested = false;
  bool _success = false;
  late AnimationController _animController;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (!_isRecording) {
      setState(() {
        _isRecording = true;
        _tested = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _tested = true;
            _success = _random.nextBool();
          });
        }
      });
    } else {
      setState(() {
        _isRecording = false;
        _tested = true;
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _isRecording
                  ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                  : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
              border: Border.all(color: fgColor, width: 1),
            ),
            child: Icon(
              _isRecording ? Icons.volume_up : Icons.mic,
              size: 48,
              color: _isRecording
                  ? (isDark ? AppColors.darkFg : AppColors.lightFg)
                  : fgColor,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'TEST MICROPHONE',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Speak to see if your microphone\nis working.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: fgColor.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildWaveform(isDark),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _toggleRecording,
            icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 16),
            label: Text(_isRecording ? 'STOP' : 'START TEST'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? AppColors.error : primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_tested)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _success ? AppColors.success : AppColors.error,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _success ? Icons.check : Icons.close,
                    color: _success ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _success ? 'MICROPHONE WORKING' : 'MICROPHONE NOT DETECTED',
                    style: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _success ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveform(bool isDark) {
    const barCount = 7;

    return SizedBox(
      height: 80,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final currentHeights = List.generate(barCount, (i) {
            final phase = sin((i / barCount) * pi * 2 + _animController.value * pi * 2);
            return (_isRecording ? 0.5 + 0.5 * phase : 0.2 + 0.1 * sin(i * 2.5)).clamp(0.1, 1.0);
          });

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final barColor = _isRecording
                  ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                  : (isDark ? AppColors.darkMutedFg : AppColors.lightMutedFg);
              return Container(
                width: 6,
                height: 80 * currentHeights[i],
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: barColor,
              );
            }),
          );
        },
      ),
    );
  }
}
