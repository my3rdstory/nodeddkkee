#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - Tailscale 설정
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
LOG_FILE="${LOGS_DIR}/tailscale_setup_$(date +%Y%m%d_%H%M%S).log"
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
log "Tailscale 설정 스크립트를 시작합니다..."
log "사용자 계정: ${USER_NAME}"

# 사용자 확인 함수
confirm() {
    # 항상 true 반환하도록 수정 (자동 진행)
    return 0
}

# 방화벽 설정 함수
setup_firewall() {
    log "방화벽 설정을 확인하고 필요한 포트를 개방합니다..."
    
    # UFW가 설치되어 있는지 확인
    if command -v ufw &> /dev/null; then
        log "UFW 방화벽이 설치되어 있습니다. UFW를 사용하여 포트를 개방합니다."
        
        # UFW 상태 확인
        UFW_STATUS=$(sudo ufw status | grep "Status: active" || echo "inactive")
        if [[ "$UFW_STATUS" == *"inactive"* ]]; then
            log "UFW가 비활성화되어 있습니다. 포트 개방 후 활성화합니다."
            # 필요한 포트 개방
            sudo ufw allow 41641/udp comment 'Tailscale' || log "Tailscale 포트 개방 실패"
            sudo ufw allow 8332/tcp comment 'Bitcoin Core' || log "Bitcoin Core 포트 개방 실패"
            sudo ufw allow 50001/tcp comment 'Electrs' || log "Electrs 포트 개방 실패"
            
            # SSH 포트 개방 (기본 22번)
            sudo ufw allow 22/tcp comment 'SSH' || log "SSH 포트 개방 실패"
            
            # UFW 활성화 (자동 yes 응답)
            echo "y" | sudo ufw enable || log "UFW 활성화 실패"
            log "UFW가 활성화되었으며 필요한 포트가 개방되었습니다."
        else
            log "UFW가 이미 활성화되어 있습니다. 필요한 포트를 개방합니다."
            # 이미 포트가 열려있는지 확인 후 개방
            if ! sudo ufw status | grep -q "41641/udp"; then
                sudo ufw allow 41641/udp comment 'Tailscale' || log "Tailscale 포트 개방 실패"
                log "Tailscale 포트(41641/udp)가 개방되었습니다."
            else
                log "Tailscale 포트(41641/udp)가 이미 개방되어 있습니다."
            fi
            
            if ! sudo ufw status | grep -q "8332/tcp"; then
                sudo ufw allow 8332/tcp comment 'Bitcoin Core' || log "Bitcoin Core 포트 개방 실패"
                log "Bitcoin Core 포트(8332/tcp)가 개방되었습니다."
            else
                log "Bitcoin Core 포트(8332/tcp)가 이미 개방되어 있습니다."
            fi
            
            if ! sudo ufw status | grep -q "50001/tcp"; then
                sudo ufw allow 50001/tcp comment 'Electrs' || log "Electrs 포트 개방 실패"
                log "Electrs 포트(50001/tcp)가 개방되었습니다."
            else
                log "Electrs 포트(50001/tcp)가 이미 개방되어 있습니다."
            fi
        fi
    # iptables 사용
    elif command -v iptables &> /dev/null; then
        log "iptables를 사용하여 포트를 개방합니다."
        
        # 이미 규칙이 있는지 확인 후 추가
        if ! sudo iptables -C INPUT -p udp --dport 41641 -j ACCEPT 2>/dev/null; then
            sudo iptables -A INPUT -p udp --dport 41641 -j ACCEPT || log "Tailscale 포트 개방 실패"
            log "Tailscale 포트(41641/udp)가 개방되었습니다."
        else
            log "Tailscale 포트(41641/udp)가 이미 개방되어 있습니다."
        fi
        
        if ! sudo iptables -C INPUT -p tcp --dport 8332 -j ACCEPT 2>/dev/null; then
            sudo iptables -A INPUT -p tcp --dport 8332 -j ACCEPT || log "Bitcoin Core 포트 개방 실패"
            log "Bitcoin Core 포트(8332/tcp)가 개방되었습니다."
        else
            log "Bitcoin Core 포트(8332/tcp)가 이미 개방되어 있습니다."
        fi
        
        if ! sudo iptables -C INPUT -p tcp --dport 50001 -j ACCEPT 2>/dev/null; then
            sudo iptables -A INPUT -p tcp --dport 50001 -j ACCEPT || log "Electrs 포트 개방 실패"
            log "Electrs 포트(50001/tcp)가 개방되었습니다."
        else
            log "Electrs 포트(50001/tcp)가 이미 개방되어 있습니다."
        fi
        
        # iptables 규칙 저장
        if command -v netfilter-persistent &> /dev/null; then
            sudo netfilter-persistent save || log "iptables 규칙 저장 실패"
            log "iptables 규칙이 저장되었습니다."
        elif [ -d "/etc/iptables" ]; then
            sudo sh -c "iptables-save > /etc/iptables/rules.v4" || log "iptables 규칙 저장 실패"
            log "iptables 규칙이 저장되었습니다."
        else
            log "경고: iptables 규칙을 영구적으로 저장할 수 없습니다. 재부팅 시 규칙이 초기화될 수 있습니다."
        fi
    else
        log "경고: 지원되는 방화벽(UFW 또는 iptables)을 찾을 수 없습니다. 포트 개방을 건너뜁니다."
    fi
    
    log "방화벽 설정이 완료되었습니다."
}

