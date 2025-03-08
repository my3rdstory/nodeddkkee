#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - 서비스 상태 확인 및 재시작
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

# 로그 함수 정의
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 로그 파일 설정
LOG_DIR="./logs"
mkdir -p "$LOG_DIR" || error_exit "로그 디렉토리를 생성할 수 없습니다."
LOG_FILE="$LOG_DIR/service_check_$(date '+%Y%m%d_%H%M%S').log"
touch "$LOG_FILE" || error_exit "로그 파일을 생성할 수 없습니다."

# 환경 변수 로드
if [ -f "nodeddkkee_env.sh" ]; then
    source nodeddkkee_env.sh
    log "환경 변수를 로드했습니다."
else
    error_exit "환경 변수 파일(nodeddkkee_env.sh)을 찾을 수 없습니다. 0_check.sh를 먼저 실행해주세요."
fi

log "서비스 상태 확인 및 재시작 스크립트를 시작합니다..."

# 서비스 상태 확인 및 재시작 함수
check_and_restart_service() {
    local service_name="$1"
    log "${service_name} 서비스 상태 확인 중..."
    
    if systemctl is-active --quiet "$service_name"; then
        log "${service_name} 서비스가 활성화되어 있습니다."
        return 0
    else
        log "${service_name} 서비스가 비활성화 상태입니다. 재시작을 시도합니다."
        
        # 서비스 중지
        log "${service_name} 서비스 중지 중..."
        sudo systemctl stop "$service_name" || {
            log "경고: ${service_name} 서비스 중지에 실패했습니다."
        }
        
        # 잠시 대기
        sleep 3
        
        # 서비스 시작
        log "${service_name} 서비스 시작 중..."
        sudo systemctl start "$service_name" || {
            log "오류: ${service_name} 서비스 시작에 실패했습니다."
            return 1
        }
        
        # 서비스 상태 확인
        sleep 5
        if systemctl is-active --quiet "$service_name"; then
            log "${service_name} 서비스가 성공적으로 재시작되었습니다."
            return 0
        else
            log "오류: ${service_name} 서비스 재시작 후에도 활성화되지 않았습니다."
            log "서비스 로그 확인 중..."
            sudo journalctl -u "$service_name" --no-pager | tail -n 20 >> "$LOG_FILE"
            return 1
        fi
    fi
}

# Bitcoin Core 서비스 확인 및 재시작
log "Bitcoin Core 서비스 확인 중..."
if ! check_and_restart_service "bitcoind"; then
    log "경고: Bitcoin Core 서비스를 활성화할 수 없습니다."
fi

# Electrs 서비스 확인 및 재시작
log "Electrs 서비스 확인 중..."
if ! check_and_restart_service "electrs"; then
    log "경고: Electrs 서비스를 활성화할 수 없습니다."
fi

# Tailscale 서비스 확인 및 재시작
log "Tailscale 서비스 확인 중..."
if ! check_and_restart_service "tailscaled"; then
    log "경고: Tailscale 서비스를 활성화할 수 없습니다."
fi

# 최종 서비스 상태 확인
log "최종 서비스 상태 확인 중..."
BITCOIN_ACTIVE=$(systemctl is-active bitcoind)
ELECTRS_ACTIVE=$(systemctl is-active electrs)
TAILSCALE_ACTIVE=$(systemctl is-active tailscaled)

log "Bitcoin Core 서비스 상태: $BITCOIN_ACTIVE"
log "Electrs 서비스 상태: $ELECTRS_ACTIVE"
log "Tailscale 서비스 상태: $TAILSCALE_ACTIVE"

# 모든 서비스가 활성화되었는지 확인
if [ "$BITCOIN_ACTIVE" = "active" ] && [ "$ELECTRS_ACTIVE" = "active" ] && [ "$TAILSCALE_ACTIVE" = "active" ]; then
    log "모든 서비스가 정상적으로 활성화되었습니다."
    
    # Tailscale IP 확인
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TAILSCALE_IP" ]; then
        log "Tailscale IP: $TAILSCALE_IP"
        
        # 접속 정보 업데이트
        log "접속 정보 업데이트 중..."
        TS_INFO_FILE="./ts_info.json"
        cat > "${TS_INFO_FILE}" << EOF
{
  "hostname": "$(hostname)",
  "tailscale": {
    "ip_address": "${TAILSCALE_IP}",
    "connected": true,
    "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
  },
  "services": {
    "bitcoin_core": {
      "port": ${BITCOIN_PORT},
      "connected": true,
      "url": "http://${TAILSCALE_IP}:${BITCOIN_PORT}/"
    },
    "electrs": {
      "port": ${ELECTRS_PORT},
      "connected": true,
      "url": "${TAILSCALE_IP}:${ELECTRS_PORT}"
    }
  },
  "connection_info": {
    "bitcoin_core_rpc": "http://${RPC_USER}:${RPC_PASS}@${TAILSCALE_IP}:${BITCOIN_PORT}/",
    "electrs_server": "${TAILSCALE_IP}:${ELECTRS_PORT}"
  }
}
EOF
        log "접속 정보가 ${TS_INFO_FILE} 파일에 업데이트되었습니다."
    else
        log "경고: Tailscale IP를 가져올 수 없습니다."
    fi
else
    log "경고: 일부 서비스가 활성화되지 않았습니다."
    if [ "$BITCOIN_ACTIVE" != "active" ]; then
        log "Bitcoin Core 서비스가 활성화되지 않았습니다."
    fi
    if [ "$ELECTRS_ACTIVE" != "active" ]; then
        log "Electrs 서비스가 활성화되지 않았습니다."
    fi
    if [ "$TAILSCALE_ACTIVE" != "active" ]; then
        log "Tailscale 서비스가 활성화되지 않았습니다."
    fi
fi

log "서비스 상태 확인 및 재시작 스크립트가 완료되었습니다."
log "로그 파일이 저장된 위치: $LOG_FILE" 