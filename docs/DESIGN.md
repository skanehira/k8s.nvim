# k8s.nvim 設計ドキュメント

生成日: 2025-12-30
ジェネレーター: analyzing-requirements

## システム概要

k8s.nvimは、Neovim内でKubernetesクラスタを管理するためのLuaプラグインである。k9sのようなターミナルUIの操作感をNeovimに持ち込み、コード編集とクラスタ管理をシームレスに行えることを目的とする。

### 解決する問題
- Neovimとターミナル（k9s/kubectl）間の頻繁なコンテキストスイッチ
- kubectlコマンドの冗長な入力
- クラスタ状態の視覚的な把握の困難さ

### 対象ユーザー
- Neovimを日常的に使用するKubernetesエンジニア/SRE
- k9sに慣れているがNeovim内で完結したいユーザー

### ビジネス価値
- 開発・運用効率の向上
- コンテキストスイッチによる認知負荷の軽減

## UI/UX設計

### レイアウト構成

専用タブ内でシングルペインのドリルダウン型UIを採用する（k9s風）。

```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │ ← ヘッダー
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│  nginx-abc123      1/1     Running   0          5m              │
│> redis-def456      1/1     Running   0          2m    ← カーソル │
│  mysql-ghi789      0/1     Pending   0          10m             │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ <CR> Select  d Describe  l Logs  e Exec  D Delete  ? Help       │ ← フッター
└─────────────────────────────────────────────────────────────────┘
```

- **シングルペイン**: 画面全体を使用、バッファ内容が切り替わる
- **ヘッダー**: コンテキスト、ネームスペース、現在のビュー名を常時表示
- **フッター**: 利用可能なキーマップのヒント表示

### ナビゲーションモデル

**ドリルダウン型**を採用。同じバッファ内でビューが切り替わり、`<Esc>`で前の階層に戻る。

```
リソース一覧
    ↓ <CR> (選択) または d (describe)
Pod詳細（describe表示）
    ↓ <Esc>
リソース一覧に戻る

※ <Esc>で上の階層に戻る
※ q で k8s.nvim を閉じる
```

**ログ/exec は別タブで開く**:
```
リソース一覧で l (ログ) または e (exec) を押す
    ↓
コンテナ選択メニュー（複数コンテナ時）
    ↓ <CR>
新規タブでターミナルが開く（k8s.nvimタブはそのまま残る）
```

### 各ビューの説明

| ビュー | 内容 | 操作 |
|--------|------|------|
| リソース一覧 | テーブル形式でリソース表示 | j/k移動、Enter選択 |
| describe | kubectl describe出力 | スクロール、検索 |
| ログ | **別タブ**でkubectl logs -f | ターミナルモード操作 |
| exec | **別タブ**でkubectl exec | ターミナルモード操作 |
| コンテナ選択 | メニュー形式 | j/k移動、Enter選択 |

**ログ/exec の別タブ動作**:
- 各Pod/コンテナのログ・execは新規タブで開く
- 複数Podのログを同時に表示可能
- タブ名: `[logs] pod-name` / `[exec] pod-name`
- タブを閉じると該当プロセスも終了

### UI図一覧

#### describe画面（dキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pod: nginx-abc123]    │ ← ヘッダー
├─────────────────────────────────────────────────────────────────┤
│ Name:         nginx-abc123                                      │
│ Namespace:    default                                           │
│ Priority:     0                                                 │
│ Node:         minikube/192.168.49.2                             │
│ Start Time:   Mon, 30 Dec 2024 10:00:00 +0900                   │
│ Labels:       app=nginx                                         │
│ ...                                                             │
├─────────────────────────────────────────────────────────────────┤
│ <Esc> Back  l Logs  e Exec  D Delete                            │ ← フッター
└─────────────────────────────────────────────────────────────────┘
```

#### フィルター入力中（/キー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods] Filter: nginx   │ ← フィルター文字列表示
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│> nginx-abc123      1/1     Running   0          5m              │
│  nginx-def456      1/1     Running   0          3m              │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ <CR> Select  d Describe  l Logs  e Exec  D Delete  ? Help       │
└─────────────────────────────────────────────────────────────────┘
/nginx_                                                    ← コマンドライン入力
```

#### リソースタイプ選択メニュー（Rキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────┐│                   │
│  NAME          ...   ││ Select Resource    ││                   │
│  nginx-abc123  ...   ││────────────────────││                   │
│  redis-def456  ...   ││> Pods              ││                   │
│  mysql-ghi789  ...   ││  Deployments       ││                   │
│                      ││  Services          ││                   │
│                      ││  ConfigMaps        ││                   │
│                      ││  Secrets           ││                   │
│                      ││  Nodes             ││                   │
│                      │└────────────────────┘│                   │
├──────────────────────┴──────────────────────────────────────────┤
│ j/k Move  <CR> Select  <Esc> Cancel                             │
└─────────────────────────────────────────────────────────────────┘
```

#### コンテキスト選択メニュー（Cキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────┐│                   │
│  NAME          ...   ││ Select Context     ││                   │
│  nginx-abc123  ...   ││────────────────────││                   │
│  redis-def456  ...   ││> minikube          ││                   │
│  mysql-ghi789  ...   ││  docker-desktop    ││                   │
│                      ││  production        ││                   │
│                      │└────────────────────┘│                   │
├──────────────────────┴──────────────────────────────────────────┤
│ j/k Move  <CR> Select  <Esc> Cancel                             │
└─────────────────────────────────────────────────────────────────┘
```

