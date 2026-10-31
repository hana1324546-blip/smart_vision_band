import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state_providers.dart';
import '../../widgets/dashboard_metric_card.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    required this.app,
    required this.onOpenDevices,
    required this.onStartNavigation,
    super.key,
  });

  final AppController app;
  final VoidCallback onOpenDevices;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final distance = app.distance;
    final range = distance == null ? 0.0 : (1 - distance.cm / 400).clamp(0.0, 1.0);
    final band = app.connected ? strings.text('connected') : strings.text(app.reconnecting ? 'reconnecting' : 'disconnected');
    final battery = app.batteryPercent?.toStringAsFixed(0) ?? strings.text('notReported');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.text('goodMorning'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(strings.text('dashboardTitle'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.colorScheme.outlineVariant)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: range,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: distance != null && distance.cm < 60 ? const Color(0xffc2413b) : const Color(0xff138a75),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(distance?.cm.toStringAsFixed(0) ?? '—', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(strings.text('centimeters'), style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.text('nearestObstacle'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(distance == null ? strings.text('distanceUnavailable') : strings.text('rangeReading'), style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: app.connected ? onStartNavigation : onOpenDevices,
                        icon: Icon(app.connected ? Icons.navigation_outlined : Icons.bluetooth_searching),
                        label: Text(app.connected ? strings.text('startNavigation') : strings.text('connectBand')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: cardWidth, child: DashboardMetricCard(icon: Icons.bluetooth_connected, label: strings.text('bluetoothBand'), value: band, detail: app.receivingUltrasonic ? strings.text('receiving') : strings.text('notReceiving'), accent: const Color(0xff5264c8), onTap: onOpenDevices)),
                SizedBox(width: cardWidth, child: DashboardMetricCard(icon: Icons.videocam_outlined, label: strings.text('esp32Stream'), value: '${app.fps.toStringAsFixed(1)} ${strings.text('fpsUnit')}', detail: strings.text(app.cameraReady ? 'connected' : 'disconnected'), accent: const Color(0xff138a75), onTap: onOpenDevices)),
                SizedBox(width: cardWidth, child: DashboardMetricCard(icon: Icons.battery_5_bar, label: strings.text('battery'), value: '$battery%', detail: strings.text('stm32Battery'), accent: const Color(0xffc17722))),
                SizedBox(width: cardWidth, child: DashboardMetricCard(icon: Icons.center_focus_strong, label: strings.text('visibleObjects'), value: '${app.detections.length}', detail: app.cameraReady ? strings.text('latestDetections') : strings.text('sensorOnlyMode'), accent: const Color(0xffa1437b))),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          color: const Color(0xffe6f4f1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: const Icon(Icons.insights_outlined, color: Color(0xff126653)),
            title: Text(strings.text('systemInsight'), style: const TextStyle(color: Color(0xff123c34), fontWeight: FontWeight.w700)),
            subtitle: Text(app.cameraReady ? strings.text('cameraAndDistanceActive') : strings.text('distanceGuidanceActive'), style: const TextStyle(color: Color(0xff254f47))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xff123c34)),
            onTap: onOpenDevices,
          ),
        ),
        const SizedBox(height: 10),
        Text(strings.text('caneSafety'), style: theme.textTheme.bodySmall),
      ],
    );
  }
}