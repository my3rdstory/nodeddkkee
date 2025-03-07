#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - Electrs 설치
# 작성자: DedSec
# 엑스: https://x.com/_orangepillkr
# 유튜브: https://www.youtube.com/@orangepillkr/
# 스페셜땡쓰: 셀프카스타드님 https://florentine-porkpie-563.notion.site/2e905cab90ae4a979711ec40bbb85d64?v=7c329be91bd44a03928fcfa3ed4c3fe4
# 라이선스: 없음
# 주의: 저는 코딩 못합니다. 커서 조져서 대충 만든거에요. 제 오드로이드 H4 기기에서만 테스트했습니다. 다른 기기에서 동작을 보장하지 않습니다. 수정 요청하지 마시고 포크해서 마음껏 사용하세요. 

# 오류 처리 함수 정의
error_exit() {
    echo "오류: $1" >&2
    exit 1
}

# 환경 변수 로드 및 검증
if [ -f "nodeddkkee_env.sh" ]; then
    source nodeddkkee_env.sh
    # 필수 환경 변수 검증
    if [ -z "$USER_NAME" ]; then
        error_exit "USER_NAME 환경 변수가 설정되지 않았습니다."
    fi
    if [ -z "$RPC_PASSWORD" ]; then
        error_exit "RPC_PASSWORD 환경 변수가 설정되지 않았습니다."
    fi
else
    error_exit "환경 변수 파일(nodeddkkee_env.sh)을 찾을 수 없습니다. 0_check.sh를 먼저 실행해주세요."
fi

# 스크립트 실행 시작 메시지
echo "Electrs 설치 스크립트를 시작합니다..."
echo "사용자 계정: ${USER_NAME}"

# 필요한 패키지 설치
echo "Electrs 의존성 패키지 설치 중..."
sudo apt-get update
sudo apt-get install -y clang cmake build-essential cargo libssl-dev gpg || error_exit "의존성 패키지 설치에 실패했습니다."

# PGP 키 가져오기
echo "Roman Zeyde의 PGP 키 가져오기 중..."
curl -s https://romanzey.de/pgp.txt | gpg --import || error_exit "PGP 키 가져오기에 실패했습니다."

# Rust 설치 (없는 경우)
if ! command -v cargo &> /dev/null; then
    echo "Rust 설치 중..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

# Electrs 디렉토리 생성
ELECTRS_DIR="/home/${USER_NAME}/electrs"
ELECTRS_DATA_DIR="${ELECTRS_DIR}/data"
ELECTRS_CONF_DIR="${ELECTRS_DIR}/config"
ELECTRS_LOG_DIR="${ELECTRS_DIR}/logs"

echo "Electrs 디렉토리 생성 중..."
mkdir -p ${ELECTRS_DIR} ${ELECTRS_DATA_DIR} ${ELECTRS_CONF_DIR} ${ELECTRS_LOG_DIR} || error_exit "Electrs 디렉토리 생성에 실패했습니다."

# Electrs 소스 다운로드 및 빌드
echo "Electrs 소스 다운로드 및 빌드 중..."
cd ~/downloads || error_exit "다운로드 디렉토리로 이동할 수 없습니다."
git clone https://github.com/romanz/electrs.git || error_exit "Electrs 소스 다운로드에 실패했습니다."
cd electrs || error_exit "Electrs 디렉토리로 이동할 수 없습니다."

# 최신 태그 확인 및 서명 검증
git fetch --tags
LATEST_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
echo "최신 버전 ${LATEST_TAG} 검증 중..."
git verify-tag ${LATEST_TAG} || error_exit "태그 서명 검증에 실패했습니다."
git checkout ${LATEST_TAG} || error_exit "태그 체크아웃에 실패했습니다."

cargo build --release || error_exit "Electrs 빌드에 실패했습니다."

# 버전 확인
echo "Electrs 버전 확인 중..."
./target/release/electrs --version || error_exit "Electrs 버전 확인에 실패했습니다."

# 바이너리 설치
echo "Electrs 바이너리 설치 중..."
sudo install -m 0755 -o root -g root -t /usr/local/bin target/release/electrs || error_exit "Electrs 바이너리 설치에 실패했습니다."

# Electrs 설정 파일 생성
echo "Electrs 설정 파일 생성 중..."
cat > ${ELECTRS_CONF_DIR}/electrs.conf << EOF || error_exit "Electrs 설정 파일 생성에 실패했습니다."
# Electrs 설정 파일

# Bitcoin Core 연결 설정
network = "bitcoin"
daemon_dir = "/home/${USER_NAME}/.bitcoin"
daemon_rpc_addr = "127.0.0.1:8332"
daemon_p2p_addr = "127.0.0.1:8333"

# 서버 설정
electrum_rpc_addr = "127.0.0.1:50001"
db_dir = "${ELECTRS_DATA_DIR}"

# 인증 설정
auth = "${USER_NAME}:${RPC_PASSWORD}"

# 로깅 설정
log_filters = "INFO"
EOF

# 소유권 설정
echo "Electrs 디렉토리 소유권 설정 중..."
sudo chown -R ${USER_NAME}:${USER_NAME} ${ELECTRS_DIR} || error_exit "Electrs 디렉토리 소유권 설정에 실패했습니다."

# Electrs 서비스 파일 생성
echo "Electrs 서비스 파일 생성 중..."
sudo tee /etc/systemd/system/electrs.service > /dev/null << EOF || error_exit "Electrs 서비스 파일 생성에 실패했습니다."
[Unit]
Description=Electrs
After=bitcoind.service
Requires=bitcoind.service

[Service]
WorkingDirectory=${ELECTRS_DIR}
ExecStart=/usr/local/bin/electrs --conf ${ELECTRS_CONF_DIR}/electrs.conf
User=${USER_NAME}
Group=${USER_NAME}
Type=simple
KillMode=process
TimeoutSec=180
Restart=always
RestartSec=60
Environment="RUST_BACKTRACE=1"
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화
echo "Electrs 서비스 활성화 중..."
sudo systemctl daemon-reload || error_exit "systemd 데몬 리로드에 실패했습니다."
sudo systemctl enable electrs || error_exit "Electrs 서비스 활성화에 실패했습니다."

# 서비스 시작
echo "Electrs 서비스 시작 중..."
sudo systemctl start electrs || error_exit "Electrs 서비스 시작에 실패했습니다."

# 프로세스 상태 확인
echo "Electrs 프로세스 상태 확인 중..."
ps aux | grep electrs || error_exit "Electrs 프로세스 확인에 실패했습니다."

# 서비스 상태 확인
echo "Electrs 서비스 상태 확인 중..."
if ! sudo systemctl status electrs --no-pager; then
    echo "경고: Electrs 서비스가 정상적으로 시작되지 않았을 수 있습니다. 로그를 확인해주세요: journalctl -u electrs -n 50"
fi

echo "Electrs 설치가 완료되었습니다."
echo "Electrum 클라이언트에서 다음 서버를 추가할 수 있습니다:"
echo "  - TCP: $(hostname -I | awk '{print $1}'):50001"
