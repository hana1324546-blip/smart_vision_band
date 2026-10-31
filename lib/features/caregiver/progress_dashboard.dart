import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ProgressDashboard extends StatefulWidget {
  const ProgressDashboard({
    required this.bluetoothConnected,
    required this.streamReady,
    required this.receivingUltrasonic,
    required this.fps,
    required this.batteryPercent,
    super.key,
  });

  final bool bluetoothConnected;
  final bool streamReady;
  final bool receivingUltrasonic;
  final double fps;
  final double? batteryPercent;

  @override
  State<ProgressDashboard> createState() => _ProgressDashboardState();
}

class _ProgressDashboardState extends State<ProgressDashboard> {
  String _section = 'overview';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fpsProgress = (widget.fps / 18).clamp(0.0, 1.0);
    final batteryProgress = ((widget.batteryPercent ?? 0) / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.text('progressTitle'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(strings.text('progressSubtitle'), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'overview', label: Text(strings.text('overview'))),
            ButtonSegment(value: 'activity', label: Text(strings.text('activity'))),
            ButtonSegment(value: 'sensors', label: Text(strings.text('sensors'))),
          ],
          selected: {_section},
          onSelectionChanged: (selection) => setState(() => _section = selection.first),
        ),
        const SizedBox(height: 16),
        if (_section == 'overview') ...[
          _StatusRow(label: strings.text('bluetoothBand'), detail: strings.text(widget.bluetoothConnected ? 'connected' : 'disconnected'), value: widget.bluetoothConnected ? 1 : 0, color: const Color(0xff5264c8)),
          _StatusRow(label: strings.text('esp32Stream'), detail: '${widget.fps.toStringAsFixed(1)} ${strings.text('fpsUnit')}', value: widget.streamReady ? fpsProgress : 0, color: const Color(0xff138a75)),
          _StatusRow(label: strings.text('hardwareStatus'), detail: strings.text(widget.receivingUltrasonic ? 'receiving' : 'notReceiving'), value: widget.receivingUltrasonic ? 1 : 0, color: const Color(0xffbd6725)),
        ] else if (_section == 'activity') ...[
          ListTile(leading: const Icon(Icons.sensors), title: Text(strings.text('ultrasonic')), subtitle: Text(strings.text(widget.receivingUltrasonic ? 'receiving' : 'notReceiving'))),
          ListTile(leading: const Icon(Icons.center_focus_strong), title: Text(strings.text('cameraInference')), subtitle: Text(strings.text(widget.streamReady ? 'connected' : 'sensorOnlyMode'))),
        ] else ...[
          _StatusRow(label: strings.text('battery'), detail: widget.batteryPercent == null ? strings.text('notReported') : '${widget.batteryPercent!.round()}%', value: batteryProgress, color: const Color(0xffa1437b)),
          _StatusRow(label: strings.text('streamFps'), detail: '${widget.fps.toStringAsFixed(1)} / 18', value: fpsProgress, color: const Color(0xff138a75)),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.detail, required this.value, required this.color});

  final String label;
  final String detail;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))), Text(detail, style: theme.textTheme.labelLarge)]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(4), color: color, backgroundColor: theme.colorScheme.surfaceContainerHighest),
        ],
      ),
    );
  }
}