#!/bin/bash
# 🧪 error_checklist.sh — run_db.sh 실행 전 필수 오류 점검

source "$(dirname "$0")/env.sh"

echo "🔍 시스템 점검 시작 중..."

if [ -f "$LOCK_FILE" ]; then
  echo "🔒 다른 프로세스가 실행 중입니다." >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'echo "⚠️ 강제 종료 감지. 안전 종료합니다." >&2; rm -f "$LOCK_FILE"; exit 1' ERR SIGHUP SIGINT SIGTERM

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker 미실행 상태. Docker Desktop 실행 후 다시 시도하세요." | tee -a "$ERR_LOG" >&2
  exit 1
fi

if [ ! -d "$BASE" ]; then
  echo "❌ $BASE 경로 없음. SSD 마운트 또는 심볼릭 링크 확인 필요." | tee -a "$ERR_LOG" >&2
  echo "👉 현재 /mnt/wsl 내 구성:"
  ls -al /mnt/wsl
  exit 1
fi

REAL_PATH=$(readlink -f "$BASE")
if [[ "$REAL_PATH" != *PHYSICALDRIVE* && "$REAL_PATH" != *nvme* ]]; then
  echo "⚠️ 심볼릭 링크가 PHYSICALDRIVE 또는 nvme 기반이 아닐 수 있습니다: $REAL_PATH" | tee -a "$ERR_LOG"
fi

touch "$BASE/.check_writeable" 2>/dev/null
if [ ! -f "$BASE/.check_writeable" ]; then
  echo "❌ $BASE에 쓰기 불가. 디스크 권한 확인 필요." | tee -a "$ERR_LOG" >&2
  exit 1
fi
rm -f "$BASE/.check_writeable"

for dir in docker db dl_fx scripts logs; do
  mkdir -p "$BASE/$dir"
done

[ ! -f "$PORT_FILE" ] && echo 9999 > "$PORT_FILE"
[ ! -f "$VERSION_JSON" ] && echo '{ "v1.00": "db_v1.00", "수정사항": "create new db" }' > "$VERSION_JSON"
[ ! -f "$ALL_SQL" ] && touch "$ALL_SQL"

if ! docker ps >/dev/null 2>&1; then
  echo "❌ Docker 명령어 실패 (docker ps). Docker 설치 또는 권한 확인." | tee -a "$ERR_LOG" >&2
  exit 1
fi

for port in $PORT_CUR $PORT_BAK1 $PORT_BAK2; do
  output=$(docker ps -a --format '{{.Names}} {{.Status}} {{.Ports}}' | grep "$port->5432")
  if [[ "$output" == *"Exited"* || "$output" == *"Dead"* ]]; then
    name=$(echo "$output" | awk '{print $1}')
    echo "⚠️ 죽은 컨테이너 감지 ($port): $name"

    read -p "🔄 $name 컨테이너를 포트 재할당할까요? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      for new_port in $(seq 1001 1999); do
        # 🟢 lsof 없으면 ss로 fallback
        if command -v lsof >/dev/null 2>&1; then
          port_check=$(lsof -i ":$new_port")
        else
          port_check=$(ss -tulwn sport = :$new_port)
        fi
        if [ -z "$port_check" ]; then
          docker rename "$name" "${name}_old"
          docker commit "${name}_old" "${name}_image"
          docker rm -f "$name"
          docker run -d --restart unless-stopped --name "$name" -p "$new_port:5432" "${name}_image"
          echo "✅ $name → 포트 $new_port 재할당 완료"
          break
        fi
      done
    else
      echo "⛔ 실행 불가. $port 포트 점유 컨테이너 제거 필요." | tee -a "$ERR_LOG" >&2
      exit 1
    fi
  fi
done

# 🟢 df -P 옵션 추가 (POSIX, native linux 안전)
USAGE=$(df -P "$BASE" | awk 'NR==2 {gsub("%",""); print $5}')
if [ "$USAGE" -ge 95 ]; then
  echo "⚠️ 경고: 현재 $BASE 디스크 사용률이 ${USAGE}%입니다. 저장 공간이 부족합니다." | tee -a "$ERR_LOG" >&2
  echo "👉 용량 확보를 위해 백업 컨테이너 정리 또는 외부 이동을 고려하세요."
fi

MAX_RETRY=3
RETRY=0
while [[ $RETRY -lt $MAX_RETRY ]]; do
  if docker pull "$PG_IMAGE" >/dev/null 2>&1; then
    echo "✅ Docker 이미지 준비 완료 ($PG_IMAGE)"
    break
  fi
  ((RETRY++))
  echo "🔁 이미지 pull 재시도 중 ($RETRY/$MAX_RETRY)..."
  sleep 2
done

if [[ $RETRY -eq $MAX_RETRY ]]; then
  echo "❌ 이미지 pull 실패 ($PG_IMAGE). 네트워크 또는 인증 상태 확인." | tee -a "$ERR_LOG" >&2
  echo "👉 필요 시 직접 docker pull $PG_IMAGE 실행 후 다시 시도하세요." | tee -a "$ERR_LOG"
  exit 1
fi

echo "✅ 모든 사전 점검 완료!"
exit 0
