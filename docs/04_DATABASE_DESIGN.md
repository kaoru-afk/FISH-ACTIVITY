# FISH ACTIVITY データベース設計書

- 文書版: 0.3
- DB: Supabase PostgreSQL
- 正本DDL: `database/001_initial_schema.sql`、`database/002_environment_collection.sql`

## 1. テーブル一覧

| テーブル | 用途 |
|---|---|
| fishing_spots | 釣り場マスター。座標精度・立入状況・情報源 |
| fish_species | 魚種マスターと生態プロフィール |
| data_collection_targets | 自動収集対象の釣り場・市町村周辺エリア |
| environment_snapshots | 気象・海況・潮汐等の予報/観測スナップショット |
| data_collection_runs | 定期収集ジョブの実行履歴・成否 |
| predictions | 魚種・釣り場・時刻別評価と根拠 |
| fishing_trips | 1回の釣行記録。ボウズも保存 |
| catch_records | 釣行に紐づく魚種・匹数・サイズ等 |
| spot_observations | 利用者による現場観察 |

## 2. 自動収集設計

### data_collection_targets
- 収集地点を釣り場単位（spot）または市町村・周辺海域単位（area）で管理する。
- `target_key`を一意キーとし、名称・都道府県・市町村・座標・座標精度を保持する。
- 初期取得間隔は60分。許可値は30/60/180/360/720/1440分。
- `data_categories`でweather / marine / tide等の収集対象を管理する。
- 釣り場単位の場合はfishing_spots.idを紐付ける。areaは代表座標と座標精度を保持する。
- 初期DDLでは対象地点を自動登録しない。座標・市町村・対象範囲を確認してから登録する。

### environment_snapshots
- 既存テーブルを拡張し、`collection_target_id`で収集対象と紐付ける。
- `forecast_for`はデータが対象とする時刻、`retrieved_at`は取得時刻。
- `record_type`はobservation / forecast / model_estimate / manual / unknownを区別する。
- `data_kind`はweather / marine / tide / current / baitfish / manual_observation。
- `payload`に値、`units`に単位、`quality`に品質・観測方式・欠損理由等をJSONBで保存する。
- providerとmodel_nameを必須/任意情報として保持し、出典を追跡可能にする。
- 予報は取得時点ごとの履歴を残す。後から新しい予報で上書きしない。
- observationは同一地点・対象時刻・データ種別・提供元の重複登録を防止する。

### data_collection_runs
- 定期ジョブごとの開始/終了時刻、提供元、成功/部分成功/失敗、登録/スキップ件数を保存する。
- エラー概要を保持し、API障害や欠測を追跡する。
- 秘密情報、APIキー、認証トークンはmetadataやerror_summaryに保存しない。

## 3. 取得間隔の初期方針

- 基本は1時間ごと。
- 30分ごとの取得は、提供元が30分以下の更新頻度で有用なデータを提供し、釣り場の短時間変化を捉える必要性が確認できた項目に限定する。
- 提供元の更新頻度より短い間隔で取得して同じ値を重複保存しない。
- 取得時刻と対象時刻を必ず分け、予報値・実測値・モデル推定値を混同しない。
- 水温・潮流などは提供元の観測密度と更新頻度に依存し、1時間ごとに新しい実測値が得られるとは限らない。

## 4. RLS・権限

| テーブル | 読取 | 書込 |
|---|---|---|
| fishing_spots / fish_species | 公開 | 管理処理 |
| data_collection_targets | 有効な対象のみ公開 | 信頼済みサーバー処理 |
| environment_snapshots | 認証済み | service_roleによるサーバー処理 |
| data_collection_runs | クライアント公開なし | service_roleによるサーバー処理 |
| predictions | 認証済み | サーバー処理方針を別途確定 |
| fishing_trips / catch_records / spot_observations | 所有者のみ | 所有者のみ |

RLSとGRANTは別の制御層。定期収集はEdge Function等の信頼できるサーバー側で実行し、service_roleキーをブラウザやGitHub Pagesへ絶対に置かない。

## 5. データ品質・分析上の原則

- 欠損値はNULLまたは明示的な欠損理由で表し、0で代用しない。
- 風速m/s、気温℃、水温℃、波高m、潮位cm等、値の単位を明示する。
- 実測・予報・モデル推定・利用者観察を区別する。
- 地点座標はexact / approximate / area_centerを区別する。
- 地点代表値と個別釣り場の実測値を同一視しない。
- 釣果ゼロの釣行（blank）と釣行中止（no_fishing）を区別する。
- 釣果だけでなく釣行時間・対象魚種・釣行の有無を集め、釣れた記録だけに偏ることを避ける。
- 予測精度の検証には、予測作成時点で利用可能だったデータのみを使用する。

## 6. 既知の検討事項

- 外部APIごとの利用規約、更新頻度、観測/予報の区別、帰属表示を確認する。
- 市町村周辺エリアと個別釣り場の代表座標・収集範囲を整備する。
- catch_records.user_idとfishing_trips.user_idの一致をDB側で保証する仕組みを検討する。
- 十分な蓄積後、釣行時間あたり釣果などの標準化指標と予測評価方法を設計する。

このDDL追加は、既存の釣行・釣果テーブルを削除・再作成しない追記型マイグレーションである。