#### ネームスペース選択メニュー（Nキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────┐│                   │
│  NAME          ...   ││ Select Namespace   ││                   │
│  nginx-abc123  ...   ││────────────────────││                   │
│  redis-def456  ...   ││> All Namespaces    ││ ← 先頭に配置      │
│  mysql-ghi789  ...   ││  default           ││                   │
│                      ││  kube-system       ││                   │
│                      ││  monitoring        ││                   │
│                      │└────────────────────┘│                   │
├──────────────────────┴──────────────────────────────────────────┤
│ j/k Move  <CR> Select  <Esc> Cancel                             │
└─────────────────────────────────────────────────────────────────┘
```

#### コンテナ選択メニュー（複数コンテナ時）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────┐│                   │
│  NAME          ...   ││ Select Container   ││                   │
│  nginx-abc123  ...   ││────────────────────││                   │
│> app-pod       ...   ││> app               ││                   │
│  mysql-ghi789  ...   ││  sidecar           ││                   │
│                      ││  init-container    ││                   │
│                      │└────────────────────┘│                   │
├──────────────────────┴──────────────────────────────────────────┤
│ j/k Move  <CR> Select  <Esc> Cancel                             │
└─────────────────────────────────────────────────────────────────┘
```

#### ポートフォワード一覧（Fキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Port Forwards]                             │ ← ヘッダー
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LOCAL    REMOTE    RESOURCE              STATUS                │
│> 8080     80        pod/nginx-abc123      Running               │
│  3000     3000      svc/frontend          Running               │
│  5432     5432      pod/postgres-xyz      Running               │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ D Stop  <Esc> Back                                              │ ← フッター
└─────────────────────────────────────────────────────────────────┘
```

#### 入力ダイアログ（ポート番号入力）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────────────┐│           │
│  NAME          ...   ││ Local Port                 ││           │
│  nginx-abc123  ...   ││────────────────────────────││           │
│> redis-def456  ...   ││ 8080_                      ││           │
│  mysql-ghi789  ...   │└────────────────────────────┘│           │
│                      │                              │           │
├──────────────────────┴──────────────────────────────────────────┤
│ <CR> Confirm  <Esc> Cancel                                      │
└─────────────────────────────────────────────────────────────────┘
```

#### スケーリング入力ダイアログ（sキー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Deployments]          │
├──────────────────────┬──────────────────────────────────────────┤
│                      │┌────────────────────────────┐│           │
│  NAME          ...   ││ Replicas (current: 3)      ││           │
│  nginx-deploy  ...   ││────────────────────────────││           │
│> redis-deploy  ...   ││ 5_                         ││           │
│  mysql-deploy  ...   │└────────────────────────────┘│           │
│                      │                              │           │
├──────────────────────┴──────────────────────────────────────────┤
│ <CR> Confirm  <Esc> Cancel                                      │
└─────────────────────────────────────────────────────────────────┘
```

#### 確認ダイアログ（削除時）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│  nginx-abc123      1/1     Running   0          5m              │
│> redis-def456      1/1     Running   0          2m              │
│  mysql-ghi789      0/1     Pending   0          10m             │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ <CR> Select  d Describe  l Logs  e Exec  D Delete  ? Help       │
└─────────────────────────────────────────────────────────────────┘
Delete pod/redis-def456? [y]es, [N]o:                      ← vim.fn.confirm
```

#### ヘルプ表示（?キー）
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods]                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│  nginx-abc123      1/1     Running   0          5m              │
│> redis-def456      1/1     Running   0          2m              │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ Keymaps:                                                        │ ← 拡張フッター
│ <CR> Select    d Describe   l Logs      e Exec      p PortFwd   │
│ D Delete       s Scale      X Restart   r Refresh               │
│ / Filter       R Resources  C Context   N Namespace S Secret    │
│ F PortFwdList  P PrevLogs   ? Help      q Quit      <Esc> Back  │
│                                                                 │
│ Press any key to close help...                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### ログ表示（別タブ）
```
┌─────────────────────────────────────────────────────────────────┐
│ [k8s.nvim] [logs] nginx-abc123                     ← タブライン │
├─────────────────────────────────────────────────────────────────┤
│ 2024-12-30T10:00:00.000Z Starting nginx...                      │
│ 2024-12-30T10:00:01.000Z Listening on port 80                   │
│ 2024-12-30T10:00:05.000Z GET / 200 0.001s                       │
│ 2024-12-30T10:00:10.000Z GET /health 200 0.000s                 │
│ 2024-12-30T10:00:15.000Z GET /api/users 200 0.023s              │
│ _                                                  ← ターミナル │
└─────────────────────────────────────────────────────────────────┘
```

