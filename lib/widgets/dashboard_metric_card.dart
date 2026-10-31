import 'package:flutter/material.dart';

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}