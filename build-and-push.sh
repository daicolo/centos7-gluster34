#!/bin/bash

###
# CentOS 7 GlusterFS 3.4 Docker Image Build and Push Script
# GitHub Container Registry (ghcr.io) へのイメージpush
###

set -e  # エラー時に即座に終了

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

# .envファイルから環境変数を読み込み
if [ -f ".env" ]; then
    log_info ".envファイルから設定を読み込み中..."
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
else
    log_warning ".envファイルが見つかりません。デフォルト値を使用します"
fi

# 設定（.envファイルからの読み込み、またはデフォルト値）
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-daicolo}"
IMAGE_NAME="${IMAGE_NAME:-centos7-gluster34}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# イメージ名の構築
FULL_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest"

# 使用方法表示
show_usage() {
    echo -e "${CYAN}使用方法:${NC}"
    echo "  $0 [コマンド]"
    echo ""
    echo -e "${CYAN}利用可能なコマンド:${NC}"
    echo "  build    - Dockerイメージをビルド"
    echo "  push     - GitHub Container Registryにpush"
    echo "  login    - GitHub Container Registryにログイン"
    echo "  all      - build + push を実行"
    echo ""
    echo -e "${CYAN}例:${NC}"
    echo "  $0 login"
    echo "  $0 build"
    echo "  $0 push"
    echo "  $0 all"
    echo ""
    echo -e "${CYAN}現在の設定:${NC}"
    echo "  レジストリ: ${REGISTRY}"
    echo "  ネームスペース: ${NAMESPACE}"
    echo "  イメージ名: ${IMAGE_NAME}"
    echo "  タグ: ${IMAGE_TAG}"
    echo "  完全なイメージ名: ${FULL_IMAGE_NAME}"
    echo "  latestタグ: ${LATEST_IMAGE_NAME}"
    echo ""
    echo -e "${CYAN}設定の変更:${NC}"
    echo "  .envファイルを編集してください"
}

# GitHub Container Registryにログイン
github_login() {
    log_info "GitHub Container Registryにログイン中..."
    echo ""
    echo -e "${YELLOW}GitHub Personal Access Token (PAT) が必要です。${NC}"
    echo -e "${YELLOW}PATは以下の権限が必要です:${NC}"
    echo "  - write:packages"
    echo "  - read:packages" 
    echo "  - delete:packages (オプション)"
    echo ""
    echo -e "${CYAN}PATの作成方法:${NC}"
    echo "  1. GitHub → Settings → Developer settings → Personal access tokens"
    echo "  2. Generate new token (classic)"
    echo "  3. 上記の権限を選択"
    echo ""
    
    read -p "GitHub Container Registryにログインしますか? [y/N]: " choice
    case $choice in
        [Yy]*)
            docker login ${REGISTRY}
            if [ $? -eq 0 ]; then
                log_success "ログインが完了しました"
                return 0
            else
                log_error "ログインに失敗しました"
                return 1
            fi
            ;;
        *)
            log_info "ログインをスキップしました"
            return 0
            ;;
    esac
}

# Dockerイメージをビルド
build_image() {
    log_info "Dockerイメージをビルド中..."
    log_info "メインタグ: ${FULL_IMAGE_NAME}"
    log_info "latestタグ: ${LATEST_IMAGE_NAME}"
    
    # 指定されたタグとlatestタグの両方でビルド
    if [ "${IMAGE_TAG}" = "latest" ]; then
        # IMAGE_TAGがlatestの場合はlatestタグのみ
        docker build -t ${FULL_IMAGE_NAME} .
    else
        # IMAGE_TAGが特定のバージョンの場合は両方のタグを作成
        docker build -t ${FULL_IMAGE_NAME} -t ${LATEST_IMAGE_NAME} .
    fi
    
    if [ $? -eq 0 ]; then
        log_success "ビルドが完了しました"
        
        # イメージサイズを表示
        echo ""
        log_info "ビルド済みイメージ:"
        docker images | grep -E "(${IMAGE_NAME}|${NAMESPACE}/${IMAGE_NAME})" | head -10
    else
        log_error "ビルドに失敗しました"
        exit 1
    fi
}

# GitHub Container Registryにpush
push_image() {
    log_info "GitHub Container Registryにpush中..."
    log_info "対象イメージ: ${FULL_IMAGE_NAME}"
    
    # イメージが存在するか確認
    if ! docker images | grep -q "${NAMESPACE}/${IMAGE_NAME}"; then
        log_warning "イメージが見つかりません。先にビルドを実行します..."
        build_image
    fi
    
    # 指定されたタグをpush
    log_info "タグ ${IMAGE_TAG} をpush中..."
    docker push ${FULL_IMAGE_NAME}
    
    if [ $? -ne 0 ]; then
        log_error "タグ ${IMAGE_TAG} のpushに失敗しました"
        exit 1
    fi
    
    # latestタグもpush（IMAGE_TAGがlatestでない場合のみ）
    if [ "${IMAGE_TAG}" != "latest" ]; then
        log_info "latestタグをpush中..."
        docker push ${LATEST_IMAGE_NAME}
        
        if [ $? -ne 0 ]; then
            log_error "latestタグのpushに失敗しました"
            exit 1
        fi
        
        log_success "両方のタグのpushが完了しました"
        echo ""
        log_info "タグ ${IMAGE_TAG}: ${FULL_IMAGE_NAME}"
        log_info "タグ latest: ${LATEST_IMAGE_NAME}"
    else
        log_success "latestタグのpushが完了しました"
        echo ""
        log_info "イメージ: ${FULL_IMAGE_NAME}"
    fi
    
    echo ""
    log_info "イメージURL: https://github.com/${NAMESPACE}/${IMAGE_NAME}/pkgs/container/${IMAGE_NAME}"
    log_info "pull コマンド: docker pull ${FULL_IMAGE_NAME}"
}

# メイン処理
main() {
    case "${1:-}" in
        build)
            build_image
            ;;
        push)
            push_image
            ;;
        login)
            github_login
            ;;
        all)
            build_image
            echo ""
            push_image
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

# Dockerfileの存在確認
if [ ! -f "Dockerfile" ]; then
    log_error "Dockerfileが見つかりません"
    exit 1
fi

# Dockerの実行確認
if ! command -v docker >/dev/null 2>&1; then
    log_error "Dockerがインストールされていません"
    exit 1
fi

# Dockerデーモンの確認
if ! docker info >/dev/null 2>&1; then
    log_error "Dockerデーモンが実行されていません"
    exit 1
fi

# メイン処理実行
main "$@"