#### exec表示（別タブ）
```
┌─────────────────────────────────────────────────────────────────┐
│ [k8s.nvim] [exec] nginx-abc123                     ← タブライン │
├─────────────────────────────────────────────────────────────────┤
│ root@nginx-abc123:/# ls -la                                     │
│ total 80                                                        │
│ drwxr-xr-x   1 root root 4096 Dec 30 10:00 .                    │
│ drwxr-xr-x   1 root root 4096 Dec 30 10:00 ..                   │
│ drwxr-xr-x   2 root root 4096 Dec 30 09:00 bin                  │
│ root@nginx-abc123:/# _                             ← ターミナル │
└─────────────────────────────────────────────────────────────────┘
```

#### Loading中の表示
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: default] [Pods] Loading...      │ ← インジケーター
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│  nginx-abc123      1/1     Running   0          5m              │
│> redis-def456      1/1     Running   0          2m              │
│  mysql-ghi789      0/1     Pending   0          10m             │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ <CR> Select  d Describe  l Logs  e Exec  D Delete  ? Help       │
└─────────────────────────────────────────────────────────────────┘
```

#### リソース0件の表示
```
┌─────────────────────────────────────────────────────────────────┐
│ [Context: minikube] [Namespace: monitoring] [Pods]              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAME              READY   STATUS    RESTARTS   AGE             │
│                                                                 │
│                                                                 │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ <CR> Select  d Describe  l Logs  e Exec  D Delete  ? Help       │
└─────────────────────────────────────────────────────────────────┘
```

### ステータス表示

リソース一覧のステータス列は色分けする：
- **緑** (`K8sStatusRunning`): Running, Completed, Active, Ready
- **黄** (`K8sStatusPending`): Pending, Waiting, ContainerCreating
- **赤** (`K8sStatusError`): Error, Failed, CrashLoopBackOff, Terminating

### リソースタイプ切り替え

2つの方法をサポート：
1. **コマンド**: `:K8s pods`, `:K8s deployments` など
2. **メニューUI**: キー操作（`R`）でフローティングメニューを中央に表示

### ヘルプ表示

- `?`キーでフッターを一時的に拡張してキーマップ一覧を表示
- 任意のキー押下でヘルプを閉じる

### UI実装詳細

#### レイアウト構成
- **3ウィンドウ構成**: NuiPopupで3つのウィンドウを作成
  - ヘッダーウィンドウ（上部固定）
  - コンテンツウィンドウ（中央、スクロール可能）
  - フッターウィンドウ（下部固定）
- **全画面表示**: タブラインを隠さないサイズで配置
- **ビュー切り替え時**: 3ウィンドウすべての内容を更新（ヘッダー・フッターも画面に応じて変化）

#### 描画方式
- **テーブル描画**: `NuiLine`/`NuiText`を使用してハイライト付きテキストを構築
- **バッファ管理**: 同じバッファを再利用して内容を書き換え

#### UI部品の実装
| 部品 | 実装方法 |
|------|---------|
| メニュー（リソース選択等） | telescope.nvimがあれば使用、なければNuiMenu |
| 確認ダイアログ | `vim.fn.confirm` |
| 入力ダイアログ | `NuiInput` |
| フィルター入力 | コマンドライン（`vim.fn.input`相当） |

#### 操作方式
- **キーボードのみ**: マウス操作は非サポート
- **vim.ui.select**: カスタマイズ（dressing.nvim等）に自動対応

## 機能要件

### 必須機能（MUST have）

#### 1. リソース一覧表示
- Pods, Deployments, Services, ConfigMaps, Secrets, Nodes, Namespaces の一覧表示
- カラム: NAME, NAMESPACE, STATUS, AGE, その他リソース固有情報（リソースタイプごとに固定）
- **ソート**: NAME順（アルファベット順）で固定、変更機能なし
- **フィルタリング**: インクリメンタル検索（`/`キーで起動、入力に応じてリアルタイム絞り込み）
  - `ESC`で検索モード終了（フィルター結果は維持）
  - 再度`/`で空入力するとフィルターをクリア
  - **フィルター表示**: ヘッダーに現在のフィルター文字列を表示
- **初期表示リソース**: Pods（起動時のデフォルト）

#### 2. リソース詳細表示（describe）
- `kubectl describe`相当の詳細情報表示
- **シンタックスハイライト**: `filetype=yaml`を設定して標準ハイライトを使用
- イベント履歴の表示
- **手動更新**: 非対応（一覧に戻って再選択）

#### 3. ログ表示
- Pod/Containerのログストリーミング表示
- **表示方式**: 新規タブを開きターミナルモードで`kubectl logs -f`を実行
- **複数Pod対応**: 複数Podのログを同時に別タブで表示可能
- **複数コンテナ時**: 選択メニューを表示してコンテナを選択
- フォロー（tail -f相当）モード（デフォルトで有効）
- **タイムスタンプ**: 常に表示（`--timestamps`オプション付き）
- **前のコンテナのログ**: `P`キーで`kubectl logs -p`を実行（再起動前のログ）
- タブを閉じるとログプロセスも終了

#### 4. コンテナexec
- 選択したPodのコンテナにシェル接続
- **表示方式**: 新規タブを開きターミナルモードで`kubectl exec`を実行
- **複数Pod対応**: 複数Podに同時接続可能（別タブ）
- **シェル選択**: `sh -c "[ -e /bin/bash ] && bash || sh"`で自動判定
- 複数コンテナ時のコンテナ選択UI
- タブを閉じるとexecセッションも終了
- **コンテナ終了時**: exitでシェルが終了した場合、タブを自動的に閉じる

#### 5. ポートフォワード
- 選択したPod/Serviceへのポートフォワード開始
- **ローカルポート指定**: 入力ダイアログでポート番号を指定
- **リモートポート**: Podのコンテナポートから自動検出（複数あれば選択）
- **一覧表示**: `F`キーで専用ビューを開きアクティブなポートフォワードを表示
- ポートフォワード停止機能（一覧画面から`D`キーで停止）
- **成功通知**: `Port forwarding started: localhost:8080 -> pod:80`のように表示
- **ライフサイクル**:
  - k8s.nvimタブを閉じた時: ポートフォワードはそのまま継続
  - Neovim終了時: 全ポートフォワード停止（クリーンアップ）

#### 6. リソース操作
- リソース削除（**Yes/No確認ダイアログ**付き）
- **スケーリング**: 入力ダイアログでレプリカ数を指定（Deployment/ReplicaSet）
- **Rollout restart**: Yes/No確認ダイアログ付き
- **操作後の更新**: 操作完了後すぐに一覧を再取得

#### 7. コンテキスト/ネームスペース切り替え
- kubeconfigコンテキスト一覧・切り替え
- ネームスペース一覧・切り替え
- 現在のコンテキスト/ネームスペース表示（ヘッダーに常時表示）
- **デフォルトネームスペース**: `default`
- **切り替えUI**: メニューUI（`C`キーでコンテキスト、`N`キーでネームスペース選択）
- **All Namespaces**: `N`キーメニューの先頭に「All Namespaces」オプションを表示
- **切り替え後**: 自動的に新しいコンテキスト/ネームスペースのリソースを取得・表示
- **カーソル位置**: 切り替え時は先頭行にリセット

#### 8. 自動更新
- 5秒間隔でのバックグラウンド自動更新
- **更新中のインジケーター**: ヘッダーに「Loading...」やスピナーを表示
- 手動更新トリガー（`r`キー）
- **更新時のカーソル保持**: 行番号で保持（同じ行にカーソルを維持）
- **ユーザー操作中**: 操作中でも即座に更新（カーソルは行番号で復元）
- **削除されたリソース**: 次回更新時に自動的に一覧から消去

### オプション機能（NICE to have）
- CRD（Custom Resource Definition）対応
- Helm release管理
- リソースのWatch API対応（リアルタイム更新）
- 複数クラスタ同時表示
- リソース使用量メトリクス表示（top相当）

## 非機能要件

### パフォーマンス要件
- 初回起動時間: 100ms以下（遅延読み込み活用）
- リソース一覧表示: 500ms以下（100リソースまで）
- UI操作レスポンス: 50ms以下

### セキュリティ要件
- kubeconfigの直接読み取りは行わない（kubectlに委譲）
- シークレット値のマスク表示オプション
- 削除操作時の確認ダイアログ必須

### 保守性基準
- LuaCATS型注釈による型安全性
- モジュール分離による単一責任原則の遵守
- 80%以上のテストカバレッジ

## アーキテクチャ設計

### ドメインモデル

```
ドメインモデル
├── Cluster (Context)
│   └── Namespace
│       └── Resource (Pod, Deployment, etc.)
│           ├── データ (name, status, age, etc.)
│           └── メタ情報 (対応操作、カラム定義)
│
├── Actions (操作、別モジュール)
│   ├── 参照系: list, describe
│   ├── 変更系: delete, scale, restart
│   └── 接続系: logs, exec, port-forward (ストリーム)
│
├── State (状態管理)
│   ├── Scope (現在のContext/Namespace) + ResourceCache
│   └── Connections (アクティブな接続、Scopeから独立)
│
└── Ports (外部インターフェース、LuaCATSで定義)
    └── KubectlPort (参照/変更/接続のIF、実装はkubectl)
