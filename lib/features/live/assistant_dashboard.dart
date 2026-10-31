import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/detection.dart';

class AssistantDashboard extends StatelessWidget {
  const AssistantDashboard({
    required this.isListening,
    required this.distanceLabel,
    required this.detections,
    required this.onListen,
    super.key,
  });

  final bool isListening;
  final String distanceLabel;
  final List<Detection> detections;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(strings.text('assistantTitle'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(strings.text('assistantSubtitle'), style: theme.textTheme.bodyMedium)),
        const SizedBox(height: 28),
        Container(
          width: 172,
          height: 172,
          decoration: BoxDecoration(
            color: isListening ? const Color(0xfffce9df) : const Color(0xffedf0fc),
            borderRadius: BorderRadius.circular(86),
            border: Border.all(color: isListening ? const Color(0xffb9462f) : const Color(0xff4a59ae), width: 2),
          ),
          child: Icon(isListening ? Icons.graphic_eq : Icons.mic_none, size: 64, color: isListening ? const Color(0xff8e2f20) : const Color(0xff303e91)),
        ),
        const SizedBox(height: 20),
        Text(strings.text(isListening ? 'listening' : 'assistantPrompt'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(strings.text('assistantCommandHint'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        Text(distanceLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        GestureDetector(
          onLongPress: isListening ? null : onListen,
          child: FilledButton.icon(onPressed: isListening ? null : onListen, icon: const Icon(Icons.mic), label: Text(strings.text(isListening ? 'listening' : 'listenNow'))),
        ),
        const SizedBox(height: 22),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(strings.text('latestDetections'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        if (detections.isEmpty)
          Align(alignment: AlignmentDirectional.centerStart, child: Text(strings.text('noObjectsDetected'), style: theme.textTheme.bodyMedium))
        else
          Wrap(spacing: 8, runSpacing: 8, children: detections.take(8).map((detection) => Chip(label: Text('${detection.label} · ${(detection.confidence * 100).round()}%'))).toList()),
      ],
    );
  }
}