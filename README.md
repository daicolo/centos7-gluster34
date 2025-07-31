# CentOS 7 GlusterFS 3.4 Docker Compose

このプロジェクトは、Docker Compose v2を使用してGlusterFSクラスターを構築するためのものです。

## 構成

- **ベースイメージ**: CentOS 7
- **GlusterFS**: バージョン 3.4.7
- **ノード数**: 3台のGlusterFSノード
- **SSH**: 各ノードでポート2222で有効

## 使用方法

### 1. イメージのビルドとコンテナの起動

```bash
# すべてのサービスを起動
docker compose up -d

# または特定のノードのみ起動
docker compose up -d gluster-node1 gluster-node2
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

# ボリューム作成（レプリカ3）
gluster volume create test-volume replica 3 \
  gluster-node1:/data/brick1 \
  gluster-node2:/data/brick1 \
  gluster-node3:/data/brick1 force

# ボリューム開始
gluster volume start test-volume

# ボリューム情報確認
gluster volume info test-volume
```

### 4. ボリュームのマウント

```bash
# マウントポイント作成
mkdir -p /mnt/glusterfs

# ボリュームマウント
mount -t glusterfs gluster-node1:/test-volume /mnt/glusterfs
```

## ポート一覧

| サービス | SSH | Gluster Daemon | 説明 |
|----------|-----|----------------|------|
| gluster-node1 | 2222 | 24007 | プライマリノード |
| gluster-node2 | 2223 | 24017 | セカンダリノード |
| gluster-node3 | 2224 | 24027 | ターシャリノード |

## データの永続化

各ノードのデータは以下のように保存されます：

- **設定ファイル**: 名前付きボリューム `gluster{1,2,3}-etc`
- **GlusterFS状態**: 名前付きボリューム `gluster{1,2,3}-lib`
- **ログファイル**: 名前付きボリューム `gluster{1,2,3}-log`
- **データディスク**: ホストディレクトリ `./data/node{1,2,3}`

### ホストディレクトリ構造

```
data/
├── node1/    # gluster-node1のデータ
├── node2/    # gluster-node2のデータ
└── node3/    # gluster-node3のデータ
```

これらのディレクトリは自動的に作成されます。

## 停止と削除

```bash
# サービス停止
docker compose down

# データボリュームも含めて削除
docker compose down -v
```

## 注意事項

- コンテナは`privileged: true`で実行されます（systemd使用のため）
- `/sys/fs/cgroup`をread-onlyでマウントしています
- データの安全性のため、本番環境では適切なバックアップ戦略を実装してください