```

### レイヤー構成

```
┌─────────────────────────────────────────────────────────────┐
│                       UI層                                  │
│  Views, Components (nui.nvim)                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ 呼び出す
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 api.lua (ファサード)                        │
│  UI向け統一API。内部の依存関係を隠蔽                         │
└─────────────────────┬───────────────────────────────────────┘
                      │ 利用する
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    ドメイン層                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │  Resources  │ │   Actions   │ │    State    │           │
│  │ (Pod等定義) │ │ (操作実行)  │ │  (状態管理) │           │
│  └─────────────┘ └──────┬──────┘ └─────────────┘           │
│                         │ 依存                              │
│                         ▼                                   │
│                  ┌─────────────┐                           │
│                  │    Ports    │ ← インターフェース定義      │
│                  │ (KubectlPort)│                           │
│                  └─────────────┘                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ 実装する
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    インフラ層                               │
│  ┌─────────────┐                                           │
│  │   Kubectl   │ アダプタ: KubectlPortの実装               │
│  │   Adapter   │ (vim.system経由でkubectl実行)              │
│  └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

### 技術スタック

| カテゴリ | 技術 | 理由 |
|---------|------|------|
| 言語 | Lua 5.1 (LuaJIT) | Neovim標準 |
| UIライブラリ | nui.nvim | Popup/Menu/Input/Line/Textを使用 |
| 非同期処理 | vim.system / vim.uv | Neovim 0.10+標準API |
| テスト | plenary.nvim (busted) | Neovimプラグイン標準 |
| 型チェック | LuaCATS + lua-language-server | CI時の型安全性 |
| 外部依存 | kubectl CLI | Kubernetes操作の標準ツール |

