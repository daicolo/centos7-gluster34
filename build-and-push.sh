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

# 設定
REGISTRY="ghcr.io"
NAMESPACE="daicolo"
IMAGE_NAME="centos7-gluster34"
TAG="v0.1-20250731"
FULL_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${TAG}"

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
    echo -e "${CYAN}イメージ情報:${NC}"
    echo "  レジストリ: ${REGISTRY}"
    echo "  イメージ名: ${FULL_IMAGE_NAME}"
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
    log_info "イメージ名: ${FULL_IMAGE_NAME}"
    
    # ローカルタグも作成
    docker build -t ${IMAGE_NAME}:${TAG} -t ${FULL_IMAGE_NAME} .
    
    if [ $? -eq 0 ]; then
        log_success "ビルドが完了しました"
        
        # イメージサイズを表示
        echo ""
        log_info "ビルド済みイメージ:"
        docker images | grep -E "(${IMAGE_NAME}|${NAMESPACE}/${IMAGE_NAME})" | head -5
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
    
    # push実行
    docker push ${FULL_IMAGE_NAME}
    
    if [ $? -eq 0 ]; then
        log_success "pushが完了しました"
        echo ""
        log_info "イメージURL: https://github.com/${NAMESPACE}/${IMAGE_NAME}/pkgs/container/${IMAGE_NAME}"
        log_info "pull コマンド: docker pull ${FULL_IMAGE_NAME}"
    else
        log_error "pushに失敗しました"
        log_warning "ログインしていることを確認してください: ./build-and-push.sh login"
        exit 1
    fi
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
