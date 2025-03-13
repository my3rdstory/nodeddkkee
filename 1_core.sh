#!/bin/bash

# root 권한 체크 및 실제 사용자 확인
if [ "$(id -u)" != "0" ]; then
    echo "이 스크립트는 root 권한으로 실행해야 합니다."
    echo "다음 명령어로 다시 실행하세요: sudo $0"
    exit 1
fi

# 실제 사용자 확인 (sudo를 통해 실행된 경우 SUDO_USER 환경변수 사용)
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(logname 2>/dev/null || echo $USER)
fi

# Bitcoin Core 버전 설정
CORE_VERSION="28.1"

# 사용자 이름 설정 (항상 실제 사용자로 설정)
USER_NAME=$REAL_USER
USER_HOME="/home/${USER_NAME}"

# RPC 인증정보 설정
RPCUSER="${USER_NAME}"
RPCPASSWORD="bitcoin"
BITCOIN_DIR="${USER_HOME}/.bitcoin"

# error_exit 함수 정의
error_exit() {
    echo "오류: $1" >&2
    exit 1
}

# 권한 관련 헬퍼 함수 정의
run_as_user() {
    su - ${USER_NAME} -c "$1"
}

# 기존 Bitcoin Core 프로세스 종료
echo "기존 Bitcoin Core 프로세스 정리 중..."
if systemctl is-active --quiet bitcoind; then
    echo "Bitcoin Core 서비스 중지 및 비활성화 중..."
    sudo systemctl stop bitcoind
    sudo systemctl disable bitcoind
    sleep 5
elif pgrep bitcoind > /dev/null; then
    echo "Bitcoin Core 데몬 종료 중..."
    bitcoin-cli stop 2>/dev/null || pkill bitcoind
    sleep 5
fi

# .bitcoin 디렉토리 정리
# echo ".bitcoin 디렉토리 정리 중..."
# if [ -d "${USER_HOME}/.bitcoin" ]; then
#     rm -rf ${USER_HOME}/.bitcoin
#     echo ".bitcoin 디렉토리가 삭제되었습니다."
# fi

# .bitcoin 디렉토리 존재 여부 확인
if [ -d "${USER_HOME}/.bitcoin" ]; then
    echo ".bitcoin 디렉토리가 이미 존재합니다. 기존 데이터를 보존합니다."
fi

# downloads 디렉토리 존재 여부 확인 및 생성
if [ ! -d "downloads" ]; then
    mkdir -p downloads || error_exit "downloads 디렉토리 생성에 실패했습니다."
    echo "downloads 디렉토리가 생성되었습니다."
else
    echo "downloads 디렉토리가 이미 존재합니다."
fi

# downloads 디렉토리로 이동
cd downloads || error_exit "downloads 디렉토리로 이동할 수 없습니다."

# Bitcoin Core 다운로드
echo "Bitcoin Core ${CORE_VERSION} 다운로드를 시작합니다..."
wget -c https://bitcoincore.org/bin/bitcoin-core-${CORE_VERSION}/bitcoin-${CORE_VERSION}-x86_64-linux-gnu.tar.gz || error_exit "Bitcoin Core 다운로드에 실패했습니다."
echo "다운로드가 완료되었습니다."

# 압축 해제
echo "압축 파일을 해제합니다..."
tar xzf bitcoin-${CORE_VERSION}-x86_64-linux-gnu.tar.gz || error_exit "압축 파일 해제에 실패했습니다."
echo "압축 해제가 완료되었습니다."

# 바이너리 파일 설치
echo "Bitcoin Core 바이너리를 설치합니다..."
# 바이너리 파일 존재 확인
if [ ! -d "bitcoin-${CORE_VERSION}/bin" ]; then
    error_exit "바이너리 디렉토리를 찾을 수 없습니다."
fi

