# CentOS 7 GlusterFS 3.4 Docker Compose

このプロジェクトは、Docker Compose v2を使用してGlusterFSクラスターを構築するためのものです。

## 構成

- **ベースイメージ**: CentOS 7
- **GlusterFS**: バージョン 3.4.7
- **ノード数**: 4台のGlusterFSノード（基本3台＋予備1台）
- **SSH**: 各ノードでポート2222で有効

## 使用方法

### 1. イメージのビルドとコンテナの起動

```bash
# すべてのサービスを起動
docker compose up -d

# または特定のノードのみ起動
docker compose up -d gluster-node1 gluster-node2 gluster-node3

# 予備ノードも含めて起動
docker compose up -d gluster-node1 gluster-node2 gluster-node3 gluster-node4
```

### 2. GlusterFSクラスターの設定

各ノードにSSHで接続：

```bash
# ノード1に接続
ssh -p 2222 root@localhost

# ノード2に接続
ssh -p 2223 root@localhost

# ノード3に接続
ssh -p 2224 root@localhost

# ノード4に接続（予備ノード）
ssh -p 2225 root@localhost
```

デフォルトパスワード: `password`

### 3. GlusterFSクラスターの構築

ノード1で以下のコマンドを実行：

```bash
# 他のノードをクラスターに追加
gluster peer probe gluster-node2
gluster peer probe gluster-node3

# ピアの状態確認
gluster peer status
```

#### 3.1 レプリカボリューム（高可用性）

```bash
# ボリューム作成（レプリカ3）
gluster volume create test-replica-volume replica 3 \
  gluster-node1:/data/brick1 \
  gluster-node2:/data/brick1 \
  gluster-node3:/data/brick1 force

# ボリューム開始
gluster volume start test-replica-volume

# ボリューム情報確認
gluster volume info test-replica-volume
```

#### 3.2 分散ボリューム（容量重視）

```bash
# ブリック用ディレクトリ作成
mkdir -p /data/brick1

# 各ノードでブリック用ディレクトリを作成（必要に応じて）
# ssh gluster-node2 "mkdir -p /data/brick1"
# ssh gluster-node3 "mkdir -p /data/brick1"

# ボリューム作成（分散3）
gluster volume create test-distributed-volume \
  gluster-node1:/data/brick1 \
  gluster-node2:/data/brick1 \
  gluster-node3:/data/brick1 force

# ボリューム開始
gluster volume start test-distributed-volume

# ボリューム情報確認
gluster volume info test-distributed-volume
```

#### 3.3 分散レプリカボリューム（高可用性＋容量）

6ノード以上の場合に推奨：

```bash
# ボリューム作成（分散レプリカ：分散2、レプリカ3）
# 注意: この例では3ノードしかないため、実際には使用できません
gluster volume create test-dist-replica-volume replica 3 \
  gluster-node1:/data/brick1 gluster-node2:/data/brick1 gluster-node3:/data/brick1 \
  gluster-node1:/data/brick2 gluster-node2:/data/brick2 gluster-node3:/data/brick2 force

# ボリューム開始
gluster volume start test-dist-replica-volume
```

#### ボリュームタイプの比較

| タイプ | 冗長性 | 容量効率 | パフォーマンス | 用途 |
|--------|--------|----------|----------------|------|
| **レプリカ** | 高 | 低（1/n） | 読み込み高速 | 重要なデータ |
| **分散** | なし | 高（100%） | 書き込み高速 | 大容量データ |
| **分散レプリカ** | 高 | 中（1/n） | バランス良好 | 本番環境推奨 |

### 4. ボリュームのマウント

```bash
# マウントポイント作成
mkdir -p /mnt/glusterfs

# レプリカボリュームをマウント
mount -t glusterfs gluster-node1:/test-replica-volume /mnt/glusterfs

# または分散ボリュームをマウント
# mount -t glusterfs gluster-node1:/test-distributed-volume /mnt/glusterfs

# マウント確認
df -h /mnt/glusterfs
```

### 5. ブリックの置き換え（replace-brick）

故障したブリックを新しいホストの新しいブリックに置き換える例：

#### 5.1 事前準備

```bash
# 現在のボリューム状態確認
gluster volume status test-replica-volume

# ブリック情報確認
gluster volume info test-replica-volume

# 置き換え先の新しいホストをクラスターに追加（必要な場合）
# 例：新しいノード4をクラスターに追加
# gluster peer probe gluster-node4
```

#### 5.2 レプリカボリュームでのブリック置き換え

