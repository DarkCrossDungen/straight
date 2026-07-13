import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:straight/shared/theme/colors.dart';

class MicTestStep extends StatefulWidget {
  const MicTestStep({super.key});

  @override
  State<MicTestStep> createState() => _MicTestStepState();
}

class _MicTestStepState extends State<MicTestStep>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _tested = false;
  bool _success = false;
  double _audioLevel = 0.0;
  late AnimationController _animController;
  AudioRecorder? _recorder;
  Stream<Uint8List>? _stream;

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
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      _recorder = AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        setState(() {
          _tested = true;
          _success = false;
        });
        return;
      }

      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
      );

      try {
        _stream = await _recorder!.startStream(config);
        setState(() {
          _isRecording = true;
          _tested = false;
          _audioLevel = 0.0;
        });

        _stream?.listen((chunk) {
          if (!mounted) return;
          final samples = _convertToInt16(chunk);
          if (samples.isEmpty) return;

          double sum = 0;
          for (final sample in samples) {
            sum += sample.abs();
          }
          final avgLevel = sum / samples.length / 32768.0;
          setState(() {
            _audioLevel = avgLevel.clamp(0.0, 1.0);
          });
        });

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          await _stopRecording();
          setState(() {
            _tested = true;
            _success = _audioLevel > 0.005;
          });
        }
      } catch (e) {
        setState(() {
          _isRecording = false;
          _tested = true;
          _success = false;
        });
      }
    } else {
      await _stopRecording();
      setState(() {
        _tested = true;
        _success = _audioLevel > 0.005;
      });
    }
  }

  Future<void> _stopRecording() async {
    await _recorder?.stop();
    _isRecording = false;
  }

  List<int> _convertToInt16(Uint8List bytes) {
    final samples = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(((bytes[i + 1] << 8) | bytes[i]).toSigned(16));
    }
    return samples;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

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
              fontFamily: 'Space Mono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Speak to see if your microphone\nis working.',
            style: TextStyle(
              fontFamily: 'DM Sans',
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
                      fontFamily: 'Space Mono',
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
            if (_isRecording && _audioLevel > 0) {
              final phase = sin(
                (i / barCount) * pi * 2 + _animController.value * pi * 2,
              );
              return (_audioLevel * 2 * (0.5 + 0.5 * phase)).clamp(0.1, 1.0);
            }
            final phase = sin(
              (i / barCount) * pi * 2 + _animController.value * pi * 2,
            );
            return (_isRecording ? 0.5 + 0.5 * phase : 0.2 + 0.1 * sin(i * 2.5))
                .clamp(0.1, 1.0);
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
