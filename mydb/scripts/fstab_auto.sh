#!/bin/bash
# 🪛 fstab_auto.sh — ext4 디스크 자동 마운트 설정 (WSL2 전용)

# ⬇️ 공용 환경 변수
source "$(dirname "$0")/env.sh"

echo "🔐 관리자 권한이 필요합니다. 비밀번호를 1회 입력해주세요."
sleep 0.5

# 🔒 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'echo "⚠️ 종료됨. 설정 취소."; rm -f "$LOCK_FILE"; exit 1' INT TERM EXIT

# 1️⃣ ext4 UUID 리스트 추출
UUIDS=($(blkid -t TYPE=ext4 -s UUID -o value))
if [ ${#UUIDS[@]} -eq 0 ]; then
  echo "⛔ ext4 디스크를 찾을 수 없습니다. SSD 포맷 상태를 확인하세요." | tee -a "$ERR_LOG" >&2
  exit 1
fi

# 2️⃣ UUID 선택 (복수일 경우)
if [ ${#UUIDS[@]} -gt 1 ]; then
  echo "🔍 여러 ext4 디스크 감지됨. 마운트할 디스크를 선택하세요:"
  select uuid in "${UUIDS[@]}"; do
    [ -n "$uuid" ] && UUID="$uuid" && break
  done
else
  UUID="${UUIDS[0]}"
  echo "✅ 자동 선택된 UUID: $UUID"
fi

# 3️⃣ 마운트 대상 디렉토리 생성
if [ ! -d "$BASE" ]; then
  echo "📁 $BASE 디렉토리가 없어서 생성합니다."
  sudo mkdir -p "$BASE"
fi

# 4️⃣ /etc/fstab에 UUID 추가
FSTAB_LINE="UUID=$UUID $BASE ext4 defaults,metadata 0 0"
if ! grep -Fxq "$FSTAB_LINE" /etc/fstab; then
  echo "➕ fstab에 항목 추가 중..."
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
else
  echo "✅ fstab에 이미 등록된 UUID입니다."
fi

# 5️⃣ /etc/wsl.conf 설정
if ! grep -q "mountFsTab" /etc/wsl.conf; then
  echo "➕ wsl.conf 설정 추가 중..."
  echo -e "\n[automount]\nenabled=true\nmountFsTab=true" | sudo tee -a /etc/wsl.conf > /dev/null
else
  echo "✅ /etc/wsl.conf에 mountFsTab 설정이 이미 존재합니다."
fi

# 6️⃣ mount -a 실행
echo "🔄 mount -a로 마운트 테스트 실행 중..."
if sudo mount -a; then
  echo "✅ 마운트 성공! $BASE 경로 사용 가능."
else
  echo "⚠️ mount -a 실패! 수동 마운트 또는 fstab 설정을 다시 확인하세요." | tee -a "$ERR_LOG" >&2
fi

# 🔚 종료
rm -f "$LOCK_FILE"
echo ""
echo "✅ 자동 마운트 설정 완료!"
echo "🔄 적용하려면 다음 명령도 사용 가능합니다:"
echo "    wsl --shutdown"
