#!/bin/bash
# ⚙️ 최초 환경 구성 스크립트 (최초 1회 실행)

# ⬇️ 공용 환경 변수 로드
source "$(dirname "$0")/env.sh"

echo "🔐 관리자 권한이 필요합니다. 비밀번호를 1회 입력해주세요."
sleep 0.5

# 🔒 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'echo "⚠️ 설정 중단됨. 롤백 처리 중..."; rm -f "$LOCK_FILE"; exit 1' INT TERM EXIT

# 1️⃣ 심볼릭 링크 존재 여부 확인 및 강제 생성
if [ ! -L "$BASE" ]; then
  echo "🔗 심볼릭 링크 없음. 자동 생성 시도 중..."

  TARGET=$(find /mnt/wsl -maxdepth 1 -type d -name "PHYSICALDRIVE*p1" | head -n 1)
  if [ -z "$TARGET" ]; then
    echo "⛔ SSD 디스크가 마운트되지 않았거나 ext4 포맷이 아닙니다." | tee -a "$ERR_LOG" >&2
    exit 1
  fi

  sudo ln -sf "$TARGET" "$BASE"
  if [ $? -ne 0 ]; then
    echo "❌ 심볼릭 링크 생성 실패. 관리자 권한 또는 경로 오류." | tee -a "$ERR_LOG" >&2
    exit 1
  fi

  echo "✅ 링크 생성 완료: $BASE → $TARGET"
else
  echo "✅ 심볼릭 링크 이미 존재: $BASE"
fi

# 2️⃣ 필수 디렉토리 생성
echo "📁 필수 디렉토리 생성 중..."
for dir in db docker logs scripts dl_fx; do
  sudo mkdir -p "$BASE/$dir"
done

# 3️⃣ 권한 설정
echo "🔧 권한 설정 중..."
sudo chown -R "$USER:$USER" "$BASE"
sudo chmod -R u+rwX "$BASE"

# 4️⃣ 필수 파일 생성
echo "🗂️ 필수 파일 생성 중..."
[ ! -f "$VERSION_JSON" ] && echo '{"v1.00": "db_v1.00", "수정사항": "create new db"}' > "$VERSION_JSON"
[ ! -f "$ALL_SQL" ] && touch "$ALL_SQL"
[ ! -f "$PORT_FILE" ] && echo "9999" > "$PORT_FILE"
[ -f "$SCRIPTS/run_db.lock" ] && rm -f "$SCRIPTS/run_db.lock"

# 5️⃣ alias 안내
echo ""
echo "ℹ️ 자주 사용하는 명령어를 등록하려면 .bashrc에 다음을 추가하세요:"
echo "    alias rundb='bash $SCRIPTS/run_db.sh'"
echo "    alias quickdb='bash $SCRIPTS/run_db.sh --quiet'"
echo "    alias checkport='bash $SCRIPTS/port_log.sh'"

# 🔚 종료 처리
rm -f "$LOCK_FILE"
echo ""
echo "✅ req_set.sh 실행 완료 — 환경 초기화 성공!"
