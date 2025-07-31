@echo off
:: CentOS 7 GlusterFS 3.4 Docker Compose
:: 初回用データディレクトリ作成バッチファイル (Windows用)
:: 
:: このバッチファイルは、GlusterFSクラスター用のホストディレクトリを作成します。

setlocal enabledelayedexpansion

echo [INFO] GlusterFS データディレクトリセットアップを開始します...

:: 現在のディレクトリを取得
set "SCRIPT_DIR=%~dp0"
set "DATA_DIR=%SCRIPT_DIR%data"

echo [INFO] 作業ディレクトリ: %SCRIPT_DIR%
echo [INFO] データディレクトリ: %DATA_DIR%

:: メインのdataディレクトリを作成
if not exist "%DATA_DIR%" (
    echo [INFO] メインデータディレクトリを作成中: %DATA_DIR%
    mkdir "%DATA_DIR%"
    echo [SUCCESS] メインデータディレクトリを作成しました
) else (
    echo [WARNING] メインデータディレクトリは既に存在します: %DATA_DIR%
)

:: 各ノード用のディレクトリを作成
set nodes=node1 node2 node3 node4

for %%n in (%nodes%) do (
    set "NODE_DIR=%DATA_DIR%\%%n"
    
    if not exist "!NODE_DIR!" (
        echo [INFO] %%n のデータディレクトリを作成中: !NODE_DIR!
        mkdir "!NODE_DIR!"
        
        :: brick用のサブディレクトリも作成
        mkdir "!NODE_DIR!\brick1"
        mkdir "!NODE_DIR!\brick2"
        mkdir "!NODE_DIR!\brick3"
        
        echo [SUCCESS] %%n のディレクトリを作成しました
    ) else (
        echo [WARNING] %%n のディレクトリは既に存在します: !NODE_DIR!
        
        :: brick用のサブディレクトリが存在しない場合は作成
        for %%b in (brick1 brick2 brick3) do (
            set "BRICK_DIR=!NODE_DIR!\%%b"
            if not exist "!BRICK_DIR!" (
                echo [INFO] %%n/%%b サブディレクトリを作成中
                mkdir "!BRICK_DIR!"
            )
        )
    )
)

:: .gitignoreファイルを作成
set "GITIGNORE_FILE=%DATA_DIR%\.gitignore"
if not exist "%GITIGNORE_FILE%" (
    echo [INFO] .gitignoreファイルを作成中...
    (
        echo # GlusterFS runtime files
        echo */brick*/
        echo */.glusterfs/
        echo */lost+found/
        echo.
        echo # Temporary files
        echo *.tmp
        echo *.log
        echo *~
        echo.
        echo # OS specific files
        echo .DS_Store
        echo Thumbs.db
    ) > "%GITIGNORE_FILE%"
    echo [SUCCESS] .gitignoreファイルを作成しました
)

:: 作成されたディレクトリ構造を表示
echo.
echo [INFO] 作成されたディレクトリ構造:
dir /B "%DATA_DIR%"
echo.

for %%n in (%nodes%) do (
    echo %%n/:
    if exist "%DATA_DIR%\%%n" (
        dir /B "%DATA_DIR%\%%n"
    ) else (
        echo   (ディレクトリが存在しません)
    )
    echo.
)

:: 使用方法の表示
echo.
echo [SUCCESS] セットアップが完了しました！
echo.
echo 次のステップ:
echo 1. Docker Composeでサービスを起動:
echo    docker compose up -d
echo.
echo 2. GlusterFSクラスターを設定:
echo    ssh -p 2222 root@localhost
echo.
echo 3. ボリュームを作成する際のブリックパス例:
echo    gluster-node1:/data/brick1
echo    gluster-node2:/data/brick1
echo    gluster-node3:/data/brick1
echo    gluster-node4:/data/brick1
echo.
echo [INFO] 詳細な手順はREADME.mdを参照してください。
echo.
pause
