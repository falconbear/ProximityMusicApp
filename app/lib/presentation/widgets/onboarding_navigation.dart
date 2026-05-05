// Presentation widget: OnboardingNavigation
//
// Reusable Back / Next / Skip button row used across the 4 onboarding pages.
// Intentionally Riverpod-free (the parent ConsumerWidget supplies callbacks).

import 'package:flutter/material.dart';

class OnboardingNavigation extends StatelessWidget {
  const OnboardingNavigation({
    super.key,
    this.onBack,
    this.onNext,
    this.onSkip,
    this.nextLabel = 'Next',
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onBack != null)
          TextButton(
            onPressed: onBack,
            child: const Text('戻る'),
          )
        else
          const SizedBox(width: 64),
        Row(
          children: [
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: const Text('スキップ'),
              ),
            const SizedBox(width: 8),
            if (onNext != null)
              ElevatedButton(
                onPressed: onNext,
                child: Text(nextLabel),
              ),
          ],
        ),
      ],
    );
  }
}