# 각 바이너리 파일 개별 설치
for binary in bitcoind bitcoin-cli bitcoin-tx bitcoin-util bitcoin-wallet; do
    if [ -f "bitcoin-${CORE_VERSION}/bin/${binary}" ]; then
        echo "${binary} 설치 중..."
        sudo install -v -m 0755 -o root -g root "bitcoin-${CORE_VERSION}/bin/${binary}" "/usr/local/bin/${binary}" || error_exit "${binary} 설치에 실패했습니다."
    else
        echo "경고: ${binary} 파일을 찾을 수 없습니다."
    fi
done

# 설치 확인
echo "바이너리 설치 확인 중..."
for binary in bitcoind bitcoin-cli bitcoin-tx bitcoin-util bitcoin-wallet; do
    if command -v "$binary" >/dev/null 2>&1; then
        echo "${binary} 설치 완료: $(which ${binary})"
    else
        error_exit "${binary} 설치를 확인할 수 없습니다."
    fi
done

echo "모든 Bitcoin Core 바이너리 설치가 완료되었습니다."

# Bitcoin Core를 서버 모드로 백그라운드에서 실행하여 .bitcoin 디렉토리 자동 생성
echo "Bitcoin Core 초기 실행 전 .bitcoin 디렉토리 확인 중..."
if [ -d "${USER_HOME}/.bitcoin" ]; then
    echo ".bitcoin 디렉토리가 이미 존재합니다: ${USER_HOME}/.bitcoin"
    
    # Bitcoin Core 서비스 상태 확인
    if systemctl is-active --quiet bitcoind; then
        echo "Bitcoin Core 서비스가 이미 active 상태입니다. 소유권 확인 및 수정 단계를 생략합니다."
    else
        # 서비스가 active 상태가 아닐 때만 소유권 확인 및 수정
        if [ "$(whoami)" = "root" ]; then
            echo "디렉토리 소유권 확인 및 수정 중..."
            chown -R ${USER_NAME}:${USER_NAME} ${USER_HOME}/.bitcoin || error_exit ".bitcoin 디렉토리 소유권 변경에 실패했습니다."
        fi
    fi
else
    echo ".bitcoin 디렉토리가 존재하지 않습니다. 생성 중..."
    if [ "$(whoami)" = "root" ]; then
        # root로 실행 중일 때는 반드시 USER_NAME으로 전환하여 실행
        run_as_user "mkdir -p ${USER_HOME}/.bitcoin"
        run_as_user "bitcoind -server -daemon"
    else
        mkdir -p ${USER_HOME}/.bitcoin
        bitcoind -server -daemon
    fi

    echo "Bitcoin 디렉토리 생성 대기 중..."
    sleep 5

    if [ -d "${USER_HOME}/.bitcoin" ]; then
        echo ".bitcoin 디렉토리가 성공적으로 생성되었습니다: ${USER_HOME}/.bitcoin"
    else
        echo "경고: .bitcoin 디렉토리가 생성되지 않았습니다. 수동으로 생성합니다."
        mkdir -p ${USER_HOME}/.bitcoin || error_exit ".bitcoin 디렉토리를 수동으로 생성할 수 없습니다."
        if [ "$(whoami)" = "root" ]; then
            chown -R ${USER_NAME}:${USER_NAME} ${USER_HOME}/.bitcoin || error_exit ".bitcoin 디렉토리 소유권 변경에 실패했습니다."
        fi
    fi
fi

# Bitcoin Core 데몬이 실행 중인지 확인
echo "Bitcoin Core 데몬 실행 상태 확인 중..."
if [ "$(whoami)" = "root" ]; then
    if run_as_user "bitcoin-cli getblockchaininfo" &>/dev/null; then
        echo "타임체인 정보 조회 성공:"
        run_as_user "bitcoin-cli getblockchaininfo | jq" || error_exit "타임체인 정보 출력에 실패했습니다."
    else
        echo "경고: Bitcoin Core 데몬이 실행 중이 아니거나 응답하지 않습니다."
    fi
else
    if bitcoin-cli getblockchaininfo &>/dev/null; then
        echo "타임체인 정보 조회 성공:"
        bitcoin-cli getblockchaininfo | jq || error_exit "타임체인 정보 출력에 실패했습니다."
    else
        echo "경고: Bitcoin Core 데몬이 실행 중이 아니거나 응답하지 않습니다."
    fi
