#!/bin/bash
# 🧠 PostgreSQL schema 비교 후 버전 기록 자동 관리 + diff 분류 저장

source "$(dirname "$0")/env.sh"

# 🔒 중복 실행 방지
if [ -f "$LOCK_FILE" ]; then
  echo "🔒 이미 실행 중입니다. ($LOCK_FILE 존재)" >&2
  exit 1
fi

touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# ✅ 명령어 사전 확인
if ! command -v pg_dump >/dev/null 2>&1; then
  echo "❌ pg_dump 명령어를 찾을 수 없습니다. postgresql-client 설치 필요." | tee -a "$ERR_LOG" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq 명령어를 찾을 수 없습니다. jq 설치 필요." | tee -a "$ERR_LOG" >&2
  exit 1
fi

CON_NEW="db_v_current"
CON_OLD="db_v_previous"

mkdir -p "$LOGS"
[ ! -f "$VERSION_JSON" ] && echo '{ "v1.00": "db_v1.00", "수정사항": "create new db" }' > "$VERSION_JSON"
[ ! -f "$ALL_SQL" ] && touch "$ALL_SQL"

latest_ver=$(jq -r 'keys[]' "$VERSION_JSON" | sort -V | tail -n1)
major=${latest_ver:1:1}
minor=${latest_ver:3:2}
new_minor=$(printf "%02d" $((10#$minor + 1)))
new_ver="v${major}.${new_minor}"
new_name="db_${new_ver}"
TMP_SQL="$LOGS/diff_${new_ver}.sql"
CLASSIFIED_SQL="$LOGS/classified_diff.sql"

echo "📘 Current version: $latest_ver → New: $new_ver"
read -p "📝 이번 변경 설명 (예: 인덱스 추가, 타입 수정): " NOTE

# 🔐 pg_dump 실행
PGOPTIONS='--client-min-messages=warning'
pg_dump -U $DB_USER -h localhost -p $PORT_CUR $DB_NAME --schema-only \
  | grep -v '^--' | grep -v '^SET' > /tmp/new.sql 2>> "$ERR_LOG"
pg_dump -U $DB_USER -h localhost -p $PORT_BAK1 $DB_NAME --schema-only \
  | grep -v '^--' | grep -v '^SET' > /tmp/old.sql 2>> "$ERR_LOG"

if [ ! -s /tmp/new.sql ] || [ ! -s /tmp/old.sql ]; then
  echo "❌ pg_dump 실패. .pgpass 설정 또는 컨테이너 상태 확인 필요." | tee -a "$ERR_LOG" >&2
  rm -f /tmp/new.sql /tmp/old.sql
  exit 1
fi

diff_output=$(diff -u /tmp/old.sql /tmp/new.sql)

if [ -z "$diff_output" ]; then
  echo "✅ 구조 변화 없음. 버전 업데이트 생략."
  rm -f /tmp/new.sql /tmp/old.sql
  exit 0
fi

# ✅ 원본 diff 저장
echo "$diff_output" > "$TMP_SQL"
cat "$TMP_SQL" >> "$ALL_SQL"
echo "🗃️  차이 저장됨: $TMP_SQL"

# ✅ 분류된 diff 생성 → classified_diff.sql
echo "-- 📋 Version diff classified for tracking" > "$CLASSIFIED_SQL"
echo "-- Generated: $(date '+%Y-%m-%d %H:%M')" >> "$CLASSIFIED_SQL"
echo "" >> "$CLASSIFIED_SQL"

grep '^[-+]' "$TMP_SQL" | awk '
  /CREATE INDEX|DROP INDEX/     {print "-- INDEX\n" $0; next}
  /ALTER TABLE/                 {print "-- TABLE\n" $0; next}
  /CREATE TYPE|ALTER TYPE/      {print "-- TYPE\n" $0; next}
  /CONSTRAINT/                  {print "-- CONSTRAINT\n" $0; next}
  {print "-- OTHER\n" $0}
' >> "$CLASSIFIED_SQL"

# ✅ version.json 업데이트
jq --arg v "$new_ver" --arg n "$new_name" --arg d "$(date '+%Y-%m-%d %H:%M')" --arg note "$NOTE" \
  '. + {($v): $n, ($v + "_note"): $note, ($v + "_date"): $d}' "$VERSION_JSON" \
  > "$VERSION_JSON.tmp" && mv "$VERSION_JSON.tmp" "$VERSION_JSON"

# ✅ diff 파일 5개만 유지
ls -t "$LOGS"/diff_v*.sql | tail -n +6 | xargs -r rm -f

rm -f /tmp/new.sql /tmp/old.sql
echo "✅ $new_ver 버전으로 업데이트 완료. 분류 기록도 생성됨."