# Tailscale 설치 확인
log "Tailscale 설치 확인 중..."
if ! command -v tailscale &> /dev/null; then
    log "Tailscale이 설치되어 있지 않습니다. 설치를 진행합니다..."
    
    # Tailscale 저장소 키 추가
    log "Tailscale 저장소 키 추가 중..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add - || error_exit "Tailscale 저장소 키 추가에 실패했습니다."
    
    # Tailscale 저장소 추가
    log "Tailscale 저장소 추가 중..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list || error_exit "Tailscale 저장소 추가에 실패했습니다."
    
    # 패키지 목록 업데이트 및 Tailscale 설치
    log "패키지 목록 업데이트 및 Tailscale 설치 중..."
    sudo apt-get update
    sudo apt-get install -y tailscale || error_exit "Tailscale 설치에 실패했습니다."
    
    log "Tailscale이 성공적으로 설치되었습니다."
else
    log "Tailscale이 이미 설치되어 있습니다."
fi

# 방화벽 설정 실행
setup_firewall

# Tailscale 서비스 상태 확인
log "Tailscale 서비스 상태 확인 중..."
if ! systemctl is-active --quiet tailscaled; then
    log "Tailscale 서비스가 실행 중이 아닙니다. 서비스를 시작합니다..."
    sudo systemctl start tailscaled || error_exit "Tailscale 서비스 시작에 실패했습니다."
else
    log "Tailscale 서비스가 이미 실행 중입니다."
fi

# Tailscale 서비스 자동 시작 설정
if ! systemctl is-enabled --quiet tailscaled; then
    log "Tailscale 서비스가 부팅 시 자동 시작되도록 설정합니다..."
    sudo systemctl enable tailscaled || log "Tailscale 서비스 자동 시작 설정에 실패했습니다."
else
    log "Tailscale 서비스가 이미 부팅 시 자동 시작되도록 설정되어 있습니다."
fi

# Tailscale 로그인 상태 확인
log "Tailscale 로그인 상태 확인 중..."
TAILSCALE_STATUS=$(sudo tailscale status 2>/dev/null)
if echo "$TAILSCALE_STATUS" | grep -q "Logged out"; then
    log "Tailscale에 로그인되어 있지 않습니다. 로그인을 진행합니다..."
    
    # 사용자 확인
    if confirm "Tailscale에 로그인하시겠습니까? (브라우저에서 인증 필요)"; then
        # Tailscale 로그인 (SSH 접속 허용 옵션 추가)
        log "Tailscale 로그인 중... (SSH 접속 허용)"
        sudo tailscale up --ssh || error_exit "Tailscale 로그인에 실패했습니다."
        
        # 로그인 성공 확인
        if sudo tailscale status | grep -q "Logged out"; then
            log "경고: Tailscale 로그인에 실패했습니다."
        else
            log "Tailscale 로그인에 성공했습니다."
        fi
    else
        log "사용자가 Tailscale 로그인을 취소했습니다."
    fi
else
    log "Tailscale에 이미 로그인되어 있습니다."
fi

