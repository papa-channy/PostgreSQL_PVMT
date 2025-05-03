#!/bin/bash
# ⚙️ 최초 환경 구성 스크립트 (native Linux 전용)

source "$(dirname "$0")/env.sh"

echo "🔐 관리자 권한이 필요합니다. 비밀번호를 1회 입력해주세요."
sleep 0.5

if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'echo "⚠️ 설정 중단됨. 롤백 처리 중..."; rm -f "$LOCK_FILE"; exit 1' INT TERM EXIT

# 🟢 native Linux 환경 설정
echo "🟢 native Linux 환경 감지됨"

# BASE 경로 설정
BASE="/home/$USER/mydb"

echo "📁 BASE 디렉토리: $BASE"

# 📁 필수 디렉토리 생성
for dir in db docker logs scripts dl_fx; do
  if [ ! -d "$BASE/$dir" ]; then
    echo "📁 $BASE/$dir 생성"
    sudo mkdir -p "$BASE/$dir"
  else
    echo "✅ 이미 존재: $BASE/$dir"
  fi
done

# 🔧 권한 설정
echo "🔧 권한 설정 중..."
sudo chown -R "$USER:$USER" "$BASE"
sudo chmod -R u+rwX "$BASE"

# 🗂️ 필수 파일 생성
echo "🗂️ 필수 파일 생성 중..."
[ ! -f "$VERSION_JSON" ] && echo '{"v1.00": "db_v1.00", "수정사항": "create new db"}' > "$VERSION_JSON"
[ ! -f "$ALL_SQL" ] && touch "$ALL_SQL"
[ ! -f "$PORT_FILE" ] && echo "9999" > "$PORT_FILE"
[ -f "$SCRIPTS/run_db.lock" ] && rm -f "$SCRIPTS/run_db.lock"

# ✅ alias 추가 (중복 방지)
if ! grep -q "alias rundb=" ~/.bashrc; then
  echo ""
  echo "ℹ️ 다음 alias가 .bashrc에 자동 추가됩니다:"
  echo "    alias rundb='bash $SCRIPTS/run_db.sh'"
  echo "    alias quickdb='bash $SCRIPTS/run_db.sh --quiet'"
  echo "    alias checkport='bash $SCRIPTS/port_log.sh'"

  {
    echo ""
    echo "# PostgreSQL_PVMT aliases"
    echo "alias rundb='bash $SCRIPTS/run_db.sh'"
    echo "alias quickdb='bash $SCRIPTS/run_db.sh --quiet'"
    echo "alias checkport='bash $SCRIPTS/port_log.sh'"
  } >> ~/.bashrc

  echo "✅ alias가 ~/.bashrc에 추가되었습니다. (source ~/.bashrc 실행 필요)"
else
  echo "✅ alias가 이미 ~/.bashrc에 등록되어 있습니다."
fi

rm -f "$LOCK_FILE"
echo ""
echo "✅ req_set.sh 실행 완료 — 환경 초기화 성공!"
