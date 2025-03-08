#!/bin/bash

# 제거 스크립트

# 스크립트가 루트 권한으로 실행되는지 확인
if [ "$(id -u)" -ne 0 ]; then
    echo "이 스크립트는 루트 권한으로 실행해야 합니다. sudo를 사용해주세요."
    exit 1
fi

# 실제 사용자 홈 디렉토리 가져오기
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
REAL_HOME=$(getent passwd $REAL_USER | cut -d: -f6)

echo "===== Bitcoin, Tor, Fulcrum 제거 스크립트 시작 ====="
echo "사용자: $REAL_USER, 홈 디렉토리: $REAL_HOME"

# 서비스 제거 시간 측정 함수
measure_time() {
    local start_time=$(date +%s)
    "$@"
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    echo "$1에 걸린 시간: ${elapsed_time}초"
}

# Bitcoin 관련 파일 제거
echo "Bitcoin 서비스 중지 및 파일 제거 중..."
measure_time sudo systemctl stop bitcoind
measure_time sudo apt remove --purge bitcoind bitcoin-qt bitcoin-cli -y
measure_time sudo apt autoremove -y
echo "Bitcoin 제거 완료"

# Tor 관련 파일 제거
echo "Tor 서비스 중지 및 파일 제거 중..."
measure_time sudo systemctl stop tor
measure_time sudo apt remove --purge tor -y
measure_time sudo apt autoremove -y
measure_time rm -rf $REAL_HOME/.tor /var/lib/tor /etc/tor
measure_time rm -rf $REAL_HOME/tor_info.json
echo "Tor 제거 완료"

# Electrs 관련 파일 제거
echo "Electrs 서비스 중지 및 파일 제거 중..."
measure_time sudo systemctl stop electrs
measure_time rm -rf $REAL_HOME/electrs/src
measure_time rm -rf $REAL_HOME/electrs/.git
measure_time rm -rf $REAL_HOME/electrs/.github
measure_time rm -rf $REAL_HOME/electrs/doc
measure_time rm -rf $REAL_HOME/electrs/contrib
# data 폴더와 빌드된 파일 보존
echo "Electrs 제거 완료 (데이터 폴더와 빌드된 파일 보존됨)"

# 서비스 비활성화 및 데몬 리로드
echo "서비스 비활성화 및 시스템 데몬 리로드 중..."

# 테일스케일 서비스 중지
echo "테일스케일 서비스 중지 중..."
measure_time sudo systemctl stop tailscaled
echo "테일스케일 서비스 중지 완료"

measure_time sudo systemctl disable bitcoind tor electrs fulcrum tailscaled
measure_time sudo systemctl daemon-reload
echo "서비스 비활성화 완료"

# 모든 서비스가 중지되었는지 확인
echo "모든 서비스가 중지되었는지 확인 중..."
SERVICES=("bitcoind" "tor" "electrs" "fulcrum" "tailscaled")
MAX_ATTEMPTS=10

for service in "${SERVICES[@]}"; do
    attempts=0
    while systemctl is-active --quiet $service 2>/dev/null && [ $attempts -lt $MAX_ATTEMPTS ]; do
        echo "$service 서비스가 아직 실행 중입니다. 중지 시도 중... (시도 $((attempts+1))/$MAX_ATTEMPTS)"
        sudo systemctl stop $service
        sleep 2
        ((attempts++))
    done
    
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "경고: $service 서비스를 $MAX_ATTEMPTS회 시도 후에도 중지할 수 없습니다."
    else
        echo "$service 서비스가 성공적으로 중지되었습니다."
    fi
done

echo "서비스 중지 확인 완료"

echo "===== 모든 제거 작업이 완료되었습니다 ====="

