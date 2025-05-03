#!/bin/bash
# 📋 port_log.sh — 실행 중인 PostgreSQL 컨테이너 포트 현황 정리

source "$(dirname "$0")/env.sh"

# 📁 기본 Desktop 경로 (native Linux)
DESKTOP_PATH="$HOME/Desktop"

# WSL 감지 → Windows Desktop 경로로 변경
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
  DESKTOP_PATH="/mnt/c/Users/$USER/Desktop"
fi

# 출력 경로 설정
OUTPUT_FILE="$DESKTOP_PATH/current_ports.txt"

# Desktop 경로 없으면 → /tmp fallback
if [ ! -d "$DESKTOP_PATH" ]; then
  OUTPUT_FILE="/tmp/current_ports.txt"
  echo "⚠️ Desktop 경로가 없으므로 /tmp/current_ports.txt에 저장했습니다." | tee -a "$ERR_LOG" >&2
fi

# 📥 컨테이너 포트 정보 수집
ALL=$(docker ps --format '{{.Names}} {{.Ports}}' | grep --color=never '->5432')

if [ -z "$ALL" ]; then
  echo "⛔ 실행 중인 PostgreSQL 컨테이너가 없습니다." > "$OUTPUT_FILE"
  exit 0
fi

# 🔍 분류 초기화
LATEST_DB=""
LOCAL_BACKUP_DB=""
OTHER_CONTAINERS=""

while read -r line; do
  NAME=$(echo "$line" | awk '{print $1}')
  PORT=$(echo "$line" | sed -E 's/.* ([0-9]+)->5432.*/\1/' || true)

  if [ -z "$PORT" ]; then
    continue
  fi

  if [[ "$PORT" == "$PORT_CUR" || "$PORT" == "$PORT_BAK1" || "$PORT" == "$PORT_BAK2" ]]; then
    LATEST_DB+="$NAME | 0.0.0.0:$PORT->5432"$'\n'

  elif [ "$PORT" -ge 9000 ] && [ "$PORT" -le 9999 ]; then
    LOCAL_BACKUP_DB+="$NAME | 0.0.0.0:$PORT->5432"$'\n'

  else
    OTHER_CONTAINERS+="$NAME | 0.0.0.0:$PORT->????"$'\n'
  fi
done <<< "$ALL"

# 📤 저장
{
  echo "📦 Docker Port Mapping Summary"
  echo "[Generated: $(date '+%Y-%m-%d %H:%M')]"
  echo ""
  echo "📦 latest db (6543~6545)"
  echo -n "$LATEST_DB"
  echo ""
  echo "💾 local backup db (9000~9999)"
  echo -n "$LOCAL_BACKUP_DB"
  echo ""
  echo "📦 other containers (non-db or dev use)"
  echo -n "$OTHER_CONTAINERS"
} > "$OUTPUT_FILE"
