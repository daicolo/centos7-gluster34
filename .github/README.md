# GitHub Actions Workflows

このプロジェクトでは、以下のGitHub Actionsワークフローが設定されています：

## 1. Docker Build and Push (Production)

**ファイル**: `.github/workflows/docker-build-push.yml`

**トリガー**:
- `v*` パターンのタグがプッシュされた時（例：`v1.0.0`, `v2.1.3`）

**実行内容**:
- Docker BuildKitを使用してイメージをビルド
- GitHub Container Registry (GHCR) にプッシュ
- タグ付け：`v1.0.0` と `latest` の両方
- BuildKitキャッシュを使用して高速化

**使用方法**:
```bash
# リリースタグを作成してプッシュ
git tag v1.0.0
git push origin v1.0.0

# ワークフローが自動実行される
```

## 2. Test Build (Development)

**ファイル**: `.github/workflows/test-build.yml`

**トリガー**:
- Pull Requestが作成・更新された時
- `main`以外のブランチにプッシュされた時

**実行内容**:
- Docker BuildKitを使用してテストビルド
- コンテナが正常に起動するかテスト
- GlusterFSサービスの動作確認
- レジストリへのプッシュは行わない

## 必要なシークレット

以下のシークレットをGitHubリポジトリに設定してください：

- `GITHUB_TOKEN`: 自動的に提供されるため設定不要
- GitHub Container Registryへのプッシュ権限は自動的に付与されます

## ワークフローの監視

1. リポジトリの「Actions」タブでワークフローの実行状況を確認
2. 失敗した場合はログを確認してエラーを特定
3. 成功した場合はGHCRでイメージが利用可能

## BuildKitキャッシュ

両方のワークフローでBuildKitキャッシュを活用：
- 初回ビルド：約5-10分
- キャッシュ有効時：約2-3分

キャッシュは30日間保持されます。
