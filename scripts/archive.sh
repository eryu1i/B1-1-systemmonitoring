#!/bin/bash
umask 0117

LOG_DIR=/var/log/agent-app
ARCHIVE_DIR=/var/log/agent-app/archive

# 디렉토리 존재 확인
if [ ! -d "$LOG_DIR" ]; then
    echo "[WARNING] 로그 디렉토리가 존재하지 않습니다: $LOG_DIR"
    exit 1
fi

if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "[WARNING] 아카이브 디렉토리가 존재하지 않습니다: $ARCHIVE_DIR"
    exit 1
fi

# 7일 이상 경과 로그 파일 찾기
FILES=$(find $LOG_DIR -maxdepth 1 -name "*.log*" -mtime +7)

if [ -z "$FILES" ]; then
    echo "[WARNING] 압축할 파일이 없습니다."
else
    for f in $FILES; do
        gzip $f
        mv ${f}.gz $ARCHIVE_DIR/
        echo "[INFO] 압축 및 이동: ${f}.gz"
    done
fi

# 30일 이상 경과 .gz 파일 삭제
OLD_FILES=$(find $ARCHIVE_DIR -name "*.gz" -mtime +30)

if [ -z "$OLD_FILES" ]; then
    echo "[WARNING] 삭제할 파일이 없습니다."
else
    for f in $OLD_FILES; do
        rm $f
        echo "[INFO] 삭제: $f"
    done
fi