### モジュール構成

ドメインモデルに基づくレイヤー構成。テストはコロケーションで配置。

```
k8s.nvim/
├── plugin/
│   └── k8s.lua                    # エントリポイント（最小限）
├── lua/
│   └── k8s/
│       ├── init.lua               # Public API / setup()
│       ├── api.lua                # ファサード（UI向け統一API）
│       ├── config.lua             # 設定管理
│       │
│       ├── domain/                # ドメイン層
│       │   ├── resources/         # リソース定義
│       │   │   ├── resource.lua   # 基底クラス
│       │   │   ├── pod.lua        # Pod定義（メタ情報含む）
│       │   │   ├── deployment.lua # Deployment定義
│       │   │   ├── service.lua    # Service定義
│       │   │   └── ...            # 他リソース
│       │   │
│       │   ├── actions/           # 操作（ビジネスロジック）
│       │   │   ├── list.lua       # 参照: 一覧取得
│       │   │   ├── list_spec.lua
│       │   │   ├── describe.lua   # 参照: 詳細取得
│       │   │   ├── describe_spec.lua
│       │   │   ├── delete.lua     # 変更: 削除
│       │   │   ├── delete_spec.lua
│       │   │   ├── scale.lua      # 変更: スケール
│       │   │   ├── scale_spec.lua
│       │   │   ├── restart.lua    # 変更: 再起動
│       │   │   ├── restart_spec.lua
│       │   │   ├── exec.lua       # 接続: exec
│       │   │   ├── exec_spec.lua
│       │   │   ├── logs.lua       # 接続: ログ
│       │   │   ├── logs_spec.lua
│       │   │   ├── port_forward.lua # 接続: ポートフォワード
│       │   │   ├── port_forward_spec.lua
│       │   │   └── fixtures/      # テスト用フィクスチャ
│       │   │
│       │   ├── state/             # 状態管理
│       │   │   ├── scope.lua      # Context/Namespace + ResourceCache
│       │   │   ├── scope_spec.lua
│       │   │   ├── connections.lua # アクティブ接続（PF等）
│       │   │   └── connections_spec.lua
│       │   │
│       │   └── ports/             # インターフェース定義（LuaCATS）
│       │       └── kubectl_port.lua # KubectlPort型定義
│       │
│       ├── infra/                 # インフラ層
│       │   └── kubectl/           # Kubectlアダプタ
│       │       ├── adapter.lua    # KubectlPortの実装
│       │       ├── adapter_spec.lua
│       │       ├── parser.lua     # JSON/YAMLパーサー
│       │       └── parser_spec.lua
│       │
│       └── ui/                    # UI層
│           ├── views/             # 画面
│           │   ├── resource_list.lua  # リソース一覧View
│           │   ├── describe.lua       # describe View
│           │   ├── port_forward_list.lua # PF一覧View
│           │   └── help.lua           # ヘルプ表示
│           │
│           ├── components/        # 共通部品
│           │   ├── layout.lua     # 3ウィンドウレイアウト
│           │   ├── table.lua      # テーブル描画
│           │   ├── header.lua     # ヘッダー・フッター
│           │   ├── menu.lua       # メニュー（telescope/NuiMenu）
│           │   ├── input.lua      # 入力ダイアログ（NuiInput）
│           │   └── confirm.lua    # 確認ダイアログ
│           │
│           └── columns.lua        # リソースタイプごとのカラム定義
│
├── doc/
│   └── k8s.txt                    # Vimヘルプドキュメント
└── docs/
    ├── DESIGN.md                  # 設計ドキュメント
    └── TODO.md                    # タスクリスト
```

### 各モジュールの責務

| モジュール | 責務 |
|-----------|------|
| `init.lua` | Public API (setup, toggle, open, close) |
| `api.lua` | ファサード。UI向け統一API、内部依存を隠蔽 |
| `config.lua` | ユーザー設定のマージ・検証・提供 |
| `domain/resources/*` | リソース定義（データ構造 + メタ情報） |
| `domain/actions/*` | 操作のビジネスロジック（Portsに依存） |
| `domain/state/scope.lua` | 現在のContext/Namespace + ResourceCache |
| `domain/state/connections.lua` | アクティブな接続（PF等）の管理 |
| `domain/ports/*` | 外部インターフェース定義（LuaCATS型） |
| `infra/kubectl/*` | KubectlPortの実装（vim.system経由） |
| `ui/views/*` | 各画面のView（描画 + キーマップ） |
| `ui/components/*` | 再利用可能なUIコンポーネント |
| `ui/columns.lua` | リソースタイプごとのカラム定義 |

