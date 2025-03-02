#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - Bitcoin Core 설치
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

# 환경 변수 로드
if [ -f "nodeddkkee_env.sh" ]; then
    source nodeddkkee_env.sh
else
    error_exit "환경 변수 파일(nodeddkkee_env.sh)을 찾을 수 없습니다. 0_check.sh를 먼저 실행해주세요."
fi

# 변수 설정
BITCOIN_VERSION="28.1"
BITCOIN_ARCH="x86_64-linux-gnu"

# 다운로드 디렉토리 확인 및 생성
if [ ! -d ~/downloads ]; then
    echo "다운로드 디렉토리 생성 중..."
    mkdir -p ~/downloads || error_exit "다운로드 디렉토리를 생성할 수 없습니다."
fi

# 스크립트 실행 시작 메시지
echo "Bitcoin Core 설치 스크립트를 시작합니다..."
echo "설치할 Bitcoin Core 버전: ${BITCOIN_VERSION}"
echo "사용자 계정: ${USER_NAME}"

# Bitcoin core 파일 검증 및 설치
echo "Bitcoin Core 다운로드 및 설치 준비 중..."

# 다운로드 디렉토리로 이동
cd ~/downloads || error_exit "다운로드 디렉토리로 이동할 수 없습니다."

# Bitcoin core 설치파일 및 검증파일 다운로드
echo "Bitcoin Core ${BITCOIN_VERSION} 다운로드 중..."
wget -c https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz || error_exit "Bitcoin Core 다운로드에 실패했습니다."

# 검증파일 다운로드
echo "검증 파일 다운로드 중..."
wget -c https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS || error_exit "SHA256SUMS 파일 다운로드에 실패했습니다."
wget -c https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc || error_exit "SHA256SUMS.asc 파일 다운로드에 실패했습니다."

# PGP서명 확인
echo "PGP 서명 확인 중..."
# guix.sigs 폴더가 존재하는지 확인하고 존재하면 삭제
if [ -d "guix.sigs" ]; then
    echo "기존 guix.sigs 폴더가 발견되었습니다. 삭제 중..."
    rm -rf guix.sigs || error_exit "기존 guix.sigs 폴더 삭제에 실패했습니다."
