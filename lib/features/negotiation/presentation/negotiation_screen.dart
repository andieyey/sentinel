import 'package:flutter/material.dart';

class NegotiationScreen extends StatelessWidget {
  const NegotiationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Negotiation')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sentinel is rebalancing your timeline based on volatility and current priority mode.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
