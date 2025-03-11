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

# ElectrumX 설정
ELECTRUMX_DIR="${USER_HOME}/electrumx"
ELECTRUMX_VENV="${ELECTRUMX_DIR}/venv"
ELECTRUMX_BACKUP_DIR="${USER_HOME}/.electrumx/backup"

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

# 기존 ElectrumX 프로세스 종료
echo "기존 ElectrumX 프로세스 정리 중..."
if systemctl is-active --quiet electrumx; then
    echo "ElectrumX 서비스 중지 및 비활성화 중..."
    sudo systemctl stop electrumx
    sudo systemctl disable electrumx
    sleep 5
elif pgrep electrumx > /dev/null; then
    echo "ElectrumX 프로세스 종료 중..."
    pkill electrumx
    sleep 5
fi

# 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get update
apt-get install -y python3-pip python3-venv libleveldb-dev git build-essential || error_exit "패키지 설치 실패"

# ElectrumX 디렉토리 생성
echo "ElectrumX 디렉토리 생성 중..."
if [ -d "$ELECTRUMX_DIR" ]; then
    rm -rf "$ELECTRUMX_DIR"
fi

# Git clone 및 가상환경 설정
echo "ElectrumX 소스코드 다운로드 및 가상환경 설정 중..."
run_as_user "git clone https://github.com/spesmilo/electrumx.git ${ELECTRUMX_DIR}"
run_as_user "python3 -m venv ${ELECTRUMX_VENV}"
run_as_user "source ${ELECTRUMX_VENV}/bin/activate && cd ${ELECTRUMX_DIR} && pip install ."

# 설정 파일 생성
echo "ElectrumX 설정 파일 생성 중..."
mkdir -p "${USER_HOME}/.electrumx"
cat > "${USER_HOME}/.electrumx/config.env" << EOF
DAEMON_URL=http://127.0.0.1:8332
DB_DIRECTORY=${USER_HOME}/.electrumx/db
COIN=Bitcoin
SERVICES=tcp://0.0.0.0:50001
PEER_DISCOVERY=off
PEER_ANNOUNCE=
MAX_SESSIONS=1000
CACHE_MB=2000
HOST=
ALLOW_ROOT=false
COST_SOFT_LIMIT=0
COST_HARD_LIMIT=0
REQUEST_TIMEOUT=30
BANDWIDTH_LIMIT=2000000
DONATION_ADDRESS=
DB_ENGINE=leveldb
LOG_LEVEL=info
DAEMON_URL_POLL_INTERVAL=60
PEER_DISCOVERY_TIMEOUT=30
EOF

# 권한 설정
chown -R ${USER_NAME}:${USER_NAME} "${USER_HOME}/.electrumx"
chmod 750 "${USER_HOME}/.electrumx"
chmod 640 "${USER_HOME}/.electrumx/config.env"

# systemd 서비스 파일 생성
echo "systemd 서비스 파일 생성 중..."
cat > /etc/systemd/system/electrumx.service << EOF
[Unit]
Description=ElectrumX
After=bitcoind.service
Requires=bitcoind.service

[Service]
WorkingDirectory=${ELECTRUMX_DIR}
EnvironmentFile=${USER_HOME}/.electrumx/config.env
ExecStart=${ELECTRUMX_VENV}/bin/electrumx_server
User=${USER_NAME}
Group=${USER_NAME}
Type=simple
KillMode=process
Restart=always
RestartSec=60
TimeoutSec=300
LimitNOFILE=8192

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
systemctl enable electrumx
systemctl start electrumx

# 서비스 및 포트 상태 확인
echo "서비스 및 포트 상태 확인 중..."
MAX_ATTEMPTS=10
ATTEMPT=1
SERVICE_STARTED=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SERVICE_STARTED" = "false" ]; do
    if systemctl is-active --quiet electrumx && nc -zv localhost 50001 2>/dev/null; then
        echo "ElectrumX 서비스가 성공적으로 시작되었고 포트 50001이 열렸습니다."
        SERVICE_STARTED=true
    else
        echo "시도 $ATTEMPT/$MAX_ATTEMPTS: 서비스 시작 및 포트 열림 대기 중..."
        sleep 10
        ATTEMPT=$((ATTEMPT+1))
    fi
done

if [ "$SERVICE_STARTED" = "false" ]; then
    echo "서비스 상태:"
    systemctl status electrumx
    echo "포트 50001 상태:"
    sudo netstat -tuln | grep 50001 || echo "포트가 사용 중이 아닙니다."
    echo "UFW 규칙:"
    sudo ufw status verbose | grep 50001
    echo "로그 확인:"
    journalctl -u electrumx --no-pager | tail -n 50
    error_exit "ElectrumX 서비스 시작 또는 포트 열기 실패"
fi

echo "ElectrumX 설치가 완료되었습니다."
echo "로그 확인: journalctl -u electrumx -f" 