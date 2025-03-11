#!/bin/bash

# root 권한 체크 및 실제 사용자 확인
if [ "$(id -u)" != "0" ]; then
    echo "이 스크립트는 root 권한으로 실행해야 합니다."
    echo "다음 명령어로 다시 실행하세요: sudo $0"
    exit 1
fi

# 실제 사용자 확인
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(logname 2>/dev/null || echo $USER)
fi

# 사용자 이름 설정
USER_NAME=$REAL_USER
USER_HOME="/home/${USER_NAME}"

# Electrs 버전 설정
ELECTRS_VERSION="0.10.9"
ELECTRS_DIR="${USER_HOME}/electrs"
ELECTRS_BINARY="${ELECTRS_DIR}/target/release/electrs"
ELECTRS_BACKUP_DIR="${USER_HOME}/.electrs/backup"

# error_exit 함수 정의
error_exit() {
    echo "오류: $1" >&2
    exit 1
}

# 권한 관련 헬퍼 함수 정의
run_as_user() {
    su - ${USER_NAME} -c "$1"
}

# bitcoind 실행 상태 확인
echo "Bitcoin Core 실행 상태 확인 중..."
if ! systemctl is-active --quiet bitcoind; then
    error_exit "bitcoind가 실행 중이어야 합니다. 비트코인 노드를 먼저 설정하세요."
fi

# 방화벽 설정 및 확인
echo "방화벽 설정 중..."

# 포트 상태 초기 확인
echo "포트 상태 확인 중..."
PORT_PID=$(lsof -t -i :50001 2>/dev/null)
if [ -n "$PORT_PID" ]; then
    PROCESS_NAME=$(ps -p $PORT_PID -o comm=)
    echo "포트 50001이 $PROCESS_NAME(PID: $PORT_PID)에 의해 사용 중입니다. 자동으로 종료합니다..."
    kill $PORT_PID
    sleep 2
    if lsof -i :50001 > /dev/null; then
        echo "프로세스 강제 종료 중..."
        kill -9 $PORT_PID
        sleep 1
    fi
    if lsof -i :50001 > /dev/null; then
        error_exit "포트 50001을 해제할 수 없습니다. 수동으로 확인이 필요합니다."
    fi
    echo "포트 50001이 해제되었습니다."
fi

# UFW 설정
if command -v ufw >/dev/null 2>&1; then
    echo "UFW 방화벽 설정 중..."
    
    # UFW 상태 확인 및 활성화
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "UFW 활성화 중..."
        sudo ufw --force enable
    fi
    
    # 포트 규칙 추가
    sudo ufw allow 50001/tcp
    sudo ufw --force reload
    
    echo "UFW 규칙 확인:"
    sudo ufw status | grep 50001 || echo "UFW 규칙이 없습니다."
else
    error_exit "UFW가 설치되어 있지 않습니다. 'apt-get install ufw' 명령어로 설치하세요."
fi

# 기존 Electrs 프로세스 종료
echo "기존 Electrs 프로세스 정리 중..."
if systemctl is-active --quiet electrs; then
    echo "Electrs 서비스 중지 및 비활성화 중..."
    sudo systemctl stop electrs
    sudo systemctl disable electrs
    sleep 5
elif pgrep electrs > /dev/null; then
    echo "Electrs 프로세스 종료 중..."
    pkill electrs
    sleep 5
fi

# 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get update
apt-get install -y clang cmake build-essential cargo git curl lsof openssl || error_exit "패키지 설치 실패"

# 백업 디렉토리 생성
mkdir -p "${ELECTRS_BACKUP_DIR}"
chown -R ${USER_NAME}:${USER_NAME} "${ELECTRS_BACKUP_DIR}"

# TLS 인증서 디렉토리 생성 및 설정
echo "TLS 인증서 생성 중..."
TLS_DIR="${USER_HOME}/.electrs/tls"
mkdir -p "$TLS_DIR"

# 자동으로 인증서 생성
openssl req -newkey rsa:2048 -nodes \
    -keyout "${TLS_DIR}/electrs.key" \
    -x509 -days 365 \
    -out "${TLS_DIR}/electrs.crt" \
    -subj "/C=KR/ST=Seoul/L=Seoul/O=Electrs/CN=localhost"

# TLS 파일 권한 설정
chown -R ${USER_NAME}:${USER_NAME} "$TLS_DIR"
chmod 600 "${TLS_DIR}/electrs.key"
chmod 644 "${TLS_DIR}/electrs.crt"

# 기존 빌드 확인
NEED_BUILD=true
BACKUP_BINARY="${ELECTRS_BACKUP_DIR}/electrs-latest"

if [ -f "$BACKUP_BINARY" ]; then
    echo "기존 빌드된 Electrs 바이너리를 발견했습니다."
    echo "백업된 바이너리를 사용합니다..."
    
    # Electrs 디렉토리 생성
    mkdir -p "${ELECTRS_DIR}/target/release"
    cp "$BACKUP_BINARY" "$ELECTRS_BINARY"
    chmod +x "$ELECTRS_BINARY"
    chown -R ${USER_NAME}:${USER_NAME} "${ELECTRS_DIR}"
    
    # 실행 가능 여부 확인
    if "${ELECTRS_BINARY}" --version &>/dev/null; then
        echo "백업된 바이너리 확인 완료"
        NEED_BUILD=false
    else
        echo "백업된 바이너리가 실행되지 않습니다. 새로 빌드합니다."
        rm -f "$ELECTRS_BINARY"
    fi
