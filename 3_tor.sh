#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - Tor 설정
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

# 로그 파일 설정
LOGS_DIR="logs"
mkdir -p "$LOGS_DIR" || error_exit "로그 디렉토리 생성에 실패했습니다."
LOG_FILE="${LOGS_DIR}/tor_setup_$(date +%Y%m%d_%H%M%S).log"
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# 환경 변수 로드
if [ -f "nodeddkkee_env.sh" ]; then
    source nodeddkkee_env.sh
else
    error_exit "환경 변수 파일(nodeddkkee_env.sh)을 찾을 수 없습니다. 0_check.sh를 먼저 실행해주세요."
fi

# 스크립트 실행 시작 메시지
log "Tor 설정 스크립트를 시작합니다..."
log "사용자 계정: ${USER_NAME}"

# 사용자 확인 함수
confirm() {
    # 항상 true 반환하도록 수정 (자동 진행)
    return 0
}

# Tor 설치 확인
log "Tor 설치 확인 중..."
if ! command -v tor &> /dev/null; then
    log "Tor가 설치되어 있지 않습니다. 설치를 진행합니다..."
    sudo apt-get update
    sudo apt-get install -y tor || error_exit "Tor 설치에 실패했습니다."
else
    log "Tor가 이미 설치되어 있습니다."
fi

# Tor 서비스 상태 확인
log "Tor 서비스 상태 확인 중..."
if ! systemctl is-active --quiet tor; then
    log "Tor 서비스가 실행 중이 아닙니다. 서비스를 시작합니다..."
    sudo systemctl start tor || error_exit "Tor 서비스 시작에 실패했습니다."
else
    log "Tor 서비스가 이미 실행 중입니다."
fi

# Tor 서비스 자동 시작 설정
if ! systemctl is-enabled --quiet tor; then
    log "Tor 서비스가 부팅 시 자동 시작되도록 설정합니다..."
    sudo systemctl enable tor || log "Tor 서비스 자동 시작 설정에 실패했습니다."
else
    log "Tor 서비스가 이미 부팅 시 자동 시작되도록 설정되어 있습니다."
fi

# Tor 설정 파일 백업
BACKUP_FILE="/etc/tor/torrc.bak_$(date +%Y%m%d_%H%M%S)"
log "Tor 설정 파일 백업 중... (${BACKUP_FILE})"
sudo cp /etc/tor/torrc "$BACKUP_FILE" || error_exit "Tor 설정 파일 백업에 실패했습니다."

# Tor 설정 파일에 Hidden Service 설정이 이미 있는지 확인
if sudo grep -q "HiddenServiceDir /var/lib/tor/bitcoin-service/" /etc/tor/torrc; then
    log "Bitcoin Core Hidden Service 설정이 이미 존재합니다."
    BITCOIN_SERVICE_EXISTS=true
else
    BITCOIN_SERVICE_EXISTS=false
fi

if sudo grep -q "HiddenServiceDir /var/lib/tor/fulcrum-service/" /etc/tor/torrc; then
    log "Fulcrum Hidden Service 설정이 이미 존재합니다."
    FULCRUM_SERVICE_EXISTS=true
else
    FULCRUM_SERVICE_EXISTS=false
fi

# 사용자 확인
if [ "$BITCOIN_SERVICE_EXISTS" = false ] || [ "$FULCRUM_SERVICE_EXISTS" = false ]; then
    if confirm "Tor 설정 파일을 수정하시겠습니까?"; then
        # Tor 설정 파일 수정
        log "Tor 설정 파일 수정 중..."
        
        # 추가할 설정 준비
        TOR_CONFIG=""
        
        if [ "$BITCOIN_SERVICE_EXISTS" = false ]; then
            TOR_CONFIG+="
# Bitcoin Core Hidden Service
HiddenServiceDir /var/lib/tor/bitcoin-service/
HiddenServiceVersion 3
HiddenServicePort 8333 127.0.0.1:8333
HiddenServicePort 8332 127.0.0.1:8332
"
        fi
        
        if [ "$FULCRUM_SERVICE_EXISTS" = false ]; then
            TOR_CONFIG+="