# Tailscale IP 주소 확인
log "Tailscale IP 주소 확인 중..."
TAILSCALE_IP=$(sudo tailscale ip 2>/dev/null)
if [ -n "$TAILSCALE_IP" ]; then
    log "Tailscale IP 주소: ${TAILSCALE_IP}"
else
    log "경고: Tailscale IP 주소를 확인할 수 없습니다."
fi

# Bitcoin Core 및 Electrs 서비스 포트 확인
log "Bitcoin Core 및 Electrs 서비스 포트 확인 중..."
BITCOIN_PORT=8332
ELECTRS_PORT=50001

# 결과를 저장할 파일 경로 설정
OUTPUT_FILE="./tailscale_info.json"

# JSON 형식으로 출력
cat > "${OUTPUT_FILE}" << EOF
{
  "tailscale": {
    "ip_address": "${TAILSCALE_IP}",
    "bitcoin_port": ${BITCOIN_PORT},
    "electrs_port": ${ELECTRS_PORT}
  }
}
EOF

log "Tailscale 정보가 ${OUTPUT_FILE} 파일에 저장되었습니다."

# JSON 내용 출력
cat "${OUTPUT_FILE}" || log "JSON 파일 출력 실패"

# Bitcoin Core 설정 파일 수정
log "Bitcoin Core 설정 파일 확인 중..."
BITCOIN_CONF="/home/${USER_NAME}/.bitcoin/bitcoin.conf"
if [ -f "$BITCOIN_CONF" ]; then
    # 이미 rpcallowip 설정이 있는지 확인
    if grep -q "rpcallowip=10.0.0.0/8" "$BITCOIN_CONF"; then
        log "Bitcoin Core 설정 파일에 이미 Tailscale 네트워크 허용 설정이 있습니다."
    else
        # 사용자 확인
        if confirm "Bitcoin Core 설정 파일에 Tailscale 네트워크 허용 설정을 추가하시겠습니까?"; then
            # 설정 추가
            cat >> "$BITCOIN_CONF" << EOF || error_exit "Bitcoin Core 설정 파일 수정에 실패했습니다."

# Tailscale 네트워크 허용 설정
rpcallowip=10.0.0.0/8
rpcbind=0.0.0.0
EOF
            log "Bitcoin Core 설정 파일에 Tailscale 네트워크 허용 설정을 추가했습니다."
            
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

# Electrs 설정 파일 수정
log "Electrs 설정 파일 확인 중..."
source nodeddkkee_env.sh
ELECTRS_CONF="${ELECTRS_CONF_DIR}/electrs.toml"
if [ -f "$ELECTRS_CONF" ]; then
    # 이미 bind_addr 설정이 있는지 확인
    if grep -q "bind_addr = \"0.0.0.0:50001\"" "$ELECTRS_CONF"; then
        log "Electrs 설정 파일에 이미 모든 인터페이스 바인딩 설정이 있습니다."
    else
        # 사용자 확인
        if confirm "Electrs 설정 파일에 모든 인터페이스 바인딩 설정을 추가하시겠습니까?"; then
            # 설정 추가
            echo "bind_addr = \"0.0.0.0:50001\"" >> "$ELECTRS_CONF" || error_exit "Electrs 설정 파일 수정에 실패했습니다."
            log "Electrs 설정 파일에 모든 인터페이스 바인딩 설정을 추가했습니다."
            
            # Electrs 서비스 재시작
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
        else
            log "사용자가 Electrs 설정 파일 수정을 취소했습니다."
        fi
    fi
else
    log "경고: Electrs 설정 파일을 찾을 수 없습니다: $ELECTRS_CONF"
fi

# 테일스케일 접속 확인
log "Tailscale 접속 확인 중..."
TAILSCALE_PING_RESULT=$(ping -c 3 ${TAILSCALE_IP} 2>&1)
if echo "$TAILSCALE_PING_RESULT" | grep -q "bytes from"; then
    log "Tailscale 접속 확인 성공: ${TAILSCALE_IP}에 접속할 수 있습니다."
    TAILSCALE_CONNECTED=true
else
    log "경고: Tailscale 접속 확인 실패: ${TAILSCALE_IP}에 접속할 수 없습니다."
    TAILSCALE_CONNECTED=false
fi

