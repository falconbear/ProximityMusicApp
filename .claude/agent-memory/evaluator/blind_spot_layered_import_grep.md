---
name: blind_spot_layered_import_grep
description: 層分離契約の SC が grep で外部パッケージ (flutter/material 等) のみを禁止していると、内部 module 間の逆向き依存 (data→presentation 等) を見逃す
type: feedback
---

層分離 (clean architecture / hexagonal) を契約化する Issue では、Success criteria が `grep -RE "^import 'package:(flutter/material|go_router)" app/lib/data/` のように**外部パッケージ名**だけを禁止する形になりがち。これは Flutter / go_router など UI / routing ライブラリの侵入は防ぐが、**プロジェクト内部の Presentation layer を Data layer から import する逆向き依存は通過させる**。

Issue #1 で実際に発生: `app/lib/data/services/audio_service.dart` が `import 'package:proximity_music_app/presentation/state/providers.dart';` を持ち、SC #7/#8 の grep は通るが scope[3] の「Data は Domain のみ参照可」に明確違反。さらに providers.dart が audio_service.dart を import していたため**循環依存**化。

**Why:** 層分離の本質は依存方向の単方向化であり、「外部パッケージを import しないこと」は副次条件にすぎない。SC を grep ベースで書くと検査がカバーする範囲が狭くなる。

**How to apply:**
- 層分離 Issue の評価時は SC の grep を信用せず、必ず**プロジェクト内 import (`package:<this_project>/...`)** も含めて手動で grep し、依存方向グラフを目視で確認する。
- `grep -RE "^import 'package:<project>/" app/lib/data/` で Data 層の内部 import を全列挙し、`presentation/` を含むものが 0 件か検査する。
- 契約モードで層分離 SC を審査する時は、SC に「内部 import の単方向制約」も grep ベースで追加するよう拒否する (例: `grep -RE "^import 'package:<project>/presentation/" app/lib/data/ | wc -l == 0`)。