# Fulcrum Hidden Service
HiddenServiceDir /var/lib/tor/fulcrum-service/
HiddenServiceVersion 3
HiddenServicePort 50001 127.0.0.1:50001
HiddenServicePort 50002 127.0.0.1:50002
"
        fi
        
        # 설정 추가
        echo "$TOR_CONFIG" | sudo tee -a /etc/tor/torrc > /dev/null || error_exit "Tor 설정 파일 수정에 실패했습니다."
        log "Tor 설정 파일이 성공적으로 수정되었습니다."
    else
        log "사용자가 Tor 설정 파일 수정을 취소했습니다."
    fi
else
    log "모든 Hidden Service 설정이 이미 존재합니다. 설정 파일을 수정하지 않습니다."
fi

# Tor 디렉토리 권한 확인 및 설정
log "Tor 디렉토리 권한 확인 중..."
for DIR in "/var/lib/tor/bitcoin-service/" "/var/lib/tor/fulcrum-service/"; do
    if [ ! -d "$DIR" ]; then
        sudo mkdir -p "$DIR" || log "디렉토리 생성 실패: $DIR"
        sudo chown debian-tor:debian-tor "$DIR" || log "권한 변경 실패: $DIR"
        sudo chmod 700 "$DIR" || log "권한 변경 실패: $DIR"
        log "디렉토리 생성 및 권한 설정 완료: $DIR"
    fi
done

# Tor 서비스 재시작
log "Tor 서비스 재시작 중..."
sudo systemctl restart tor || error_exit "Tor 서비스 재시작에 실패했습니다."

# Tor 서비스가 시작될 때까지 대기
log "Tor 서비스 시작 대기 중..."
for i in {1..30}; do
    if systemctl is-active --quiet tor; then
        log "Tor 서비스가 성공적으로 시작되었습니다."
        break
    fi
    if [ $i -eq 30 ]; then
        log "경고: Tor 서비스 시작 대기 시간이 초과되었습니다."
    fi
    sleep 1
done

# Bitcoin Core 설정 파일 수정
log "Bitcoin Core 설정 파일 확인 중..."
BITCOIN_CONF="/home/${USER_NAME}/.bitcoin/bitcoin.conf"
if [ -f "$BITCOIN_CONF" ]; then
    # 이미 onion 관련 설정이 있는지 확인
    if grep -q "onion=" "$BITCOIN_CONF"; then
        log "Bitcoin Core 설정 파일에 이미 onion 설정이 있습니다."
    else
        # 사용자 확인
        if confirm "Bitcoin Core 설정 파일에 Tor 설정을 추가하시겠습니까?"; then
            # 설정 추가
            cat >> "$BITCOIN_CONF" << EOF || error_exit "Bitcoin Core 설정 파일 수정에 실패했습니다."

# Tor 설정
proxy=127.0.0.1:9050
listen=1
bind=127.0.0.1
onion=127.0.0.1:9050
onlynet=onion
listenonion=1
EOF
            log "Bitcoin Core 설정 파일에 Tor 설정을 추가했습니다."
            
            # Bitcoin Core 서비스 재시작
            if systemctl is-active --quiet bitcoind; then
                log "Bitcoin Core 서비스 재시작 중..."
                sudo systemctl restart bitcoind || error_exit "Bitcoin Core 서비스 재시작에 실패했습니다."
                
                # 서비스 재시작 확인
                sleep 5
                if systemctl is-active --quiet bitcoind; then
                    log "Bitcoin Core 서비스가 성공적으로 재시작되었습니다."
                else
                    log "경고: Bitcoin Core 서비스 재시작 후 활성화되지 않았습니다."
                fi
            else
                log "Bitcoin Core 서비스가 실행 중이 아닙니다. 재시작하지 않습니다."
            fi
        else
            log "사용자가 Bitcoin Core 설정 파일 수정을 취소했습니다."
        fi
    fi
else
    log "경고: Bitcoin Core 설정 파일을 찾을 수 없습니다: $BITCOIN_CONF"
fi

# Fulcrum 서비스 재시작 (설치되어 있는 경우)
if systemctl is-active --quiet fulcrum; then
    log "Fulcrum 서비스 재시작 중..."
    sudo systemctl restart fulcrum || log "Fulcrum 서비스 재시작에 실패했습니다."
    
    # 서비스 재시작 확인
    sleep 5
    if systemctl is-active --quiet fulcrum; then
        log "Fulcrum 서비스가 성공적으로 재시작되었습니다."
    else
        log "경고: Fulcrum 서비스 재시작 후 활성화되지 않았습니다."
    fi
