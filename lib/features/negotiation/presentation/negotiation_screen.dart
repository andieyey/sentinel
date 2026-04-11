import 'package:flutter/material.dart';

import '../../../core/background/background_status.dart';

class NegotiationScreen extends StatelessWidget {
  const NegotiationScreen({super.key, this.event});

  final BackgroundRecalculationEvent? event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Negotiation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _buildNarrative(event),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.35),
          ),
        ),
      ),
    );
  }

  String _buildNarrative(BackgroundRecalculationEvent? event) {
    if (event == null) {
      return 'Sentinel is rebalancing your timeline based on volatility and current priority mode.';
    }

    final stationary = event.stationaryMinutes ?? 5;
    final delay = event.totalDayDelayMinutes ?? 0;
    final buffer = StringBuffer(
      'Stationary for ${stationary}m. Total day delay: ${delay}m.',
    );
    if (event.sleepAtRiskTime != null) {
      buffer.write(' Sleep at risk: ${_formatTime12h(event.sleepAtRiskTime)}.');
    }
    buffer.write(' Optimize?');
    return buffer.toString();
  }

  String _formatTime12h(DateTime? value) {
    if (value == null) {
      return 'unknown';
    }

    var hour = value.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute $suffix';
  }
}
