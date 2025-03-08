#!/bin/bash

# 1_core.sh에서 설정한 변수들을 가져오기 위한 환경 파일 생성
if [ -f "./1_core.sh" ]; then
    # 1_core.sh에서 변수 설정 부분만 추출
    grep -E "^[A-Z_]+=.*$" ./1_core.sh > ./core_vars.env
    source ./core_vars.env
else
    echo "오류: 1_core.sh 파일을 찾을 수 없습니다."
    exit 1
fi

# 필수 변수 확인
if [ -z "$USER_NAME" ] || [ -z "$USER_HOME" ]; then
    echo "오류: 필수 변수가 설정되지 않았습니다."
    exit 1
fi

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

if sudo grep -q "HiddenServiceDir /var/lib/tor/electrs-service/" /etc/tor/torrc; then
    log "Electrs Hidden Service 설정이 이미 존재합니다."
    ELECTRS_SERVICE_EXISTS=true
else
    ELECTRS_SERVICE_EXISTS=false
fi

# 사용자 확인
if [ "$BITCOIN_SERVICE_EXISTS" = false ] || [ "$ELECTRS_SERVICE_EXISTS" = false ]; then
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
        
        if [ "$ELECTRS_SERVICE_EXISTS" = false ]; then
            TOR_CONFIG+="
# Electrs Hidden Service
HiddenServiceDir /var/lib/tor/electrs-service/
HiddenServiceVersion 3
HiddenServicePort 50001 127.0.0.1:50001
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
for DIR in "/var/lib/tor/bitcoin-service/" "/var/lib/tor/electrs-service/"; do
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
                
                # 서비스 재시작 확인 (최대 10번 시도)
                for attempt in {1..5}; do
                    log "Bitcoin Core 서비스 상태 확인 중... (시도 $attempt/10)"
                    sleep 5
                    if systemctl is-active --quiet bitcoind; then
                        log "Bitcoin Core 서비스가 성공적으로 재시작되었습니다."
                        break
                    elif [ $attempt -eq 10 ]; then
                        log "경고: Bitcoin Core 서비스가 10번의 시도 후에도 활성화되지 않았습니다."
                    fi
                done
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

# Electrs 서비스 재시작 (설치되어 있는 경우)
if systemctl is-active --quiet electrs; then
    log "Electrs 서비스 재시작 중..."
    sudo systemctl restart electrs || log "Electrs 서비스 재시작에 실패했습니다."
    
    # 서비스 재시작 확인
    sleep 5
    if systemctl is-active --quiet electrs; then
        log "Electrs 서비스가 성공적으로 재시작되었습니다."
    else
        log "경고: Electrs 서비스 재시작 후 활성화되지 않았습니다."
    fi
else
    log "Electrs 서비스가 실행 중이 아니거나 설치되어 있지 않습니다."
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

# Electrs Onion 주소
if [ -f "/var/lib/tor/electrs-service/hostname" ]; then
    ELECTRS_ONION=$(sudo cat /var/lib/tor/electrs-service/hostname)
    log "Electrs Onion 주소: ${ELECTRS_ONION}"
else
    log "경고: Electrs Onion 주소 파일을 찾을 수 없습니다."
fi

log "Tor 설정이 완료되었습니다."
log "이제 Tor 네트워크를 통해 Bitcoin Core와 Electrs에 접속할 수 있습니다."
log "로그 파일이 저장된 위치: $(pwd)/$LOG_FILE"

# 토르 설정이 완료된 후 실행되는 부분

# 토르 서비스가 완전히 시작될 때까지 대기
sleep 5

# 결과를 저장할 파일 경로 설정
OUTPUT_FILE="./tor_info.json"

# 노드 접속용 토르 주소 가져오기
if [ -f "/var/lib/tor/bitcoin-service/hostname" ]; then
    NODE_ONION_ADDRESS=$(sudo cat /var/lib/tor/bitcoin-service/hostname)
    NODE_PORT=8332
else
    log "경고: 비트코인 노드 Onion 주소 파일을 찾을 수 없습니다."
    NODE_ONION_ADDRESS="주소를 찾을 수 없음"
    NODE_PORT=8332
fi

# Electrs 접속용 토르 주소 가져오기
if [ -f "/var/lib/tor/electrs-service/hostname" ]; then
    ELECTRS_ONION_ADDRESS=$(sudo cat /var/lib/tor/electrs-service/hostname)
    ELECTRS_PORT=50001  # Electrs 포트
else
    log "경고: Electrs Onion 주소 파일을 찾을 수 없습니다."
    ELECTRS_ONION_ADDRESS="주소를 찾을 수 없음"
    ELECTRS_PORT=50001
fi

# JSON 형식으로 출력
cat > "${OUTPUT_FILE}" << EOF
{
  "node": {
    "onion_address": "${NODE_ONION_ADDRESS}",
    "port": ${NODE_PORT}
  },
  "electrs": {
    "onion_address": "${ELECTRS_ONION_ADDRESS}",
    "port": ${ELECTRS_PORT}
  }
}
EOF

log "토르 주소 정보가 ${OUTPUT_FILE} 파일에 저장되었습니다."

# JSON 내용 출력
cat "${OUTPUT_FILE}" || log "JSON 파일 출력 실패"

# nodeddkkee_env.sh에서 ELECTRS_CONF_DIR 경로 가져오기
source nodeddkkee_env.sh

# electrs.toml 파일에 토르 주소 추가
ELECTRS_CONF="${ELECTRS_CONF_DIR}/electrs.toml"
if [ -f "$ELECTRS_CONF" ]; then
    echo "tor_proxy = \"127.0.0.1:9050\"" >> "$ELECTRS_CONF"
    echo "tor_hostname = \"${ELECTRS_ONION_ADDRESS}\"" >> "$ELECTRS_CONF"
    log "Electrs 설정 파일에 Tor 주소를 추가했습니다."
else
    log "경고: Electrs 설정 파일을 찾을 수 없습니다: $ELECTRS_CONF"
fi 