else
    log "Fulcrum 서비스가 실행 중이 아니거나 설치되어 있지 않습니다."
fi

# Onion 주소 확인 및 표시
log "Onion 주소 확인 중..."
sleep 10  # Hidden Service 주소 생성을 위한 충분한 대기 시간

# Bitcoin Core Onion 주소
if [ -f "/var/lib/tor/bitcoin-service/hostname" ]; then
    BITCOIN_ONION=$(sudo cat /var/lib/tor/bitcoin-service/hostname)
    log "Bitcoin Core Onion 주소: ${BITCOIN_ONION}"
else
    log "경고: Bitcoin Core Onion 주소 파일을 찾을 수 없습니다."
fi

# Fulcrum Onion 주소
if [ -f "/var/lib/tor/fulcrum-service/hostname" ]; then
    FULCRUM_ONION=$(sudo cat /var/lib/tor/fulcrum-service/hostname)
    log "Fulcrum Onion 주소: ${FULCRUM_ONION}"
else
    log "경고: Fulcrum Onion 주소 파일을 찾을 수 없습니다."
fi

log "Tor 설정이 완료되었습니다."
log "이제 Tor 네트워크를 통해 Bitcoin Core와 Fulcrum에 접속할 수 있습니다."
log "로그 파일이 저장된 위치: $(pwd)/$LOG_FILE"

# 토르 설정이 완료된 후 실행되는 부분

# 토르 서비스가 완전히 시작될 때까지 대기
sleep 5

# 결과를 저장할 파일 경로 설정
OUTPUT_FILE="./tor_info.json"

# 노드 접속용 토르 주소 가져오기
if [ -f "/var/lib/tor/bitcoin-service/hostname" ]; then
    NODE_ONION_ADDRESS=$(sudo cat /var/lib/tor/bitcoin-service/hostname)
    NODE_PORT=8333  # 비트코인 노드의 기본 포트
else
    log "경고: 비트코인 노드 Onion 주소 파일을 찾을 수 없습니다."
    NODE_ONION_ADDRESS="주소를 찾을 수 없음"
    NODE_PORT=8333
fi

# 풀크럼 접속용 토르 주소 가져오기
if [ -f "/var/lib/tor/fulcrum-service/hostname" ]; then
    FULCRUM_ONION_ADDRESS=$(sudo cat /var/lib/tor/fulcrum-service/hostname)
    FULCRUM_RPC_PORT=50001  # 풀크럼 RPC 포트
    FULCRUM_SSL_PORT=50002  # 풀크럼 SSL 포트
else
    log "경고: 풀크럼 Onion 주소 파일을 찾을 수 없습니다."
    FULCRUM_ONION_ADDRESS="주소를 찾을 수 없음"
    FULCRUM_RPC_PORT=50001
    FULCRUM_SSL_PORT=50002
fi

# JSON 형식으로 출력
cat > "${OUTPUT_FILE}" << EOF
{
  "node": {
    "onion_address": "${NODE_ONION_ADDRESS}",
    "port": ${NODE_PORT}
  },
  "fulcrum": {
    "rpc": {
      "onion_address": "${FULCRUM_ONION_ADDRESS}",
      "port": ${FULCRUM_RPC_PORT}
    },
    "ssl": {
      "onion_address": "${FULCRUM_ONION_ADDRESS}",
      "port": ${FULCRUM_SSL_PORT}
    }
  }
}
EOF

log "토르 주소 정보가 ${OUTPUT_FILE} 파일에 저장되었습니다."

# JSON 내용 출력
cat "${OUTPUT_FILE}" || log "JSON 파일 출력 실패"

# nodeddkkee_env.sh에서 FULCRUM_CONF_DIR 경로 가져오기
source nodeddkkee_env.sh

# fulcrum.conf 파일에 토르 주소 추가
FULCRUM_CONF="${FULCRUM_CONF_DIR}/fulcrum.conf"
if [ -f "$FULCRUM_CONF" ]; then
    echo "tor_hostname=${FULCRUM_ONION_ADDRESS}" >> "$FULCRUM_CONF"
    echo "tor_tcp_port=50001" >> "$FULCRUM_CONF"
    log "Fulcrum 설정 파일에 Tor 주소를 추가했습니다."
else
    log "경고: Fulcrum 설정 파일을 찾을 수 없습니다: $FULCRUM_CONF"
fi 