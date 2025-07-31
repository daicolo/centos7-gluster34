#!/bin/bash

###
# CentOS 7 GlusterFS 3.4 Docker Compose
# 初回用データディレクトリ作成スクリプト
# 
# このスクリプトは、GlusterFSクラスター用のホストディレクトリを作成し、
# 適切な権限を設定します。
###

set -e  # エラー時に即座に終了

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

log_info "GlusterFS データディレクトリセットアップを開始します..."
log_info "作業ディレクトリ: $SCRIPT_DIR"
log_info "データディレクトリ: $DATA_DIR"

# メインのdataディレクトリを作成
if [ ! -d "$DATA_DIR" ]; then
    log_info "メインデータディレクトリを作成中: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    log_success "メインデータディレクトリを作成しました"
else
    log_warning "メインデータディレクトリは既に存在します: $DATA_DIR"
fi

# 各ノード用のディレクトリを作成
NODES=("node1" "node2" "node3" "node4")

for node in "${NODES[@]}"; do
    NODE_DIR="$DATA_DIR/$node"
    
    if [ ! -d "$NODE_DIR" ]; then
        log_info "$node のデータディレクトリを作成中: $NODE_DIR"
        mkdir -p "$NODE_DIR"
        
        # brick用のサブディレクトリも作成
        mkdir -p "$NODE_DIR/brick1"
        mkdir -p "$NODE_DIR/brick2"
        mkdir -p "$NODE_DIR/brick3"
        
        log_success "$node のディレクトリを作成しました"
    else
        log_warning "$node のディレクトリは既に存在します: $NODE_DIR"
        
        # brick用のサブディレクトリが存在しない場合は作成
        for brick in brick1 brick2 brick3; do
            BRICK_DIR="$NODE_DIR/$brick"
            if [ ! -d "$BRICK_DIR" ]; then
                log_info "$node/$brick サブディレクトリを作成中"
                mkdir -p "$BRICK_DIR"
            fi
        done
    fi
done

# 権限設定
log_info "ディレクトリ権限を設定中..."
chmod -R 755 "$DATA_DIR"
log_success "権限設定が完了しました"

# 現在のユーザー情報を表示
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

log_info "現在のユーザー: $CURRENT_USER (UID: $CURRENT_UID, GID: $CURRENT_GID)"

# SELinux設定の確認と警告
if command -v getenforce >/dev/null 2>&1; then
    SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Unknown")
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        log_warning "SELinuxが有効です。必要に応じて以下のコマンドを実行してください:"
        echo "  sudo setsebool -P virt_use_fusefs 1"
        echo "  sudo setsebool -P virt_sandbox_use_fusefs 1"
    fi
fi

# 作成されたディレクトリ構造を表示
echo ""
log_info "作成されたディレクトリ構造:"
tree "$DATA_DIR" 2>/dev/null || {
    log_warning "treeコマンドが見つかりません。ls -laを使用します:"
    echo ""
    ls -la "$DATA_DIR"
    echo ""
    for node in "${NODES[@]}"; do
        echo "$node/:"
        ls -la "$DATA_DIR/$node" 2>/dev/null || echo "  (ディレクトリが存在しません)"
        echo ""
    done
}

# .gitignoreファイルを作成（オプション）
GITIGNORE_FILE="$DATA_DIR/.gitignore"
if [ ! -f "$GITIGNORE_FILE" ]; then
    log_info ".gitignoreファイルを作成中..."
    cat > "$GITIGNORE_FILE" << 'EOF'
# GlusterFS runtime files
*/brick*/
*/.glusterfs/
*/lost+found/

# Temporary files
*.tmp
*.log
*~

# OS specific files
.DS_Store
Thumbs.db
EOF
    log_success ".gitignoreファイルを作成しました"
fi

# 使用方法の表示
echo ""
log_success "セットアップが完了しました！"
echo ""
echo "次のステップ:"
echo "1. Docker Composeでサービスを起動:"
echo "   docker compose up -d"
echo ""
echo "2. GlusterFSクラスターを設定:"
echo "   ssh -p 2222 root@localhost"
echo ""
echo "3. ボリュームを作成する際のブリックパス例:"
echo "   gluster-node1:/data/brick1"
echo "   gluster-node2:/data/brick1"
echo "   gluster-node3:/data/brick1"
echo "   gluster-node4:/data/brick1"
echo ""
log_info "詳細な手順はREADME.mdを参照してください。"