## データ設計

### 状態モデル

状態は「Scope（スコープ + キャッシュ）」と「Connections（アクティブ接続）」に分離。
Connectionsはスコープ変更の影響を受けない（独立）。

```lua
-- Scope: Context/Namespace + ResourceCache
---@class Scope
---@field context string 現在のkubeconfigコンテキスト
---@field namespace string 現在のネームスペース（"" = All Namespaces）
---@field resource_type string 表示中のリソースタイプ
---@field resources Resource[] リソース一覧キャッシュ
---@field filter string 現在のフィルター文字列

-- Connections: アクティブな接続（Scopeから独立）
---@class Connections
---@field port_forwards PortForward[] アクティブなポートフォワード

---@class Resource
---@field kind string リソース種別
---@field name string リソース名
---@field namespace string ネームスペース
---@field status string ステータス
---@field age string 経過時間
---@field raw table kubectl出力の生データ

---@class PortForward
---@field id number プロセスID
---@field resource string 対象リソース（"pod/name" 形式）
---@field namespace string ネームスペース
---@field local_port number ローカルポート
---@field remote_port number リモートポート
```

### ポート（インターフェース）定義

```lua
---@class KubectlPort
---@field get_resources fun(kind: string, namespace: string): K8sResult<Resource[]>
---@field describe fun(kind: string, name: string, namespace: string): K8sResult<string>
---@field delete fun(kind: string, name: string, namespace: string): K8sResult<nil>
---@field scale fun(kind: string, name: string, namespace: string, replicas: number): K8sResult<nil>
---@field restart fun(kind: string, name: string, namespace: string): K8sResult<nil>
---@field exec fun(pod: string, container: string, namespace: string): K8sResult<Job>
---@field logs fun(pod: string, container: string, namespace: string, opts: LogOpts): K8sResult<Job>
---@field port_forward fun(resource: string, namespace: string, local_port: number, remote_port: number): K8sResult<Job>
---@field get_contexts fun(): K8sResult<string[]>
---@field use_context fun(name: string): K8sResult<nil>
---@field get_namespaces fun(): K8sResult<string[]>
```

### kubectlコマンドマッピング

| 機能 | kubectlコマンド |
|------|----------------|
| リソース一覧 | `kubectl get <resource> -o json` |
| リソース詳細 | `kubectl describe <resource> <name>` |
| ログ取得 | `kubectl logs [-f] <pod> [-c container]` |
| exec | `kubectl exec -it <pod> [-c container] -- <shell>` |
| ポートフォワード | `kubectl port-forward <resource> <local>:<remote>` |
| 削除 | `kubectl delete <resource> <name>` |
| スケール | `kubectl scale <resource> <name> --replicas=<n>` |
| コンテキスト一覧 | `kubectl config get-contexts -o name` |
| コンテキスト切替 | `kubectl config use-context <name>` |
| ネームスペース一覧 | `kubectl get namespaces -o json` |

## API設計

### Public API

```lua
-- プラグイン初期化（設定のみ、初期化は自動）
require("k8s").setup({
  -- デフォルト設定
  namespace = "default",           -- デフォルトネームスペース
  refresh_interval = 5000,         -- 自動更新間隔（ミリ秒）
  timeout = 10000,                 -- kubectlコマンドのタイムアウト（ミリ秒）

  -- UI設定（シングルペイン、ドリルダウン型）

  -- キーマップ（カスタマイズ可能）
  keymaps = {
    select = "<CR>",
    describe = "d",
    logs = "l",
    logs_previous = "P",           -- 前のコンテナのログ（-p）
    exec = "e",
    port_forward = "p",
    port_forward_list = "F",       -- ポートフォワード一覧
    delete = "D",
    scale = "s",
    restart = "X",                 -- Rollout restart
    refresh = "r",
    filter = "/",
    quit = "q",
    help = "?",
    back = "<Esc>",              -- 前の階層に戻る
    resource_menu = "R",
    toggle_secret = "S",           -- Secretマスク切り替え
    context_menu = "C",            -- コンテキスト選択メニュー
    namespace_menu = "N",          -- ネームスペース選択メニュー
  },

  -- telescope連携（オプショナル）
  telescope = {
    enabled = false,               -- trueでtelescope.nvimを使用
  },
})

-- UIの表示/非表示切り替え
require("k8s").toggle()

-- UIを開く
require("k8s").open()

-- UIを閉じる
require("k8s").close()

-- 特定リソースタイプを開く
require("k8s").open_resource("pods")
```

### ユーザーコマンド

```vim
:K8s                    " UIをトグル
:K8s open               " UIを開く
:K8s close              " UIを閉じる
:K8s pods               " Pods一覧を開く
:K8s deployments        " Deployments一覧を開く
:K8s services           " Services一覧を開く
:K8s nodes              " Nodes一覧を開く
:K8s context [name]     " コンテキスト表示/切り替え
:K8s namespace [name]   " ネームスペース表示/切り替え
:K8s portforwards       " ポートフォワード一覧
```

### キーマップ（`<Plug>`マッピング）

