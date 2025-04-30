#!/bin/bash
# 📦 run_db.sh — SSD 기반 PostgreSQL 컨테이너 자동 구성 및 관리
# Author: chan + chatGPT (2025)

# ⬇️ 공통 환경 변수 불러오기
source "$(dirname "$0")/env.sh"

# ✅ --quiet 플래그 처리
QUIET=false
for arg in "$@"; do
  case $arg in
    --quiet)
      QUIET=true
      ;;
  esac
done

# 🔒 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
  $QUIET || echo "🚫 Already running: $LOCK_FILE"
  exit 1
fi

touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# 🔧 사전 오류 점검
bash "$SCRIPTS/error_checklist.sh" || exit 1

# 1️⃣ SSD 컨테이너 목록 추출
ALL_CONS=$(ls "$DB" | grep '^db_v' | sort -r)
LATEST_CON=$(echo "$ALL_CONS" | head -n 1)
BAK1_CON=$(echo "$ALL_CONS" | sed -n 2p)
BAK2_CON=$(echo "$ALL_CONS" | sed -n 3p)

$QUIET || {
  echo "🔄 SSD 컨테이너 감지:"
  echo "🆕 최신: $LATEST_CON"
  echo "📁 백업1: $BAK1_CON"
  echo "📁 백업2: $BAK2_CON"
}

# 2️⃣ 로컬 충돌 검사
$QUIET || echo "🔍 로컬 충돌 검사 및 포트 확인..."
bash "$SCRIPTS/compare_con.sh"
bash "$SCRIPTS/port_log.sh"

# 3️⃣ 사용자 선택 백업
idx=0
CHOICES=()
for con in $ALL_CONS; do
  [ "$con" = "$LATEST_CON" ] && continue
  idx=$((idx+1))
  echo "$idx) $con"
  CHOICES+=("$con")
done

echo ""
echo "💾 SSD 컨테이너 중 로컬에 백업할 항목을 선택하세요 (쉼표 구분, 없으면 0)"
read -p "👉 선택 (예: 1,2 또는 0): " SELECT
PORT_NOW=$(cat "$PORT_FILE")

# 입력 검사
if ! echo "$SELECT" | grep -Eq '^0$|^([0-9]+,)*[0-9]+$'; then
  echo "⛔ 잘못된 입력 형식" | tee -a "$ERR_LOG" >&2
  exit 1
fi

SAVE_LIST=()
if [ "$SELECT" != "0" ]; then
  for num in $(echo "$SELECT" | tr ',' ' '); do
    con="${CHOICES[$((num-1))]}"
    port=$PORT_NOW

    if [ -z "$con" ]; then
      echo "⚠️ 잘못된 번호: $num → 무시됨" >&2
      continue
    fi

    # 컨테이너 이름 중복 방지
    if docker ps -a --format '{{.Names}}' | grep -q "^$con$"; then
      echo "⚠️ 컨테이너 이름 $con 이미 존재. 건너뜁니다." | tee -a "$ERR_LOG" >&2
      continue
    fi

    docker run -d \
      --restart unless-stopped \
      --name "$con" \
      -e POSTGRES_USER=$DB_USER \
      -e POSTGRES_PASSWORD=1234 \
      -e POSTGRES_DB=$DB_NAME \
      -p "$port:5432" \
      -v "$DB/$con:/var/lib/postgresql/data" \
      $PG_IMAGE

    echo "[$(date '+%Y-%m-%d %H:%M')] Copied SSD container $con → $USER@local port $port" >> "$LOGS/backup_log.txt"
    SAVE_LIST+=("$con:$port")
    PORT_NOW=$((PORT_NOW - 1))
  done
  echo "$PORT_NOW" > "$PORT_FILE"
fi

# 4️⃣ 최신 복제
LAST_NUM=$(echo "$LATEST_CON" | grep -oP '[0-9]+\.[0-9]+$')
MAJOR=$(echo "$LAST_NUM" | cut -d. -f1)
MINOR=$(echo "$LAST_NUM" | cut -d. -f2)
MINOR=$((10#$MINOR + 1))
NEXT_VER=$(printf "db_v%d.%02d" $MAJOR $MINOR)

docker run -d \
  --restart unless-stopped \
  --name "$NEXT_VER" \
  -e POSTGRES_USER=$DB_USER \
  -e POSTGRES_PASSWORD=1234 \
  -e POSTGRES_DB=$DB_NAME \
  -p "$PORT_CUR:5432" \
  -v "$DB/$NEXT_VER:/var/lib/postgresql/data" \
  $PG_IMAGE

# 5️⃣ 이전 버전 실행
for bak in "$BAK1_CON:$PORT_BAK1" "$BAK2_CON:$PORT_BAK2"; do
  name=$(echo $bak | cut -d: -f1)
  port=$(echo $bak | cut -d: -f2)
  if [ -d "$DB/$name" ]; then
    docker run -d \
      --restart unless-stopped \
      --name "$name" \
      -e POSTGRES_USER=$DB_USER \
      -e POSTGRES_PASSWORD=1234 \
      -e POSTGRES_DB=$DB_NAME \
      -p "$port:5432" \
      -v "$DB/$name:/var/lib/postgresql/data" \
      $PG_IMAGE
  fi
done

# 6️⃣ 버전 관리
bash "$SCRIPTS/version_manage.sh" "$LATEST_CON" "$NEXT_VER"

# 7️⃣ 포트 상태 갱신
bash "$SCRIPTS/port_log.sh"

# ✅ 완료
$QUIET || {
  echo ""
  echo "✅ 모든 컨테이너 실행 완료!"
  echo "🆕 현재 작업 컨테이너: $NEXT_VER → 포트 $PORT_CUR"
  echo "📁 로컬 저장 목록: ${SAVE_LIST[*]}"
}
