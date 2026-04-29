// Presentation page: ConsentPage (onboarding step 4 of 4).
//
// Two display modes:
//
// 1) Normal mode (`needsReconsent == false`): full 4-step onboarding tail.
//    Shows the consent body in a SingleChildScrollView, a 「同意する」
//    checkbox, and a 「同意して続行」 ElevatedButton that is disabled until
//    the box is ticked. 「戻る」 / 「スキップ」 navigation is also visible.
//
// 2) Reconsent mode (`needsReconsent == true` because the persisted
//    acceptedVersion is older than [currentTermsVersion]): shows only two
//    actions — 「同意する」 and 「アプリを終了」. The router redirects all
//    other paths back to /onboarding/consent (stuck redirect, spec feature
//    13 acceptance criterion 5). 「アプリを終了」 invokes
//    `SystemNavigator.pop()` from `package:flutter/services.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';
import 'package:proximity_music_app/presentation/widgets/onboarding_navigation.dart';

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    // Reconsent mode is *only* triggered when a previous consent record
    // exists but its acceptedVersion is older than the current terms.
    // First-time onboarding (consent == null) renders the normal mode with
    // a 「同意して続行」 button so the user can complete the 4-step flow.
    final state = ref.watch(onboardingStateProvider);
    final consent = state.consent;
    final reconsentMode =
        consent != null && consent.acceptedVersion != currentTermsVersion;

    return Scaffold(
      appBar: AppBar(
        title: Text(reconsentMode ? '利用規約の更新' : '利用規約 / プライバシー'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reconsentMode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '利用規約が更新されました。続行するには再度ご同意ください。',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'アプリ利用規約',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        // Lorem-ipsum-相当の placeholder 本文 (Sprint 02 では
                        // 法務確定前のため正式テキストは未掲載).
                        '本利用規約は ProximityMusic の利用条件を定めるもので、'
                        'アプリのインストールおよび利用をもって全条項に同意'
                        'いただいたものとみなされます。\n\n'
                        '1. 共有可能な楽曲は権利クリアなものに限定されます。\n'
                        '2. 近接検知機能は Bluetooth および位置情報を使用'
                        'する場合があります。\n'
                        '3. 規約は予告なく更新されることがあります。更新時'
                        'には再同意を求めます。',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'プライバシーポリシー',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '当アプリはユーザーの近接情報を一時的に処理しますが、'
                        '長期保存や第三者提供は行いません。詳細は別途公開する'
                        '正式版プライバシーポリシーをご参照ください。',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                  const Text(
                    '同意する',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (reconsentMode)
                _ReconsentActions(
                  agreed: _agreed,
                  onAgree: () async {
                    await ref
                        .read(onboardingServiceProvider)
                        .recordConsent(currentTermsVersion);
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                )
              else
                _NormalActions(
                  agreed: _agreed,
                  onContinue: () async {
                    final s = ref.read(onboardingServiceProvider);
                    await s.recordConsent(currentTermsVersion);
                    await s.complete();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                  onBack: () => context.go('/onboarding/permissions'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NormalActions extends StatelessWidget {
  const _NormalActions({
    required this.agreed,
    required this.onContinue,
    required this.onBack,
  });

  final bool agreed;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: agreed ? onContinue : null,
            child: const Text('同意して続行'),
          ),
        ),
        const SizedBox(height: 8),
        OnboardingNavigation(onBack: onBack),
      ],
    );
  }
}

class _ReconsentActions extends StatelessWidget {
  const _ReconsentActions({
    required this.agreed,
    required this.onAgree,
  });

  final bool agreed;
  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: () => SystemNavigator.pop(),
          child: const Text('アプリを終了'),
        ),
        ElevatedButton(
          onPressed: agreed ? onAgree : null,
          child: const Text('同意する'),
        ),
      ],
    );
  }
}
