#!/bin/bash
# ⚙️ 최초 환경 구성 스크립트 (최초 1회 실행)

source "$(dirname "$0")/env.sh"

echo "🔐 관리자 권한이 필요합니다. 비밀번호를 1회 입력해주세요."
sleep 0.5

if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'echo "⚠️ 설정 중단됨. 롤백 처리 중..."; rm -f "$LOCK_FILE"' INT TERM EXIT

# 🟢 WSL 여부 감지 → BASE/TARGET 구분
if [[ "$OSTYPE" == "linux-gnu" && -d "/mnt/wsl" ]]; then
  echo "🟢 WSL 환경 감지됨"
  BASE="/mnt/wsl/mydb"
  TARGET=$(find /mnt/wsl -maxdepth 1 -type d -name "PHYSICALDRIVE*p1" | head -n 1)
  if [ -z "$TARGET" ]; then
    echo "⛔ SSD 디스크가 마운트되지 않았거나 ext4 포맷이 아닙니다." | tee -a "$ERR_LOG" >&2
    rm -f "$LOCK_FILE"
    exit 1
  fi
  if [ ! -L "$BASE" ]; then
    echo "🔗 심볼릭 링크 없음. 자동 생성 시도 중..."
    sudo ln -sf "$TARGET" "$BASE"
    if [ $? -ne 0 ]; then
      echo "❌ 심볼릭 링크 생성 실패. 관리자 권한 또는 경로 오류." | tee -a "$ERR_LOG" >&2
      rm -f "$LOCK_FILE"
      exit 1
    fi
    echo "✅ 링크 생성 완료: $BASE → $TARGET"
  else
    echo "✅ 심볼릭 링크 이미 존재: $BASE"
  fi
else
  echo "🟢 native Linux 환경 감지됨 → 심볼릭 링크 단계 생략"
  BASE="/mnt/mydb"
fi

echo "📁 필수 디렉토리 생성 중..."
for dir in db docker logs scripts dl_fx; do
  sudo mkdir -p "$BASE/$dir"
done

echo "🔧 권한 설정 중..."
sudo chown -R "$USER:$USER" "$BASE"
sudo chmod -R u+rwX "$BASE"

echo "🗂️ 필수 파일 생성 중..."
[ ! -f "$VERSION_JSON" ] && echo '{"v1.00": "db_v1.00", "수정사항": "create new db"}' > "$VERSION_JSON"
[ ! -f "$ALL_SQL" ] && touch "$ALL_SQL"
[ ! -f "$PORT_FILE" ] && echo "9999" > "$PORT_FILE"
[ -f "$SCRIPTS/run_db.lock" ] && rm -f "$SCRIPTS/run_db.lock"

echo ""
echo "ℹ️ 다음 alias가 .bashrc에 자동 추가됩니다:"
echo "    alias rundb='bash $SCRIPTS/run_db.sh'"
echo "    alias quickdb='bash $SCRIPTS/run_db.sh --quiet'"
echo "    alias checkport='bash $SCRIPTS/port_log.sh'"

# ✅ alias 자동 추가
{
  echo ""
  echo "# PostgreSQL_PVMT aliases"
  echo "alias rundb='bash $SCRIPTS/run_db.sh'"
  echo "alias quickdb='bash $SCRIPTS/run_db.sh --quiet'"
  echo "alias checkport='bash $SCRIPTS/port_log.sh'"
} >> ~/.bashrc

echo "✅ alias가 ~/.bashrc에 추가되었습니다. (source ~/.bashrc 실행 필요)"

rm -f "$LOCK_FILE"
echo ""
echo "✅ req_set.sh 실행 완료 — 환경 초기화 성공!"