```lua
-- グローバル
vim.keymap.set("n", "<Plug>(k8s-toggle)", require("k8s").toggle)
vim.keymap.set("n", "<Plug>(k8s-open)", require("k8s").open)
vim.keymap.set("n", "<Plug>(k8s-close)", require("k8s").close)

-- リソース一覧画面内（バッファローカル）
-- <CR>     リソース選択/詳細表示
-- d        describe表示
-- l        ログ表示
-- e        exec（Podのみ）
-- p        ポートフォワード
-- D        削除（確認あり）
-- s        スケール（Deployment/ReplicaSet）
-- r        手動更新
-- /        フィルター
-- q        閉じる
-- ?        ヘルプ表示
```

## セキュリティ設計

### 認証・認可
- kubectlに完全委譲（kubeconfig/RBAC）
- プラグイン自体は認証情報を保持しない

### セキュリティ対策
- **入力検証**: コマンドインジェクション防止のためリソース名をエスケープ
- **シークレット保護**: Secretsのdata値はデフォルトでマスク表示（`S`キーでトグル可能）
- **確認ダイアログ**: 削除操作はYes/No確認を挟む
- **監査ログ**: 破壊的操作はNotifyで通知
- **無効操作**: リソースタイプに対して無効な操作時は「この操作はこのリソースでは使用できません」を表示

## パフォーマンス設計

### 最適化戦略

1. **遅延読み込み**
   - `plugin/k8s.lua`はコマンド/マッピング定義のみ
   - 実際のロジックは初回使用時に`require()`

2. **非同期処理**
   - すべてのkubectl実行は`vim.system`で非同期
   - UI描画は`vim.schedule`でメインスレッドに戻す

3. **キャッシング**
   - リソース一覧は5秒間キャッシュ
   - 手動更新でキャッシュ無効化

4. **差分更新**
   - 全体再描画ではなく変更行のみ更新

### スケーラビリティ
- 大量リソース時のページネーション（1000件以上）
- 仮想スクロール検討（将来）

## エラー戦略

### 起動時チェック

プラグイン起動時（`:K8s`コマンド実行時）に以下をチェック：
- **kubectl存在チェック**: `kubectl`がPATHに存在しない場合、エラーメッセージを表示して終了
- チェックは初回起動時のみ実行（以降はキャッシュ）

```lua
-- 起動時のkubectlチェック例
local function check_kubectl()
  local result = vim.fn.executable("kubectl")
  if result == 0 then
    vim.notify("kubectl not found in PATH. Please install kubectl.", vim.log.levels.ERROR)
    return false
  end
  return true
end
```

### エラー分類

| 分類 | 例 | 対応 |
|------|-----|------|
| 回復不可能 | kubectl未インストール | **起動時にエラー表示して終了** |
| 回復可能 | ネットワーク一時障害 | リトライ（3回、指数バックオフ） |
| ユーザー起因 | 存在しないリソース指定 | エラーメッセージ表示 |
| 設定エラー | 不正なkubeconfig | 設定確認を促すメッセージ |

### エラーハンドリング方針

```lua
---@class K8sResult<T>
---@field ok boolean
---@field data T|nil
---@field error string|nil

-- 例: kubectl実行結果
---@return K8sResult<K8sResource[]>
function kubectl.get_pods()
  -- ...
end
```

### エラーログ・通知
- エラーは`vim.notify`で通知（`vim.log.levels.ERROR`）
- 警告は`vim.log.levels.WARN`
- デバッグログは設定で有効化可能

## テスト戦略

### テストピラミッド

| レベル | 対象 | カバレッジ目標 |
|--------|------|---------------|
| ユニットテスト | parser, commands, utils | 90% |
| 統合テスト | actions + kubectl mock | 80% |
| E2Eテスト | 主要ユーザーフロー | 重要パスのみ |

### テストデータ戦略
- **フィクスチャ**: 各機能ディレクトリの`fixtures/`にkubectl出力のJSONサンプル（コロケーション）
- **モック**: kubectlコマンドをモック化してテスト

### モック/スタブ方針
- `kubectl/*`モジュールはインターフェース経由で差し替え可能に設計
- テスト時はモックkubectlを注入

### CI統合
- PR時: ユニットテスト + リント + 型チェック
- マージ時: 全テスト実行
- lua-language-serverによる型チェック
- stylua/luacheckによるリント

## 開発・運用

### 開発環境
- Neovim 0.10+
- lua-language-server（型チェック）
- stylua（フォーマット）
- luacheck（リント）
- plenary.nvim（テスト）

### ディレクトリ構造（再掲）
```
k8s.nvim/
├── plugin/k8s.lua          # エントリポイント
├── lua/k8s/
│   ├── api.lua             # ファサード
│   ├── domain/             # ドメイン層（resources, actions, state, ports）
│   ├── infra/              # インフラ層（kubectl adapter）
│   └── ui/                 # UI層（views, components）
├── doc/k8s.txt             # ヘルプ
└── docs/                   # 設計ドキュメント
```

## 制約と前提

### 技術的制約
- Neovim 0.10+必須（vim.system API）
- kubectl CLIがPATHに存在すること
- nui.nvim依存

### ビジネス制約
- 個人プロジェクトとして開発
- OSS（MITライセンス想定）

