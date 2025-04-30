# 📦 PostgreSQL_PVMT

**PostgreSQL Portable Version Management Toolkit**

SSD 기반의 PostgreSQL 컨테이너를 간편하게 관리하고,  
클라우드 없이 강력한 자동 버전 관리 및 백업 시스템을 제공합니다.

---

## 🚀 What is it?

이 프로젝트는 Linux 초보자부터 고급 사용자까지 누구나 쉽게 사용할 수 있도록 설계된  
**Docker + WSL 기반 PostgreSQL 버전 관리 및 자동화 시스템**입니다.

### 주요 기능:
- 🔄 SSD 기반의 간편한 컨테이너 이동성
- 📁 체계적인 컨테이너 및 버전 관리
- 🛡️ 강력한 오류 방지 및 복구 기능
- 🗃️ 자동화된 버전 기록 및 Schema 변화 분류 저장
- 🖥️ 직관적인 포트 상태 시각화 및 관리

---

## 📌 Table of Contents

- [Main Features](#-main-features)
- [Installation](#-installation)
- [Initial Setup](#-initial-setup)
- [Quick Start Guide](#-quick-start-guide)
- [Detailed Functional Description](docs/full_functionality.txt)
- [Examples and Outputs](docs/examples_and_outputs.txt)
- [Warnings](#-warnings)

---

## 📦 Main Features

- **버전 자동 관리**
  - Schema 변경 감지 및 diff 저장
  - 변경 내용 분류 저장 (`classified_diff.sql`)
  - 변경 SQL 누적 기록 (`all_change.sql`)
  - 버전 기록 JSON 자동 업데이트 (`version.json`)

- **포터블 컨테이너 관리**
  - SSD ↔ 로컬 자동 동기화
  - Docker 복사 및 실행 자동화

- **오류 방지 및 복구 시스템**
  - 환경 점검 스크립트 (`error_checklist.sh`)
  - 포트 충돌 감지 및 자동 재할당
  - 저장 공간 부족 경고 (95% 이상 시)

- **포트 상태 시각화**
  - 현재 상태를 바탕화면에 출력 (`current_ports.txt`)

---

## 🛠️ Installation

```bash
git clone https://github.com/papa-channy/PostgreSQL_PVMT.git

## Initial Setup

```bash
bash scripts/req_set.sh      # 디렉토리 및 권한 초기화
bash scripts/fstab_auto.sh   # SSD 자동 마운트 설정
```

자세한 초기 설정: [docs/full_functionality.txt](docs/full_functionality.txt)

---

## 🚩 Quick Start Guide

```bash
bash scripts/run_db.sh           # 전체 시스템 실행
bash scripts/run_db.sh --quiet   # 경량 모드 실행
bash scripts/port_log.sh         # 현재 포트 상태 확인
```

---

## 📑 Detailed Functional Description

전체 구조, 각 스크립트의 역할 및 동작 방식은 다음 파일을 확인하세요:

[docs/full_functionality.txt](docs/full_functionality.txt)

---

## 📊 Examples and Outputs

스크립트 실행 결과 및 출력물 예시는 다음 파일에서 확인하세요:

[docs/examples_and_outputs.txt](docs/examples_and_outputs.txt)

---

## ⚠️ Warnings

- SSD는 반드시 ext4로 포맷 후 /mnt/wsl/ 에 마운트되어야 합니다.
- Docker 데몬이 항상 실행되어 있어야 합니다.
- 강제 종료나 SSD 분리 시 시스템이 손상될 수 있으니 안전하게 마운트를 해제하세요.

---

## 🤝 Contributing

이슈, 기능 제안, 문서화 등 모든 기여를 환영합니다.  
[Issue 페이지](https://github.com/papa-channy/PostgreSQL_PVMT/issues) 또는 PR로 참여해주세요.

---

## ✉️ Getting Help

문제가 생기면 [Issue 페이지](https://github.com/papa-channy/PostgreSQL_PVMT/issues)를 이용해주세요.