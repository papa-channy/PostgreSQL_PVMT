#!/bin/bash

# 🔍 SSD 컨테이너와 로컬 PostgreSQL 컨테이너 구조 비교 후 복사 여부 판단
# 사용자가 선택한 SSD 컨테이너를 커밋 → 로컬에 run

source "$(dirname "$0")/env.sh"

if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

SSD_PORTS=($PORT_BAK2 $PORT_BAK1)  # 최신 제외
LOCAL_PORTS=($PORT_CUR $PORT_BAK1 $PORT_BAK2)

# ✅ 1. SSD 컨테이너 목록
ssd_list=()
for port in "${SSD_PORTS[@]}"; do
  con=$(docker ps -a --format '{{.Names}} {{.Ports}}' | grep -E "(${port}|\\[::\\]):${port}->5432" | awk '{print $1}')
  [ -n "$con" ] && ssd_list+=("$con")
done

# ✅ 2. 로컬 컨테이너 목록
local_list=()
for port in "${LOCAL_PORTS[@]}"; do
  con=$(docker ps -a --format '{{.Names}} {{.Ports}}' | grep -E "(${port}|\\[::\\]):${port}->5432" | awk '{print $1}')
  [ -n "$con" ] && local_list+=("$con")
done

# ✅ 3. 구조 비교 (Image ID 기준)
echo ""
echo "📦 SSD vs 로컬 컨테이너 구조 비교 시작..."
selectable_list=()
index=1

for ssd_con in "${ssd_list[@]}"; do
  is_duplicate=false

  if ! ssd_image=$(docker inspect --format='{{.Image}}' "$ssd_con" 2>/dev/null); then
    echo "❌ docker inspect 실패: $ssd_con" | tee -a "$ERR_LOG" >&2
    continue
  fi

  for local_con in "${local_list[@]}"; do
    if ! local_image=$(docker inspect --format='{{.Image}}' "$local_con" 2>/dev/null); then
      echo "❌ docker inspect 실패: $local_con" | tee -a "$ERR_LOG" >&2
      continue
    fi

    if [ "$ssd_image" == "$local_image" ]; then
      echo "✔️ 동일: SSD '$ssd_con' ≒ 로컬 '$local_con'"
      is_duplicate=true
      break
    fi
  done

  if [ "$is_duplicate" = false ]; then
    echo "❗ 미존재 SSD 컨테이너: $ssd_con"
    echo "   [$index] 선택 가능"
    selectable_list+=("$ssd_con")
    ((index++))
  fi
done

# ✅ 4. 사용자 입력
if [ ${#selectable_list[@]} -eq 0 ]; then
  echo "✅ 백업할 SSD 컨테이너가 없습니다."
  exit 0
fi

echo ""
echo "💬 백업할 SSD 컨테이너 번호를 선택하세요 (예: 1,2 또는 0)"
read -p "   ➤ 선택: " selection
selection=$(echo "$selection" | tr -d '[:space:]')

if [[ "$selection" == "0" ]]; then
  echo "❎ 선택 없음. 종료합니다."
  exit 0
fi

IFS=',' read -r -a selected_indices <<< "$selection"
for idx in "${selected_indices[@]}"; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#selectable_list[@]}" ]; then
    echo "❌ 유효하지 않은 번호: $idx" | tee -a "$ERR_LOG" >&2
    exit 1
  fi
done

# ✅ 5. 포트 + 이름 중복 처리
[ ! -f "$PORT_FILE" ] && echo 9999 > "$PORT_FILE"
next_port=$(cat "$PORT_FILE")

for idx in "${selected_indices[@]}"; do
  con_name="${selectable_list[$((idx-1))]}"
  new_name="${con_name}_bak_${next_port}"

  if docker ps -a --format '{{.Names}}' | grep -q "^$new_name$"; then
    echo "⚠️ 이름 중복: $new_name → 스킵됨" | tee -a "$ERR_LOG" >&2
    continue
  fi

  if ! docker commit "$con_name" "${con_name}_image"; then
    echo "❌ docker commit 실패: $con_name" | tee -a "$ERR_LOG" >&2
    continue
  fi

  docker run -d --restart unless-stopped --name "$new_name" -p "$next_port:5432" "${con_name}_image"

  now=$(date '+%Y-%m-%d %H:%M')
  echo "[$now] Copied SSD container $con_name → $USER@local port $next_port" >> "$LOGS/backup_log.txt"

  ((next_port--))
done

echo "$next_port" > "$PORT_FILE"

echo "✅ 선택한 SSD 컨테이너가 로컬에 백업되었습니다."
exit 0