### 依存関係
- nui.nvim: UIコンポーネント
- plenary.nvim: テスト実行（開発時のみ）
- telescope.nvim: オプショナル（fuzzy finder連携）

## インタビュー決定事項サマリー

2025-12-30のインタビューで決定した主要な設計方針：

| カテゴリ | 決定事項 |
|---------|---------|
| レイアウト | シングルペイン、ドリルダウン型（k9s風） |
| ナビゲーション | `<CR>`で階層を進む、`<Esc>`で戻る |
| ログ/exec | 別タブで開く（複数Pod同時表示可能） |
| describe表示 | 通常バッファ（検索・コピー容易） |
| execシェル | /bin/bash優先、なければ/bin/sh |
| 複数コンテナ | 選択メニュー表示 |
| ポートフォワード | タブ閉じ/Neovim終了時に停止 |
| デフォルトNS | `default` |
| 削除確認 | Yes/Noのみ（シンプル） |
| Secretマスク | トグル可能（Sキー） |
| デフォルトソート | NAME（アルファベット順） |
| 更新時カーソル | 行番号で保持 |
| キーマップ | カスタマイズ可能 |
| kubectlチェック | 起動時にエラー表示 |
| telescope連携 | オプショナル |
| カラム設定 | リソースタイプごとに固定 |
| リソース切替 | コマンド + メニューUI両対応 |
| フィルター | インクリメンタル検索、ESC+再度/でクリア |
| Context/NS切替 | メニューUI（C/Nキー）、切替後自動更新 |
| 初期表示リソース | Pods |
| ヘルプ表示 | フッター拡張形式 |
| ポートフォワード一覧 | 専用ビュー（Fキー） |
| ローカルポート指定 | 入力ダイアログ |
| スケーリング | 入力ダイアログでレプリカ数指定 |
| Rollout restart | Yes/No確認あり |
| ログタイムスタンプ | 常に表示（--timestamps） |
| 前のログ | 対応（Pキーで-pオプション） |
| リソースメニュー | フローティング形式 |
| describe ハイライト | filetype=yaml |
| ソート変更 | 不要（NAME順固定） |
| Shell判定 | `sh -c "[ -e /bin/bash ] && bash || sh"`で自動判定 |
| リモートポート | コンテナポートから自動検出 |
| タイムアウト | 設定可能（デフォルト10秒） |
| All Namespaces | Nキーメニューの先頭に表示 |
| ログ/execタブ | k8s.nvimタブを閉じてもそのまま残る |
| PFタブ閉じ時 | ポートフォワードは継続 |
| 削除リソース | 次回更新時に自動消去 |
| リソース0件 | 空テーブル表示（ヘッダーのみ） |
| 通知設定 | vim.notifyデフォルト動作に任せる |
| describe更新 | 非対応（一覧に戻って再選択） |
| ログtail | kubectlデフォルト値を使用 |
| メニュー検索 | 不要（j/k選択のみ） |
| 操作後更新 | 即座に一覧を再取得 |
| exec終了時 | タブを自動的に閉じる |
| 実行中表示 | ヘッダーにLoading...表示 |
| PF成功通知 | 「Port forwarding started: ...」を表示 |
| フィルター表示 | ヘッダーに表示 |
| 無効操作 | エラーメッセージを表示 |
| 切替時カーソル | 先頭行にリセット |
| レイアウト実装 | NuiPopupで3ウィンドウ（ヘッダー/コンテンツ/フッター） |
| テーブル描画 | NuiLine/NuiTextでハイライト付き |
| 状態管理 | Scope（Context/NS + Cache）とConnections（PF等）に分離 |
| メニュー実装 | telescope優先、なければNuiMenu |
| 確認ダイアログ | vim.fn.confirm |
| 入力ダイアログ | NuiInput |
| フィルター入力 | コマンドライン（vim.fn.input） |
| バッファ管理 | 既存バッファ再利用 |
| マウス操作 | 非サポート（キーボードのみ） |
| vim.ui.select | カスタマイズに自動対応 |
| カラム定義 | ui/columns.luaに配置 |
| フィクスチャ配置 | 各アクションディレクトリ内（コロケーション） |
| **ドメインモデル** | Cluster > Namespace > Resource の包含関係 |
| 操作カテゴリ | 参照（list, describe）/ 変更（delete, scale）/ 接続（logs, exec, PF） |
| 接続の特徴 | ストリーム型（継続的データ流） |
| Resource表現 | クラスアプローチ（種別ごとにメタ情報を持つ） |
| 操作の配置 | 別モジュール（テスト容易性のため） |
| レイヤー構成 | UI → api.lua（ファサード）→ ドメイン → インフラ |
| ポート定義 | LuaCATSでインターフェース定義 |
| kubectl位置 | インフラ層（KubectlPortの実装） |

## 参照

- タスク分解: planning-tasks スキルでTODO.mdを生成
- [Neovim Lua Plugin Best Practices](https://github.com/nvim-neorocks/nvim-best-practices)
- [nui.nvim Documentation](https://github.com/MunifTanjim/nui.nvim)
- [k9s - Kubernetes CLI](https://k9scli.io/)
