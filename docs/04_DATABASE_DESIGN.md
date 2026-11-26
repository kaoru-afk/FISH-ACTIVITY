# FISH ACTIVITY データベース設計書

- 文書版: 0.2
- 根拠: database/001_initial_schema.sql
- DB: Supabase PostgreSQL

## 2026-11-26 改訂
今回の変更はフロントエンド内の算出・表示責務の分離であり、DBテーブル・カラム・RLS・GRANTの変更は行っていない。将来 predictions に環境適合度と魚種別活動期待度を保存する場合は、DDLと本書を同時に改訂する。

## テーブル一覧
| テーブル | 用途 |
|---|---|
| fishing_spots | 釣り場マスター。座標精度・立入状況・情報源を保持 |
| fish_species | 魚種マスターと生態プロフィール・確度 |
| environment_snapshots | 予報・海況等の時点スナップショット |
| predictions | 魚種・釣り場・時刻別評価、内訳、欠損、アルゴリズム版 |
| fishing_trips | 1回の釣行記録 |
| catch_records | 釣行に紐づく釣果イベント |
| spot_observations | 現場観察 |

## 設計上の重要事項
- UUIDを主キーとする。
- 釣り場・魚種はspot_key/species_keyを一意キーとして持つ。
- 環境スナップショットはforecast_for（対象時刻）とretrieved_at（取得時刻）を分ける。
- data_kindはweather / marine / tide / current / baitfish / manual_observation。
- payload, units, qualityはJSONBで保持する。
- 予測はalgorithm_version、components、missing_factors、参照スナップショットIDを保持する。
- 釣行結果はcaught / blank / no_fishing / unknownを区別する。
- 釣果は釣行に紐づけ、魚種・時刻・サイズ・重量・数量等を記録する。
- 現場観察は予報データとは別テーブルに保存する。

## RLS方針（SQL定義）
| テーブル | 読取 | 書込 |
|---|---|---|
| fishing_spots | 公開 | 現行ポリシーでは公開書込なし |
| fish_species | 公開 | 現行ポリシーでは公開書込なし |
| environment_snapshots | 認証済み | 現行ポリシーでは書込ポリシーなし |
| predictions | 認証済み | 現行ポリシーでは書込ポリシーなし |
| fishing_trips | 所有者のみ | 所有者のみ |
| catch_records | 所有者のみ | 所有者のみ |
| spot_observations | 所有者のみ | 所有者のみ |

RLSポリシーとSQL GRANTは別の制御層。実際のアクセス可否は両方とSupabase設定を確認する。

## データ品質
- 欠損値はNULLまたは明示的な欠損情報で表す。0で代用しない。
- 数値は単位を記録し、変換前後の意味を明確にする。
- 予報の取得時刻と対象時刻を保持する。
- 予報値を上書きせず、取得時点ごとの履歴として保存する。
- 緯度経度は座標精度（exact / approximate / area_center）を保持する。
- 釣り場の立入状況はverified_open / restricted / prohibited / unverifiedを区別する。
- 魚種プロフィールにはprofile_confidenceと出典情報を保持する。

## 現行スキーマの注意点
- predictions.score_typeにcatch_probabilityがあるが、校正済み確率モデルがない限り使用しない。
- fishing_trips.weather_snapshot_idと複数環境要素の関連付け方式を今後整理する。
- catch_records.user_idとfishing_trips.user_idの一致をDB側でも保証する仕組みを検討する。
- spot_observationsの所有者・釣り場・観察値の整合性検証を検討する。
- 環境/予測データの書込権限はサーバー処理導入前に慎重に設計する。

正本DDLはdatabase/001_initial_schema.sql。本書とDDLを変更した場合は両方を更新する。