fi
git clone https://github.com/bitcoin-core/guix.sigs || error_exit "guix.sigs 저장소 클론에 실패했습니다."
gpg --import guix.sigs/builder-keys/* || error_exit "PGP 키 가져오기에 실패했습니다."
gpg --verify SHA256SUMS.asc || error_exit "PGP 서명 검증에 실패했습니다. 다운로드한 파일이 손상되었거나 변조되었을 수 있습니다."

# SHA256 체크섬 확인
echo "SHA256 체크섬 확인 중..."
sha256sum --ignore-missing --check SHA256SUMS || error_exit "SHA256 체크섬 검증에 실패했습니다. 다운로드한 파일이 손상되었을 수 있습니다."

# Bitcoin core 설치
echo "Bitcoin Core 압축 해제 중..."
tar xzf bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz || error_exit "Bitcoin Core 압축 해제에 실패했습니다."

# 바이너리 설치
echo "바이너리 파일 설치 중..."
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${BITCOIN_VERSION}/bin/* || error_exit "바이너리 파일 설치에 실패했습니다."

# Bitcoin Core를 서버 모드로 백그라운드에서 실행하여 .bitcoin 디렉토리 자동 생성
echo "Bitcoin Core 초기 실행 전 .bitcoin 디렉토리 확인 중..."
if [ -d "/home/${USER_NAME}/.bitcoin" ]; then
    echo ".bitcoin 디렉토리가 이미 존재합니다: /home/${USER_NAME}/.bitcoin"
    
    # Bitcoin Core 서비스 상태 확인
    if systemctl is-active --quiet bitcoind; then
        echo "Bitcoin Core 서비스가 이미 active 상태입니다. 소유권 확인 및 수정 단계를 생략합니다."
    else
        # 서비스가 active 상태가 아닐 때만 소유권 확인 및 수정
        if [ "$(whoami)" = "root" ]; then
            echo "디렉토리 소유권 확인 및 수정 중..."
            chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bitcoin || error_exit ".bitcoin 디렉토리 소유권 변경에 실패했습니다."
        fi
    fi
else
    echo ".bitcoin 디렉토리가 존재하지 않습니다. 생성 중..."
    # 일반 사용자로 bitcoind 실행하여 디렉토리 생성
    echo "Bitcoin Core 초기 실행 중 (.bitcoin 디렉토리 생성)..."
    if [ "$(whoami)" = "root" ]; then
        # root로 실행 중인 경우 su 명령을 사용하여 지정된 사용자로 실행
        su - ${USER_NAME} -c "bitcoind -server -daemon" || error_exit "Bitcoin Core 초기 실행에 실패했습니다."
    else
        # 이미 일반 사용자로 실행 중인 경우 직접 실행
        bitcoind -server -daemon || error_exit "Bitcoin Core 초기 실행에 실패했습니다."
    fi

    # 디렉토리가 생성될 때까지 잠시 대기
    echo "Bitcoin 디렉토리 생성 대기 중..."
    sleep 5

    # .bitcoin 디렉토리 생성 확인
    if [ -d "/home/${USER_NAME}/.bitcoin" ]; then
        echo ".bitcoin 디렉토리가 성공적으로 생성되었습니다: /home/${USER_NAME}/.bitcoin"
    else
        echo "경고: .bitcoin 디렉토리가 생성되지 않았습니다. 수동으로 생성합니다."
        mkdir -p /home/${USER_NAME}/.bitcoin || error_exit ".bitcoin 디렉토리를 수동으로 생성할 수 없습니다."
        # root로 실행 중인 경우 소유권 변경
        if [ "$(whoami)" = "root" ]; then
            chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bitcoin || error_exit ".bitcoin 디렉토리 소유권 변경에 실패했습니다."
        fi
    fi
fi

# Bitcoin Core 데몬이 실행 중인지 확인
echo "Bitcoin Core 데몬 실행 상태 확인 중..."
if [ "$(whoami)" = "root" ]; then
    # root로 실행 중인 경우 su 명령을 사용하여 지정된 사용자로 실행
    if su - ${USER_NAME} -c "bitcoin-cli getblockchaininfo" &>/dev/null; then
        echo "Bitcoin Core 데몬이 정상적으로 실행 중입니다."
        # 정보 출력
        su - ${USER_NAME} -c "bitcoin-cli getblockchaininfo | jq" || echo "경고: 타임체인 정보를 가져올 수 없습니다."
    else
        echo "경고: Bitcoin Core 데몬이 실행 중이 아니거나 응답하지 않습니다."
        # 경고만 표시하고 계속 진행
    fi
else
    # 이미 일반 사용자로 실행 중인 경우 직접 실행
    if bitcoin-cli getblockchaininfo &>/dev/null; then
        echo "Bitcoin Core 데몬이 정상적으로 실행 중입니다."
        # 정보 출력
        bitcoin-cli getblockchaininfo | jq || echo "경고: 타임체인 정보를 가져올 수 없습니다."
    else
        echo "경고: Bitcoin Core 데몬이 실행 중이 아니거나 응답하지 않습니다."
        # 경고만 표시하고 계속 진행
    fi
fi

# 잠시 대기하여 프로세스가 완전히 종료되도록 함
sleep 3

# RPC 인증 정보 생성 및 메모리에 저장
echo "RPC 인증 정보 생성 중..."
cd ~/downloads || error_exit "다운로드 디렉토리로 이동할 수 없습니다."
wget -q https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py || error_exit "rpcauth.py 스크립트 다운로드에 실패했습니다."
chmod +x rpcauth.py || error_exit "rpcauth.py 스크립트에 실행 권한을 부여할 수 없습니다."

# rpcauth.py 스크립트 실행 결과를 변수에 저장
RPC_AUTH_RESULT=$(./rpcauth.py ${USER_NAME} ${RPC_PASSWORD}) || error_exit "RPC 인증 정보 생성에 실패했습니다."

# 결과에서 rpcauth 문자열만 추출하여 변수에 저장
RPC_AUTH=$(echo "${RPC_AUTH_RESULT}" | grep "^rpcauth=" | cut -d= -f2-)
if [ -z "$RPC_AUTH" ]; then
    error_exit "RPC 인증 문자열을 추출할 수 없습니다."
fi

# 생성된 RPC 인증 정보 출력
echo "생성된 RPC 인증 정보:"
echo "사용자: ${USER_NAME}"
echo "비밀번호: ${RPC_PASSWORD}"
echo "rpcauth=${RPC_AUTH}"

# Bitcoin.conf 파일 생성 (메모리에 저장된 RPC 인증 정보 사용)
echo "Bitcoin 설정 파일 생성 중..."
if [ "$(whoami)" = "root" ]; then
    # root로 실행 중인 경우 임시 파일을 생성한 후 소유권 변경
    cat > /tmp/bitcoin.conf.tmp << EOF || error_exit "임시 Bitcoin 설정 파일 생성에 실패했습니다."
server=1
txindex=1
daemon=1
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
# 메모리에 저장된 RPC 인증 정보 사용
rpcauth=${RPC_AUTH}
EOF
    # 파일 복사 및 소유권 변경
    cp /tmp/bitcoin.conf.tmp /home/${USER_NAME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 복사에 실패했습니다."
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 소유권 변경에 실패했습니다."
    chmod 600 /home/${USER_NAME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 권한 변경에 실패했습니다."
    rm /tmp/bitcoin.conf.tmp
else
    # 일반 사용자로 실행 중인 경우 직접 생성
    cat > /home/${USER_NAME}/.bitcoin/bitcoin.conf << EOF || error_exit "Bitcoin 설정 파일 생성에 실패했습니다."
server=1
txindex=1
daemon=1
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
# 메모리에 저장된 RPC 인증 정보 사용
rpcauth=${RPC_AUTH}
EOF
    chmod 600 /home/${USER_NAME}/.bitcoin/bitcoin.conf || error_exit "Bitcoin 설정 파일 권한 변경에 실패했습니다."
fi

echo "Bitcoin 설정 파일이 생성되었습니다: /home/${USER_NAME}/.bitcoin/bitcoin.conf"

# bitcoind.service 파일 설정
echo "시스템 서비스 설정 중..."
sudo tee /etc/systemd/system/bitcoind.service > /dev/null << EOF || error_exit "서비스 파일 생성에 실패했습니다."
[Unit]
Description=Bitcoin daemon
Documentation=https://github.com/bitcoin/bitcoin/blob/master/doc/init.md
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/bitcoind \\
                            -pid=/run/bitcoind/bitcoind.pid \\
                            -conf=/home/${USER_NAME}/.bitcoin/bitcoin.conf \\
                            -datadir=/home/${USER_NAME}/.bitcoin
PermissionsStartOnly=true
Type=forking
PIDFile=/run/bitcoind/bitcoind.pid
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600
User=${USER_NAME}
Group=${USER_NAME}
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710
ConfigurationDirectory=bitcoin
ConfigurationDirectoryMode=0710
StateDirectory=bitcoind
StateDirectoryMode=0710
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# Bitcoin Core 종료
echo "초기 Bitcoin Core 프로세스 종료 중..."
if [ "$(whoami)" = "root" ]; then
    # root로 실행 중인 경우 su 명령을 사용하여 지정된 사용자로 실행
    su - ${USER_NAME} -c "bitcoin-cli stop" || echo "경고: Bitcoin Core 프로세스를 종료할 수 없습니다. 이미 종료되었거나 실행 중이 아닐 수 있습니다."
else
    # 이미 일반 사용자로 실행 중인 경우 직접 실행
    bitcoin-cli stop || echo "경고: Bitcoin Core 프로세스를 종료할 수 없습니다. 이미 종료되었거나 실행 중이 아닐 수 있습니다."
fi

# 프로세스가 종료될 때까지 대기
while pgrep -u ${USER_NAME} bitcoind > /dev/null; do
    sleep 1
done

# 서비스 활성화
echo "Bitcoin Core 서비스 활성화 및 시작 중..."
sudo systemctl enable bitcoind || error_exit "Bitcoin Core 서비스 활성화에 실패했습니다."
sleep 5

# 서비스 시작
echo "Bitcoin Core 서비스 시작 중..."

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
        if su - ${USER_NAME} -c "bitcoin-cli -rpcwait getblockchaininfo" &>/dev/null; then
            echo "타임체인 정보 조회 성공:"
            su - ${USER_NAME} -c "bitcoin-cli getblockchaininfo | jq" || echo "경고: 타임체인 정보 출력에 실패했습니다."
            INFO_RETRIEVED=true
        else
            echo "타임체인 정보 조회 실패. Bitcoin Core가 아직 준비되지 않았을 수 있습니다."
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                # 대기 시간 증가
                echo "3초 후 다시 시도합니다..."
                sleep 3
            fi
            ATTEMPT=$((ATTEMPT+1))
        fi
    else
        # 이미 일반 사용자로 실행 중인 경우 직접 실행
        if bitcoin-cli -rpcwait getblockchaininfo &>/dev/null; then
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

echo "Bitcoin Core 설치가 완료되었습니다." 