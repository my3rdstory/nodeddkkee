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

# Bitcoin 관련 파일 제거
echo "Bitcoin 서비스 중지 및 파일 제거 중..."
sudo systemctl stop bitcoind
sudo apt remove --purge bitcoind bitcoin-qt bitcoin-cli -y
sudo apt autoremove -y
# rm -rf $REAL_HOME/downloads
# rm -rf $REAL_HOME/.bitcoin
echo "Bitcoin 제거 완료"

# Tor 관련 파일 제거
echo "Tor 서비스 중지 및 파일 제거 중..."
sudo systemctl stop tor
sudo apt remove --purge tor -y
sudo apt autoremove -y
rm -rf $REAL_HOME/.tor /var/lib/tor /etc/tor
rm -rf $REAL_HOME/tor_info.json
echo "Tor 제거 완료"

# Fulcrum 관련 파일 제거
echo "Fulcrum 서비스 중지 및 파일 제거 중..."
sudo systemctl stop fulcrum
rm -rf $REAL_HOME/fulcrum
# rm -rf $REAL_HOME/fulcrum_db
echo "Fulcrum 제거 완료"

# 서비스 비활성화 및 데몬 리로드
echo "서비스 비활성화 및 시스템 데몬 리로드 중..."
sudo systemctl disable bitcoind tor fulcrum
sudo systemctl daemon-reload
echo "서비스 비활성화 완료"

echo "===== 모든 제거 작업이 완료되었습니다 ====="