fi

if [ "$NEED_BUILD" = true ]; then
    # Electrs 소스 다운로드 및 빌드
    echo "Electrs 소스 다운로드 중..."
    if [ -d "$ELECTRS_DIR" ]; then
        rm -rf "$ELECTRS_DIR"
    fi

    # Git clone
    echo "최신 Electrs 소스코드 다운로드 중..."
    run_as_user "git clone https://github.com/romanz/electrs.git ${ELECTRS_DIR}"
    cd "$ELECTRS_DIR" || error_exit "Electrs 디렉토리로 이동 실패"

    # Rust 툴체인 설치 확인
    if ! command -v cargo &> /dev/null; then
        echo "Rust 툴체인 설치 중..."
        apt-get install -y rustc cargo || error_exit "Rust 설치 실패"
    fi

    # 빌드 환경 설정
    export CARGO_HOME="${USER_HOME}/.cargo"
    export RUSTUP_HOME="${USER_HOME}/.rustup"
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
    chown -R ${USER_NAME}:${USER_NAME} "$CARGO_HOME" "$RUSTUP_HOME"

    echo "Electrs 빌드 중..."
    if ! run_as_user "cd ${ELECTRS_DIR} && cargo build --release"; then
        error_exit "Electrs 빌드 실패"
    fi

    # 성공적으로 빌드된 바이너리 백업
    echo "빌드된 바이너리 백업 중..."
    cp "$ELECTRS_BINARY" "$BACKUP_BINARY"
    chmod +x "$BACKUP_BINARY"
    chown ${USER_NAME}:${USER_NAME} "$BACKUP_BINARY"
fi

# 설정 파일 생성
echo "Electrs 설정 파일 생성 중..."
mkdir -p "${USER_HOME}/.electrs"

# 기존 설정 파일 제거
if [ -f "${USER_HOME}/.electrs/config.toml" ]; then
    echo "기존 config.toml 파일 제거 중..."
    rm -f "${USER_HOME}/.electrs/config.toml"
fi

cat > "${USER_HOME}/.electrs/config.toml" << EOF
network = "bitcoin"
daemon_dir = "${USER_HOME}/.bitcoin"
daemon_rpc_addr = "127.0.0.1:8332"
daemon_p2p_addr = "127.0.0.1:8333"
electrum_rpc_addr = "0.0.0.0:50001"
db_dir = "${USER_HOME}/.electrs/db"
cookie = "${USER_HOME}/.bitcoin/.cookie"
tls_cert = "${USER_HOME}/.electrs/tls/electrs.crt"
tls_key = "${USER_HOME}/.electrs/tls/electrs.key"
EOF

# 권한 설정
chown -R ${USER_NAME}:${USER_NAME} "${USER_HOME}/.electrs"
chmod 750 "${USER_HOME}/.electrs"
chmod 640 "${USER_HOME}/.electrs/config.toml"

# 기존 서비스 파일 제거
if [ -f "/etc/systemd/system/electrs.service" ]; then
    echo "기존 electrs 서비스 중지 및 제거 중..."
    systemctl stop electrs
    systemctl disable electrs
    sleep 3
    rm -f "/etc/systemd/system/electrs.service"
    systemctl daemon-reload
    systemctl reset-failed
fi

# systemd 서비스 파일 생성
echo "systemd 서비스 파일 생성 중..."
cat > /etc/systemd/system/electrs.service << EOF
[Unit]
Description=Electrs
After=bitcoind.service
Requires=bitcoind.service

[Service]
WorkingDirectory=/home/${USER_NAME}/electrs
Environment="RUST_BACKTRACE=1"
ExecStart=${ELECTRS_DIR}/target/release/electrs --conf ${USER_HOME}/.electrs/config.toml --log-filters INFO
User=${USER_NAME}
Group=${USER_NAME}
Type=simple
KillMode=process
Restart=always
RestartSec=60
TimeoutSec=300
LimitNOFILE=4096

# 보안 설정
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# systemd 서비스 설정
echo "systemd 서비스 설정 중..."
systemctl daemon-reload
systemctl enable electrs
systemctl start electrs

# 서비스 및 포트 상태 확인
if [ "$SERVICE_STARTED" = "false" ]; then
    echo "서비스 상태:"
    systemctl status electrs
    echo "포트 50001 상태:"
    sudo netstat -tuln | grep 50001 || echo "포트가 사용 중이 아닙니다."
    echo "UFW 규칙:"
    sudo ufw status verbose | grep 50001
    echo "로그 확인:"
    journalctl -u electrs --no-pager | tail -n 50
    error_exit "Electrs 서비스 시작 또는 포트 열기 실패"
fi

echo "Electrs 설치가 완료되었습니다."
echo "로그 확인: journalctl -u electrs -f" 