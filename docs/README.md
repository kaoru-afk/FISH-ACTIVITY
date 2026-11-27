# FISH ACTIVITY ドキュメント

このフォルダは要件・仕様・設計・検証基準を管理する。

## 文書一覧
- [要件定義書](01_REQUIREMENTS.md)
- [機能仕様書](02_FUNCTIONAL_SPEC.md)
- [システム設計書](03_SYSTEM_DESIGN.md)
- [データベース設計書](04_DATABASE_DESIGN.md)
- [判定ロジック設計書](05_SCORING_DESIGN.md)
- [テスト仕様書](06_TEST_SPEC.md)

## DBマイグレーション
- [初期スキーマ](../database/001_initial_schema.sql)
- [自動環境データ収集用スキーマ](../database/002_environment_collection.sql)

## 2026-11-27 改訂（v0.3）
- 自動環境データ収集の対象地点テーブル `data_collection_targets` を追加。
- `environment_snapshots` に収集対象IDとデータ種別（実測/予報/推定/手動/不明）を追加。
- 定期収集処理の実行履歴 `data_collection_runs` を追加。
- 初期収集間隔を60分とし、データ提供元の更新頻度に応じて30分等へ調整する方針を明記。
- SQLマイグレーションは追加済み。Supabaseプロジェクトへの適用と定期収集処理は別途必要。

## 状態の表記
- 現状: ソースコードまたはSQLで確認できた内容。
- 未検証: 実装は確認できるが、公開環境での動作確認が未完了。
- 予定: 今後の実装候補。現行機能として扱わない。
- 要決定: 根拠や仕様が不足しており、確定が必要。

仕様と実装が食い違った場合は差分を記録し、意図的に仕様を改訂してから実装を変更する。