# Bitcoin Core 접속 확인
log "Bitcoin Core 접속 확인 중..."
if command -v curl &> /dev/null && [ -f "$BITCOIN_CONF" ]; then
    RPC_USER=$(grep -oP "rpcuser=\K.*" "$BITCOIN_CONF" | head -1)
    RPC_PASS=$(grep -oP "rpcpassword=\K.*" "$BITCOIN_CONF" | head -1)
    
    if [ -n "$RPC_USER" ] && [ -n "$RPC_PASS" ]; then
        BITCOIN_TEST_RESULT=$(curl --silent --user "${RPC_USER}:${RPC_PASS}" --data-binary '{"jsonrpc":"1.0","method":"getblockchaininfo","params":[],"id":1}' -H 'content-type: text/plain;' http://${TAILSCALE_IP}:${BITCOIN_PORT}/ 2>&1)
        
        if echo "$BITCOIN_TEST_RESULT" | grep -q "blocks"; then
            log "Bitcoin Core 접속 확인 성공: ${TAILSCALE_IP}:${BITCOIN_PORT}에 접속할 수 있습니다."
            BITCOIN_CONNECTED=true
        else
            log "경고: Bitcoin Core 접속 확인 실패: ${TAILSCALE_IP}:${BITCOIN_PORT}에 접속할 수 없습니다."
            BITCOIN_CONNECTED=false
        fi
    else
        log "경고: Bitcoin Core RPC 사용자 정보를 찾을 수 없습니다."
        BITCOIN_CONNECTED=false
    fi
else
    log "경고: curl 명령어를 찾을 수 없거나 Bitcoin Core 설정 파일이 없습니다."
    BITCOIN_CONNECTED=false
fi

# Electrs 접속 확인
log "Electrs 접속 확인 중..."
if command -v nc &> /dev/null; then
    if nc -z -w 5 ${TAILSCALE_IP} ${ELECTRS_PORT}; then
        log "Electrs 접속 확인 성공: ${TAILSCALE_IP}:${ELECTRS_PORT}에 접속할 수 있습니다."
        ELECTRS_CONNECTED=true
    else
        log "경고: Electrs 접속 확인 실패: ${TAILSCALE_IP}:${ELECTRS_PORT}에 접속할 수 없습니다."
        ELECTRS_CONNECTED=false
    fi
else
    log "경고: nc 명령어를 찾을 수 없습니다."
    ELECTRS_CONNECTED=false
fi

# 호스트명 가져오기
HOSTNAME=$(hostname)

# 최종 접속 정보를 ts_info.json 파일로 저장
TS_INFO_FILE="./ts_info.json"
cat > "${TS_INFO_FILE}" << EOF
{
  "hostname": "${HOSTNAME}",
  "tailscale": {
    "ip_address": "${TAILSCALE_IP}",
    "connected": ${TAILSCALE_CONNECTED},
    "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
  },
  "services": {
    "bitcoin_core": {
      "port": ${BITCOIN_PORT},
      "connected": ${BITCOIN_CONNECTED},
      "url": "http://${TAILSCALE_IP}:${BITCOIN_PORT}/"
    },
    "electrs": {
      "port": ${ELECTRS_PORT},
      "connected": ${ELECTRS_CONNECTED},
      "url": "${TAILSCALE_IP}:${ELECTRS_PORT}"
    }
  },
  "connection_info": {
    "bitcoin_core_rpc": "http://${RPC_USER}:${RPC_PASS}@${TAILSCALE_IP}:${BITCOIN_PORT}/",
    "electrs_server": "${TAILSCALE_IP}:${ELECTRS_PORT}"
  }
}
EOF

log "Tailscale 접속 정보가 ${TS_INFO_FILE} 파일에 저장되었습니다."

# JSON 내용 출력
cat "${TS_INFO_FILE}" || log "JSON 파일 출력 실패"

log "Tailscale 설정이 완료되었습니다."
log "이제 Tailscale 네트워크를 통해 Bitcoin Core와 Electrs에 접속할 수 있습니다."
log "Tailscale IP 주소: ${TAILSCALE_IP}"
log "Bitcoin Core 접속 정보: ${TAILSCALE_IP}:${BITCOIN_PORT}"
log "Electrs 접속 정보: ${TAILSCALE_IP}:${ELECTRS_PORT}"
log "로그 파일이 저장된 위치: $(pwd)/$LOG_FILE"
log "접속 정보 파일이 저장된 위치: $(pwd)/$TS_INFO_FILE"