fi

# 잠시 대기하여 프로세스가 완전히 종료되도록 함
sleep 3

# Bitcoin 설정 파일 유효성 검사
echo "Bitcoin 설정 파일 유효성 검사 중..."

# 생성된 RPC 인증 정보 출력
echo "RPC 인증 정보:"
echo "사용자: ${USER_NAME}"
echo "비밀번호: ${RPCPASSWORD}"

# bitcoin.conf 파일 생성
echo "Bitcoin 설정 파일 생성 중..."
if [ "$(whoami)" = "root" ]; then
    # root로 실행 중인 경우 임시 파일을 생성한 후 소유권 변경
    cat > /tmp/bitcoin.conf.tmp << EOF || error_exit "임시 Bitcoin 설정 파일 생성에 실패했습니다."
# RPC 인증 설정
# rpcuser=${USER_NAME}
# rpcpassword=${RPCPASSWORD}

server=1
txindex=0
daemon=1
# mempoolfullrbf=1
# mempoolexpiry=336
# maxmempool=500

rpcport=8332
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=10.0.0.0/8
rpcallowip=172.0.0.0/8
rpcallowip=192.0.0.0/8
zmqpubrawblock=tcp://0.0.0.0:28332
zmqpubrawtx=tcp://0.0.0.0:28333
zmqpubhashblock=tcp://0.0.0.0:28334
whitelist=127.0.0.1

# 일반 인터넷 연결 허용
addnode=mainnet.bitcoin.ninja
discover=1
dnsseed=1
dns=1

