#!/bin/bash

###
# CentOS 7 GlusterFS 3.4 Docker Compose
# ノード接続スクリプト
# 
# 使用方法:
#   ./connect-node.sh [ノード番号]
#   例: ./connect-node.sh 1
#       ./connect-node.sh 2
###

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# 使用方法表示
show_usage() {
    echo -e "${CYAN}使用方法:${NC}"
    echo "  $0 [ノード番号]"
    echo ""
    echo -e "${CYAN}例:${NC}"
    echo "  $0 1    # gluster-node1に接続"
    echo "  $0 2    # gluster-node2に接続" 
    echo "  $0 3    # gluster-node3に接続"
    echo "  $0 4    # gluster-node4に接続"
    echo ""
    echo -e "${CYAN}利用可能なノード:${NC}"
    echo "  1: gluster-node1 (Primary)"
    echo "  2: gluster-node2 (Secondary)"
    echo "  3: gluster-node3 (Tertiary)"
    echo "  4: gluster-node4 (Spare)"
}

# コンテナの状態確認
check_container_status() {
    local container_name="$1"
    local status=$(docker compose ps --format "table {{.Name}}\t{{.State}}" | grep "$container_name" | awk '{print $2}')
    
    if [ -z "$status" ]; then
        return 2  # コンテナが存在しない
    elif [ "$status" = "running" ]; then
        return 0  # 実行中
    else
        return 1  # 停止中
    fi
}

# メイン処理
main() {
    # 引数チェック
    if [ $# -eq 0 ]; then
        log_error "ノード番号が指定されていません"
        echo ""
        show_usage
        exit 1
    fi
    
    # ノード番号の検証
    NODE_NUM="$1"
    if ! [[ "$NODE_NUM" =~ ^[1-4]$ ]]; then
        log_error "無効なノード番号です: $NODE_NUM"
        log_info "有効なノード番号: 1, 2, 3, 4"
        echo ""
        show_usage
        exit 1
    fi
    
    # コンテナ名の設定
    CONTAINER_NAME="gluster-node$NODE_NUM"
    
    log_info "接続先: $CONTAINER_NAME"
    
    # Docker Composeファイルの存在確認
    if [ ! -f "compose.yaml" ] && [ ! -f "docker-compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
        log_error "Docker Composeファイルが見つかりません"
        log_info "compose.yaml、docker-compose.yaml、またはdocker-compose.ymlが存在することを確認してください"
        exit 1
    fi
    
    # コンテナの状態確認
    log_info "コンテナの状態を確認中..."
    check_container_status "$CONTAINER_NAME"
    status_code=$?
    
    case $status_code in
        0)
            log_success "コンテナは実行中です"
            ;;
        1)
            log_warning "コンテナは停止中です。起動を試行します..."
            docker compose up -d "$CONTAINER_NAME"
            if [ $? -ne 0 ]; then
                log_error "コンテナの起動に失敗しました"
                exit 1
            fi
            log_success "コンテナを起動しました"
            # 起動後少し待機
            sleep 3
            ;;
        2)
            log_error "コンテナ '$CONTAINER_NAME' が見つかりません"
            log_info "利用可能なコンテナを確認しています..."
            docker compose ps
            exit 1
            ;;
    esac
    
    # bashシェルで接続
    log_info "コンテナに接続中..."
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} $CONTAINER_NAME にbashで接続します${NC}"
    echo -e "${GREEN} 終了するには 'exit' と入力してください${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # docker compose execを実行
    docker compose exec "$CONTAINER_NAME" /bin/bash
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "接続を終了しました"
    else
        log_error "接続に失敗しました"
        exit 1
    fi
}

# ヘルプオプションの処理
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# メイン処理実行
main "$@"
