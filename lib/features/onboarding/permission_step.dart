import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:straight/shared/theme/colors.dart';

class PermissionStep extends StatefulWidget {
  const PermissionStep({super.key});

  @override
  State<PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<PermissionStep> {
  bool _granted = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final recorder = AudioRecorder();
      final hasPermission = await recorder.hasPermission();
      setState(() {
        _granted = hasPermission;
        _checking = false;
        if (!hasPermission) {
          _error =
              'Microphone permission denied. Please enable it in Windows Settings > Privacy > Microphone.';
        }
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _error = 'Could not check microphone permission: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _granted
                  ? AppColors.success
                  : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
              border: Border.all(color: fgColor, width: 1),
            ),
            child: _checking
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _granted ? Icons.check : Icons.mic,
                    size: 48,
                    color: _granted ? Colors.white : fgColor,
                  ),
          ),
          const SizedBox(height: 48),
          Text(
            'MICROPHONE ACCESS',
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
            'STRAIGHT needs microphone access to listen and\ntranscribe your voice.',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 14,
              color: fgColor.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_granted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.success, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'GRANTED',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else if (_error != null)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.error, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkPermission,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('TRY AGAIN'),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _checking ? null : _checkPermission,
              icon: const Icon(Icons.mic, size: 16),
              label: Text(_checking ? 'CHECKING...' : 'GRANT PERMISSION'),
            ),
        ],
      ),
    );
  }
}
