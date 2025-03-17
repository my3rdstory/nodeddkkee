#!/bin/bash

# 오류 발생 시 스크립트 중단
set -e

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

# 작업 디렉토리 설정
WORK_DIR="/home/${REAL_USER}/live"
DASHBOARD_SERVICE="dashboard"
DASHBOARD_PATH="${WORK_DIR}/dashboard.py"

# .streamlit 디렉토리 생성 및 설정
echo "스트림릿 설정 디렉토리 생성 중..."
mkdir -p ${WORK_DIR}/.streamlit
chown -R ${REAL_USER}:${REAL_USER} ${WORK_DIR}/.streamlit

# config.toml 파일 생성
echo "스트림릿 설정 파일 생성 중..."
cat > ${WORK_DIR}/.streamlit/config.toml << EOF
[server]
# 서버 주소 및 포트 설정
address = "0.0.0.0"
port = 8501

# 프로덕션 모드 설정
runOnSave = false
headless = true

[browser]
# 자동으로 브라우저 열기 비활성화
serverAddress = "localhost"
gatherUsageStats = false

[theme]
# 테마 설정
primaryColor = "#FF4B4B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"

[client]
# 클라이언트 설정
showErrorDetails = false
toolbarMode = "minimal"

[ui]
# UI 요소 숨기기
hideTopBar = true
hideSidebarNav = true
EOF

# 설정 파일 권한 설정
chown ${REAL_USER}:${REAL_USER} ${WORK_DIR}/.streamlit/config.toml
chmod 644 ${WORK_DIR}/.streamlit/config.toml

# systemd 서비스 파일 생성
create_service_file() {
    cat > /etc/systemd/system/${DASHBOARD_SERVICE}.service << EOF
[Unit]
Description=Bitcoin Node Dashboard
After=network.target bitcoind.service
Requires=bitcoind.service

[Service]
User=${REAL_USER}
WorkingDirectory=${WORK_DIR}
ExecStart=/usr/local/bin/streamlit run ${DASHBOARD_PATH} --server.address 0.0.0.0 --server.port 8501
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

# 필요한 패키지 설치
echo "파이썬 패키지 설치 중..."
pip3 install -r ${WORK_DIR}/requirements.txt

# 서비스 파일 생성
echo "대시보드 서비스 파일 생성 중..."
create_service_file

# systemd 리로드
systemctl daemon-reload

# 서비스 시작
echo "대시보드 서비스 시작 중..."
systemctl enable ${DASHBOARD_SERVICE}
systemctl start ${DASHBOARD_SERVICE}

echo "대시보드 설치가 완료되었습니다."
echo "브라우저에서 http://localhost:8501 로 접속하여 확인하실 수 있습니다."