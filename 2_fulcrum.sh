#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - Fulcrum 설치
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
echo "Fulcrum 설치 스크립트를 시작합니다..."
echo "설치할 Fulcrum 버전: ${FULCRUM_VERSION}"
echo "사용자 계정: ${USER_NAME}"

# 필요한 패키지 설치
echo "Fulcrum 의존성 패키지 설치 중..."
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev libzmq3-dev libsodium-dev pkg-config zlib1g-dev libbz2-dev libsnappy-dev || error_exit "의존성 패키지 설치에 실패했습니다."

# Fulcrum 디렉토리 생성
echo "Fulcrum 디렉토리 생성 중..."
mkdir -p ${FULCRUM_DIR} ${FULCRUM_DATA_DIR} ${FULCRUM_CONF_DIR} ${FULCRUM_SSL_DIR} || error_exit "Fulcrum 디렉토리 생성에 실패했습니다."
# 로그 디렉토리 추가
FULCRUM_LOG_DIR="${FULCRUM_DIR}/logs"
mkdir -p ${FULCRUM_LOG_DIR} || error_exit "Fulcrum 로그 디렉토리 생성에 실패했습니다."

# Fulcrum 다운로드 및 설치
echo "Fulcrum 다운로드 중..."
cd ~/downloads || error_exit "다운로드 디렉토리로 이동할 수 없습니다."

# 시스템 아키텍처 확인
ARCH=$(uname -m)
if [ -z "$FULCRUM_ARCH" ]; then
    error_exit "FULCRUM_ARCH 환경 변수가 설정되지 않았습니다."
fi

# Fulcrum 바이너리 다운로드
wget -c "https://github.com/cculianu/Fulcrum/releases/download/v${FULCRUM_VERSION}/Fulcrum-${FULCRUM_VERSION}-${FULCRUM_ARCH}.tar.gz" || error_exit "Fulcrum 다운로드에 실패했습니다."

# 압축 해제
echo "Fulcrum 압축 해제 중..."
tar xzf "Fulcrum-${FULCRUM_VERSION}-${FULCRUM_ARCH}.tar.gz" || error_exit "Fulcrum 압축 해제에 실패했습니다."

# 바이너리 설치
echo "Fulcrum 바이너리 설치 중..."
sudo install -m 0755 -o root -g root -t /usr/local/bin "Fulcrum-${FULCRUM_VERSION}-${FULCRUM_ARCH}/Fulcrum" "Fulcrum-${FULCRUM_VERSION}-${FULCRUM_ARCH}/FulcrumAdmin" || error_exit "Fulcrum 바이너리 설치에 실패했습니다."

# SSL 인증서 생성
echo "SSL 인증서 생성 중..."
cd ${FULCRUM_SSL_DIR} || error_exit "SSL 디렉토리로 이동할 수 없습니다."
openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 3650 -out cert.pem -subj "/C=KR/ST=Seoul/L=Seoul/O=Nodeddkkee/OU=Bitcoin/CN=localhost" || error_exit "SSL 인증서 생성에 실패했습니다."

# Fulcrum 설정 파일 생성
echo "Fulcrum 설정 파일 생성 중..."
# 기존 설정 파일 백업
if [ -f "${FULCRUM_CONF_DIR}/fulcrum.conf" ]; then
    echo "기존 설정 파일 백업 중..."
    cp "${FULCRUM_CONF_DIR}/fulcrum.conf" "${FULCRUM_CONF_DIR}/fulcrum.conf.backup.$(date +%Y%m%d%H%M%S)" || error_exit "설정 파일 백업에 실패했습니다."
fi

# 시스템 메모리 확인 및 DB 메모리 설정 최적화
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
# 시스템 메모리의 25%를 Fulcrum에 할당 (최소 512MB, 최대 4GB)
DB_MEM=$((TOTAL_MEM_MB / 4))
if [ $DB_MEM -lt 512 ]; then
    DB_MEM=512
elif [ $DB_MEM -gt 4096 ]; then
    DB_MEM=4096
fi

cat > ${FULCRUM_CONF_DIR}/fulcrum.conf << EOF || error_exit "Fulcrum 설정 파일 생성에 실패했습니다."
# Fulcrum 설정 파일

# 데이터베이스 디렉토리
datadir = ${FULCRUM_DATA_DIR}

# Bitcoin Core RPC 설정
bitcoind = 127.0.0.1:8332
rpcuser = ${USER_NAME}
rpcpassword = ${RPC_PASSWORD}

# 서버 설정
tcp = 127.0.0.1:50001
ssl = 127.0.0.1:50002

# SSL 인증서 설정
cert = ${FULCRUM_SSL_DIR}/cert.pem
key = ${FULCRUM_SSL_DIR}/key.pem

# 성능 설정
worker_threads = 4
db_max_open_files = 400
db_mem = ${DB_MEM}

# 로깅 설정
debug = false
logfile = ${FULCRUM_LOG_DIR}/fulcrum.log
EOF

# 소유권 설정
echo "Fulcrum 디렉토리 소유권 설정 중..."
sudo chown -R ${USER_NAME}:${USER_NAME} ${FULCRUM_DIR} || error_exit "Fulcrum 디렉토리 소유권 설정에 실패했습니다."

# Fulcrum 서비스 파일 생성
echo "Fulcrum 서비스 파일 생성 중..."
sudo tee /etc/systemd/system/fulcrum.service > /dev/null << EOF || error_exit "Fulcrum 서비스 파일 생성에 실패했습니다."
[Unit]
Description=Fulcrum Electrum Server
After=bitcoind.service
Requires=bitcoind.service

[Service]
ExecStart=/usr/local/bin/Fulcrum ${FULCRUM_CONF_DIR}/fulcrum.conf
User=${USER_NAME}
Group=${USER_NAME}
Type=simple
KillMode=process
TimeoutSec=180
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화
echo "Fulcrum 서비스 활성화 중..."
sudo systemctl daemon-reload || error_exit "systemd 데몬 리로드에 실패했습니다."
sudo systemctl enable fulcrum || error_exit "Fulcrum 서비스 활성화에 실패했습니다."

# 서비스 시작
echo "Fulcrum 서비스 시작 중..."
sudo systemctl start fulcrum || error_exit "Fulcrum 서비스 시작에 실패했습니다."

# 서비스 상태 확인
echo "Fulcrum 서비스 상태 확인 중..."
if ! sudo systemctl status fulcrum --no-pager; then
    echo "경고: Fulcrum 서비스가 정상적으로 시작되지 않았을 수 있습니다. 로그를 확인해주세요: journalctl -u fulcrum -n 50"
    # 오류가 발생해도 스크립트는 계속 진행
fi

echo "Fulcrum 설치가 완료되었습니다."
echo "Electrum 클라이언트에서 다음 서버를 추가할 수 있습니다:"
echo "  - TCP: $(hostname -I | awk '{print $1}'):50001"
echo "  - SSL: $(hostname -I | awk '{print $1}'):50002" 