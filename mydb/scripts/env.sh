#!/bin/bash
# 📦 env.sh — 공용 환경 변수 설정

# 베이스 경로 (SSD 마운트된 위치)
export BASE="/mnt/wsl/mydb"

# 하위 경로
export DB="$BASE/db"
export LOGS="$BASE/logs"
export SCRIPTS="$BASE/scripts"

# 공용 파일
export PORT_FILE="$SCRIPTS/port.txt"
export VERSION_JSON="$LOGS/version.json"
export ALL_SQL="$LOGS/all_change.sql"
export ERR_LOG="$LOGS/error.log"

# 공용 LOCK 파일 (통일됨)
export LOCK_FILE="/tmp/sys.lock"

# PostgreSQL 기본 정보
export DB_USER="chan"
export DB_NAME="qa_db"
export PG_IMAGE="postgres:16"

# 주요 포트 정책
export PORT_CUR=6543
export PORT_BAK1=6544
export PORT_BAK2=6545