# 연결 설정
maxconnections=125
maxuploadtarget=5000
EOF
    # 파일 복사 및 소유권 변경
    cp /tmp/bitcoin.conf.tmp ${USER_HOME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 복사에 실패했습니다."
    chown ${USER_NAME}:${USER_NAME} ${USER_HOME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 소유권 변경에 실패했습니다."
    chmod 600 ${USER_HOME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 권한 변경에 실패했습니다."
    rm /tmp/bitcoin.conf.tmp
else
    # 일반 사용자로 실행 중인 경우 직접 생성
    cat > ${USER_HOME}/.bitcoin/bitcoin.conf << EOF || error_exit "Bitcoin 설정 파일 생성에 실패했습니다."
# RPC 인증 설정
rpcuser=${USER_NAME}
rpcpassword=${RPCPASSWORD}

server=1
txindex=1
daemon=1
mempoolfullrbf=1
mempoolexpiry=336
maxmempool=500

rpcport=8332
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=10.0.0.0/8
rpcallowip=172.0.0.0/8
rpcallowip=192.0.0.0/8
zmqpubrawblock=tcp://0.0.0.0:28332
zmqpubrawtx=tcp://0.0.0.0:28333
zmqpubhashblock=tcp://0.0.0.0:28334
whitelist=127.0.0.1

# 일반 인터넷 연결 허용
addnode=mainnet.bitcoin.ninja
discover=1
dnsseed=1
dns=1

# 연결 설정
maxconnections=125
maxuploadtarget=5000
EOF
    chmod 600 ${USER_HOME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 권한 변경에 실패했습니다."
fi

echo "Bitcoin 설정 파일이 생성되었습니다: ${USER_HOME}/.bitcoin/bitcoin.conf"

# 기존 Bitcoin Core 프로세스 종료 확인
echo "기존 Bitcoin Core 프로세스 확인 및 종료 중..."
if pgrep bitcoind > /dev/null; then
    echo "기존 Bitcoin Core 프로세스 종료 중..."
    if [ "$(whoami)" = "root" ]; then
        su - ${USER_NAME} -c "bitcoin-cli stop" || pkill bitcoind
    else
        bitcoin-cli stop || pkill bitcoind
    fi
    sleep 10
fi

# 락 파일 확인 및 제거
if [ -f "${USER_HOME}/.bitcoin/.lock" ]; then
    echo "Bitcoin Core 락 파일 제거 중..."
    rm -f "${USER_HOME}/.bitcoin/.lock"
fi

# 디렉토리 권한 확인 및 수정
echo "디렉토리 권한 확인 및 수정 중..."

# /run/bitcoind 디렉토리 확인 및 생성
if [ ! -d "/run/bitcoind" ]; then
    sudo mkdir -p /run/bitcoind || error_exit "/run/bitcoind 디렉토리 생성 실패"
fi

# /run/bitcoind 권한 설정
sudo chown ${USER_NAME}:${USER_NAME} /run/bitcoind || error_exit "/run/bitcoind 소유권 변경 실패"
sudo chmod 755 /run/bitcoind || error_exit "/run/bitcoind 권한 설정 실패"

# .bitcoin 디렉토리 권한 설정
sudo chown -R ${USER_NAME}:${USER_NAME} ${USER_HOME}/.bitcoin || error_exit ".bitcoin 디렉토리 소유권 변경 실패"
sudo chmod 755 ${USER_HOME}/.bitcoin || error_exit ".bitcoin 디렉토리 권한 설정 실패"

# 권한 설정 확인
echo "디렉토리 권한 확인:"
ls -ld /run/bitcoind
ls -ld ${USER_HOME}/.bitcoin

# bitcoind.service 파일 생성
echo "bitcoind.service 파일 생성 중..."
cat > /tmp/bitcoind.service << EOF || error_exit "bitcoind.service 파일 생성에 실패했습니다."
[Unit]
Description=Bitcoin daemon
Documentation=https://github.com/bitcoin/bitcoin/blob/master/doc/init.md
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/bin/mkdir -p /run/bitcoind
ExecStartPre=/bin/chown ${USER_NAME}:${USER_NAME} /run/bitcoind
ExecStartPre=/bin/mkdir -p /home/${USER_NAME}/.bitcoin
ExecStartPre=/bin/chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bitcoin
ExecStart=/usr/local/bin/bitcoind \\
                            -daemon \\
                            -pid=/run/bitcoind/bitcoind.pid \\
                            -conf=/home/${USER_NAME}/.bitcoin/bitcoin.conf \\
                            -datadir=/home/${USER_NAME}/.bitcoin
Type=forking
PIDFile=/run/bitcoind/bitcoind.pid
Restart=on-failure
RestartSec=5
TimeoutStartSec=infinity
TimeoutStopSec=600
User=${USER_NAME}
Group=${USER_NAME}
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710
WorkingDirectory=/home/${USER_NAME}/.bitcoin
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# 서비스 파일을 시스템 디렉토리로 이동
sudo mv /tmp/bitcoind.service /etc/systemd/system/bitcoind.service || error_exit "서비스 파일 이동에 실패했습니다."
sudo chmod 644 /etc/systemd/system/bitcoind.service || error_exit "서비스 파일 권한 설정에 실패했습니다."

# 시스템 데몬 리로드
sudo systemctl daemon-reload || error_exit "시스템 데몬 리로드에 실패했습니다."

# 네트워크 상태 확인
echo "네트워크 상태 확인 중..."
MAX_NET_ATTEMPTS=30
NET_ATTEMPT=1
NETWORK_READY=false

while [ $NET_ATTEMPT -le $MAX_NET_ATTEMPTS ] && [ "$NETWORK_READY" = "false" ]; do
    if systemctl is-active --quiet network-online.target || systemctl is-active --quiet NetworkManager.service; then
        echo "네트워크가 준비되었습니다."
        NETWORK_READY=true
    else
        echo "시도 $NET_ATTEMPT/$MAX_NET_ATTEMPTS: 네트워크가 준비되지 않았습니다."
        if [ $NET_ATTEMPT -lt $MAX_NET_ATTEMPTS ]; then
            echo "2초 후 다시 확인합니다..."
            sleep 2
        fi
        NET_ATTEMPT=$((NET_ATTEMPT+1))
    fi
done

if [ "$NETWORK_READY" = "false" ]; then
    error_exit "네트워크가 준비되지 않았습니다. 네트워크 연결을 확인해 주세요."
fi

# 인터넷 연결 확인
echo "인터넷 연결 확인 중..."
if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    error_exit "인터넷 연결을 확인할 수 없습니다."
fi

# 서비스 활성화
sudo systemctl enable bitcoind
sleep 5

# 최대 시도 횟수 설정
MAX_ATTEMPTS=10
ATTEMPT=1
SERVICE_STARTED=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SERVICE_STARTED" = "false" ]; do
    echo "시도 $ATTEMPT/$MAX_ATTEMPTS: Bitcoin Core 서비스 시작 중..."
    sudo systemctl start bitcoind
    sleep 5
    
    # 서비스 상태 확인
    if sudo systemctl is-active --quiet bitcoind; then
        echo "Bitcoin Core 서비스가 성공적으로 시작되었습니다."
        SERVICE_STARTED=true
    else
        echo "Bitcoin Core 서비스 시작 실패. 상태 확인 중..."
        sudo systemctl status bitcoind --no-pager | head -n 20
        
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "3초 후 다시 시도합니다..."
            sleep 3
        fi
        ATTEMPT=$((ATTEMPT+1))
    fi
done

if [ "$SERVICE_STARTED" = "false" ]; then
    echo "최대 시도 횟수($MAX_ATTEMPTS)에 도달했습니다."
    echo "서비스 로그 확인 중..."
    sudo journalctl -u bitcoind --no-pager | tail -n 50
    error_exit "Bitcoin Core 서비스 시작에 실패했습니다. 설정 파일과 권한을 확인해 주세요."
fi

# 타임체인 정보 확인
echo "타임체인 정보 확인 중..."
sleep 5

# 최대 시도 횟수 설정
MAX_ATTEMPTS=10
ATTEMPT=1
INFO_RETRIEVED=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$INFO_RETRIEVED" = "false" ]; do
    echo "시도 $ATTEMPT/$MAX_ATTEMPTS: 타임체인 정보 확인 중..."
    
    if [ "$(whoami)" = "root" ]; then
        # root로 실행 중인 경우 su 명령을 사용하여 지정된 사용자로 실행
        if su - ${USER_NAME} -c "bitcoin-cli getblockchaininfo" &>/dev/null; then
            echo "타임체인 정보 조회 성공:"
            su - ${USER_NAME} -c "bitcoin-cli getblockchaininfo | jq" || echo "경고: 타임체인 정보 출력에 실패했습니다."
            INFO_RETRIEVED=true
        else
            echo "타임체인 정보 조회 실패. Bitcoin Core가 아직 준비되지 않았을 수 있습니다."
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                # 대기 시간 증가
                echo "5초 후 다시 시도합니다..."
                sleep 5
            fi
            ATTEMPT=$((ATTEMPT+1))
        fi
    else
        # 이미 일반 사용자로 실행 중인 경우 직접 실행
        if bitcoin-cli getblockchaininfo &>/dev/null; then
            echo "타임체인 정보 조회 성공:"
            bitcoin-cli getblockchaininfo | jq || echo "경고: 타임체인 정보 출력에 실패했습니다."
            INFO_RETRIEVED=true
        else
            echo "타임체인 정보 조회 실패. Bitcoin Core가 아직 준비되지 않았을 수 있습니다."
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then                
                echo "3초 후 다시 시도합니다..."
                sleep 3
            fi
            ATTEMPT=$((ATTEMPT+1))
        fi
    fi
done

if [ "$INFO_RETRIEVED" = "false" ]; then
    echo "최대 시도 횟수($MAX_ATTEMPTS)에 도달했습니다."
    echo "Bitcoin Core 서비스 로그 확인 중..."
    sudo journalctl -u bitcoind --no-pager | tail -n 50
    echo "경고: 타임체인 정보를 가져올 수 없습니다. Bitcoin Core가 제대로 시작되지 않았을 수 있습니다."
    echo "설치는 계속 진행됩니다."
fi

echo "Bitcoin Core 설정이 완료되었습니다."
echo "tail -f ~/.bitcoin/debug.log 명령어로 로그를 확인할 수 있습니다."