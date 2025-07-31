#!/bin/bash

###
# CentOS 7 GlusterFS 3.4 Docker Compose
# 全ノード管理スクリプト
# 
# 使用方法:
#   ./manage-nodes.sh [コマンド]
#   
# 利用可能なコマンド:
#   status  - 全ノードの状態確認
#   start   - 全ノードの起動
#   stop    - 全ノードの停止
#   restart - 全ノードの再起動
#   logs    - 全ノードのログ表示
#   exec    - 対話的にノードを選択して接続
###

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# ノード一覧
NODES=("gluster-node1" "gluster-node2" "gluster-node3" "gluster-node4")
NODE_DESCRIPTIONS=("Primary" "Secondary" "Tertiary" "Spare")

# 使用方法表示
show_usage() {
    echo -e "${CYAN}使用方法:${NC}"
    echo "  $0 [コマンド]"
    echo ""
    echo -e "${CYAN}利用可能なコマンド:${NC}"
    echo "  status   - 全ノードの状態確認"
    echo "  start    - 全ノードの起動"
    echo "  stop     - 全ノードの停止"
    echo "  restart  - 全ノードの再起動"
    echo "  logs     - 全ノードのログ表示"
    echo "  exec     - 対話的にノードを選択して接続"
    echo ""
    echo -e "${CYAN}例:${NC}"
    echo "  $0 status"
    echo "  $0 start"
    echo "  $0 exec"
}

# 全ノードの状態確認
check_all_status() {
    log_info "全ノードの状態を確認中..."
    echo ""
    printf "%-15s %-10s %-15s %s\n" "ノード名" "状態" "説明" "IP"
    echo "=================================================="
    
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        desc="${NODE_DESCRIPTIONS[$i]}"
        
        # 状態取得
        status=$(docker compose ps --format "table {{.Name}}\t{{.State}}" | grep "$node" | awk '{print $2}')
        if [ -z "$status" ]; then
            status="Not Found"
            status_color="$RED"
        elif [ "$status" = "running" ]; then
            status_color="$GREEN"
        else
            status_color="$YELLOW"
        fi
        
        # IP取得（実行中の場合のみ）
        if [ "$status" = "running" ]; then
            ip=$(docker compose exec "$node" hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
        else
            ip="N/A"
        fi
        
        printf "%-15s ${status_color}%-10s${NC} %-15s %s\n" "$node" "$status" "$desc" "$ip"
    done
    echo ""
}

# 全ノード起動
start_all_nodes() {
    log_info "全ノードを起動中..."
    docker compose up -d
    if [ $? -eq 0 ]; then
        log_success "全ノードの起動が完了しました"
        sleep 3
        check_all_status
    else
        log_error "ノードの起動に失敗しました"
        exit 1
    fi
}

# 全ノード停止
stop_all_nodes() {
    log_warning "全ノードを停止中..."
    docker compose down
    if [ $? -eq 0 ]; then
        log_success "全ノードの停止が完了しました"
    else
        log_error "ノードの停止に失敗しました"
        exit 1
    fi
}

# 全ノード再起動
restart_all_nodes() {
    log_info "全ノードを再起動中..."
    docker compose restart
    if [ $? -eq 0 ]; then
        log_success "全ノードの再起動が完了しました"
        sleep 5
        check_all_status
    else
        log_error "ノードの再起動に失敗しました"
        exit 1
    fi
}

# 全ノードのログ表示
show_all_logs() {
    log_info "全ノードのログを表示中..."
    echo -e "${YELLOW}Ctrl+C で終了${NC}"
    echo ""
    docker compose logs -f
}

# 対話的ノード選択
interactive_exec() {
    echo -e "${CYAN}接続先ノードを選択してください:${NC}"
    echo ""
    
    for i in "${!NODES[@]}"; do
        node="${NODES[$i]}"
        desc="${NODE_DESCRIPTIONS[$i]}"
        num=$((i + 1))
        
        # 状態確認
        status=$(docker compose ps --format "table {{.Name}}\t{{.State}}" | grep "$node" | awk '{print $2}')
        if [ "$status" = "running" ]; then
            status_indicator="${GREEN}●${NC}"
        elif [ -z "$status" ]; then
            status_indicator="${RED}●${NC}"
        else
            status_indicator="${YELLOW}●${NC}"
        fi
        
        echo -e "  ${MAGENTA}$num${NC}) $status_indicator $node ($desc)"
    done
    
    echo ""
    echo -e "  ${MAGENTA}q${NC}) 終了"
    echo ""
    read -p "選択してください [1-4/q]: " choice
    
    case $choice in
        [1-4])
            node_index=$((choice - 1))
            selected_node="${NODES[$node_index]}"
            
            # connect-node.shスクリプトを使用
            if [ -f "./connect-node.sh" ]; then
                ./connect-node.sh "$choice"
            else
                log_info "$selected_node に接続中..."
                docker compose exec "$selected_node" /bin/bash
            fi
            ;;
        q|Q)
            log_info "終了します"
            exit 0
            ;;
        *)
            log_error "無効な選択です: $choice"
            exit 1
            ;;
    esac
}

# メイン処理
main() {
    case "${1:-}" in
        status)
            check_all_status
            ;;
        start)
            start_all_nodes
            ;;
        stop)
            stop_all_nodes
            ;;
        restart)
            restart_all_nodes
            ;;
        logs)
            show_all_logs
            ;;
        exec)
            interactive_exec
            ;;
        -h|--help|"")
            show_usage
            ;;
        *)
            log_error "無効なコマンド: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Docker Composeファイルの存在確認
if [ ! -f "compose.yaml" ] && [ ! -f "docker-compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    log_error "Docker Composeファイルが見つかりません"
    exit 1
fi

# メイン処理実行
main "$@"
