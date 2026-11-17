import 'package:flutter/material.dart';

import '../data/dummy_data.dart';

/// Tab 3 - the Pattern Library: 2-layer architecture explainer + 6 scam types.
/// Dark Emerald & Warm Gold design (Mockups 5-7).
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      children: [
        // 2-Layer Hybrid Architecture Explainer Card (Mockup 5)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0E3325),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1F4E3D)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How Our 2-Layer Shield Works',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC),
                  height: 1.2,
                ),
              ),
              SizedBox(height: 14),
              _LayerSubCard(
                badge: 'LAYER 1',
                icon: Icons.bolt_rounded,
                title: 'Instant offline rules',
                body:
                    'Spots urgency, fake authority, OTP traps and bad links in under a millisecond, even without internet.',
              ),
              SizedBox(height: 10),
              _LayerSubCard(
                badge: 'LAYER 2',
                icon: Icons.smart_toy_outlined,
                title: 'Hybrid AI classifier',
                body:
                    'Catches sneaky conversational scams like fake pension calls, while genuine bank OTPs stay at zero risk.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'The 6 scams hitting Indian families',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Learn their fingerprints. Spot the pattern, stop the scam.',
          style: TextStyle(
            fontSize: 18,
            height: 1.4,
            color: Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 14),
        for (final scam in scamTypes) _ScamTypeCard(scam: scam),
      ],
    );
  }
}

class _LayerSubCard extends StatelessWidget {
  final String badge;
  final IconData icon;
  final String title;
  final String body;

  const _LayerSubCard({
    required this.badge,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF092219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A3E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFE5B842)),
              const SizedBox(width: 6),
              Text(
                badge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFFE5B842),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScamTypeCard extends StatelessWidget {
  final ScamType scam;

  const _ScamTypeCard({required this.scam});

  @override
  Widget build(BuildContext context) {
    final numStr = scam.number.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D221B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F3D32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                numStr,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE5B842),
                  height: 1.05,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  scam.title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'THEY SAY',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFFF87171),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scam.example,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              fontStyle: FontStyle.italic,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'THEY WANT',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scam.wants,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'DO THIS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFF34D399),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scam.advice,
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }
}