```bash
# レプリカボリュームの場合（ヒーリングあり）
# 構文: gluster volume replace-brick <VOLNAME> <SOURCE-BRICK> <NEW-BRICK> commit force

# 例：node2のブリックをnode4に置き換え
gluster volume replace-brick test-replica-volume \
  gluster-node2:/data/brick1 \
  gluster-node4:/data/brick1 commit force

# 置き換え後の状態確認
gluster volume status test-replica-volume
gluster volume info test-replica-volume

# データ同期（ヒーリング）開始
gluster volume heal test-replica-volume

# ヒーリング状況確認
gluster volume heal test-replica-volume info
```

#### 5.3 分散ボリュームでの段階的置き換え（無停止）

分散ボリュームでも無停止で安全に移行する方法：

```bash
# 1. 新しいノードをクラスターに追加
gluster peer probe gluster-node4

# 2. 新しいブリックを分散ボリュームに追加
gluster volume add-brick test-distributed-volume \
  gluster-node4:/data/brick1

# 3. データ再配置（rebalance）を開始
gluster volume rebalance test-distributed-volume start

# 4. 再配置の進行状況確認
gluster volume rebalance test-distributed-volume status

# 5. 再配置完了まで待機
# "completed" になるまで繰り返し確認
while true; do
  STATUS=$(gluster volume rebalance test-distributed-volume status | grep -o "completed\|in progress")
  echo "Rebalance status: $STATUS"
  if [ "$STATUS" = "completed" ]; then
    break
  fi
  sleep 30
done

# 6. 古いブリックを削除開始
gluster volume remove-brick test-distributed-volume \
  gluster-node2:/data/brick1 start

# 7. データ移動の進行状況確認
gluster volume remove-brick test-distributed-volume \
  gluster-node2:/data/brick1 status

# 8. データ移動完了後、削除を確定
gluster volume remove-brick test-distributed-volume \
  gluster-node2:/data/brick1 commit

# 9. 最終的なボリューム状態確認
gluster volume info test-distributed-volume
gluster volume status test-distributed-volume
```

#### 5.4 段階的な置き換え（推奨方法）

より安全な段階的置き換え方法：

```bash
# 1. 新しいブリックを追加
gluster volume add-brick test-replica-volume replica 4 \
  gluster-node4:/data/brick1

# 2. データ再バランス実行
gluster volume rebalance test-replica-volume start

# 3. 再バランス状況確認
gluster volume rebalance test-replica-volume status

# 4. 古いブリックを削除
gluster volume remove-brick test-replica-volume replica 3 \
  gluster-node2:/data/brick1 start

# 5. 削除状況確認
gluster volume remove-brick test-replica-volume replica 3 \
  gluster-node2:/data/brick1 status

# 6. 削除を確定
gluster volume remove-brick test-replica-volume replica 3 \
  gluster-node2:/data/brick1 commit
```

#### 5.5 トラブルシューティング

```bash
# ブリックの状態確認
gluster volume status test-replica-volume detail

# ログファイル確認
tail -f /var/log/glusterfs/glusterd.log
tail -f /var/log/glusterfs/bricks/data-brick1.log

# 強制的なブリック置き換え（最終手段）
gluster volume reset-brick test-replica-volume \
  gluster-node2:/data/brick1 \
  gluster-node4:/data/brick1 commit force
```

## 6. ポート一覧

| サービス | SSH | Gluster Daemon | 説明 |
|----------|-----|----------------|------|
| gluster-node1 | 2222 | 24007 | プライマリノード |
| gluster-node2 | 2223 | 24017 | セカンダリノード |
| gluster-node3 | 2224 | 24027 | ターシャリノード |
| gluster-node4 | 2225 | 24037 | 予備ノード（置き換え用） |

## 7. データの永続化

各ノードのデータは以下のように保存されます：

- **設定ファイル**: 名前付きボリューム `gluster{1,2,3,4}-etc`
- **GlusterFS状態**: 名前付きボリューム `gluster{1,2,3,4}-lib`
- **ログファイル**: 名前付きボリューム `gluster{1,2,3,4}-log`
- **データディスク**: ホストディレクトリ `./data/node{1,2,3,4}`

### ホストディレクトリ構造

```
data/
├── node1/    # gluster-node1のデータ
├── node2/    # gluster-node2のデータ
├── node3/    # gluster-node3のデータ
└── node4/    # gluster-node4のデータ（予備）
```

これらのディレクトリは自動的に作成されます。

## 8. 停止と削除

```bash
# サービス停止
docker compose down

# データボリュームも含めて削除
docker compose down -v
```

## 9. 注意事項

- コンテナは`privileged: true`で実行されます（systemd使用のため）
- `/sys/fs/cgroup`をread-onlyでマウントしています
- データの安全性のため、本番環境では適切なバックアップ戦略を実装してください
