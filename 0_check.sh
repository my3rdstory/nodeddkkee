#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee) - 시스템 확인 및 준비
# 작성자: DedSec
# 엑스: https://x.com/_orangepillkr
# 유튜브: https://www.youtube.com/@orangepillkr/
# 스페셜땡쓰: 셀프카스타드님 https://florentine-porkpie-563.notion.site/2e905cab90ae4a979711ec40bbb85d64?v=7c329be91bd44a03928fcfa3ed4c3fe4
# 라이선스: 없음
# 주의: 저는 코딩 못합니다. 커서 조져서 대충 만든거에요. 제 오드로이드 H4 기기에서만 테스트했습니다. 다른 기기에서 동작을 보장하지 않습니다. 수정 요청하지 마시고 포크해서 마음껏 사용하세요. 

# sudo 권한 확인 및 비밀번호 캐싱
check_sudo() {
    echo "관리자 권한이 필요합니다. 비밀번호를 요청할 수 있습니다."
    # sudo 인증 캐시 갱신 (비밀번호 입력 요청)
    sudo -v
    
    # 인증 캐시 유지를 위한 백그라운드 프로세스 실행
    (while true; do sudo -v; sleep 50; done) &
    SUDO_PID=$!
    
    # 스크립트 종료 시 백그라운드 프로세스 종료
    trap 'kill -9 $SUDO_PID' EXIT
}

# 오류 처리 함수 정의
error_exit() {
    echo "오류: $1" >&2
    exit 1
}

# 사용자 계정 감지 및 설정
detect_user() {
    # 현재 로그인한 사용자 계정 자동 감지
    if [ "$(whoami)" = "root" ]; then
        # 스크립트가 root로 실행된 경우, SUDO_USER 환경 변수를 확인
        if [ -n "$SUDO_USER" ]; then
            USER_NAME="$SUDO_USER"
        else
            # SUDO_USER가 없는 경우 사용자에게 물어봄
            echo "스크립트가 root로 실행되었습니다. Bitcoin Core를 실행할 사용자 계정을 입력하세요:"
            read -p "사용자 계정: " USER_NAME
            if [ -z "$USER_NAME" ] || ! id "$USER_NAME" &>/dev/null; then
                error_exit "유효하지 않은 사용자 계정입니다."
            fi
        fi
        echo "Bitcoin Core는 사용자 '$USER_NAME'로 실행됩니다."
    else
        USER_NAME=$(whoami) || error_exit "사용자 계정을 감지할 수 없습니다."
    fi
}

# 시스템 업데이트 및 필요한 패키지 설치
update_system() {
    echo "시스템 업데이트 중..."
    sudo apt update && sudo apt upgrade -y || error_exit "시스템 업데이트에 실패했습니다."
    
    echo "필요한 패키지 설치 중..."
    sudo apt -y install git nano net-tools jq tor htop glances build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python3 python3-pip cmake cargo clang libssl-dev || error_exit "필요한 패키지 설치에 실패했습니다."
}

# 다운로드 디렉토리 생성
create_download_dir() {
    echo "다운로드 디렉토리 생성 중..."
    cd ~ || error_exit "홈 디렉토리로 이동할 수 없습니다."
    mkdir -p downloads || error_exit "다운로드 디렉토리를 생성할 수 없습니다."
}

# 메인 실행 흐름
echo "시스템 확인 및 준비 스크립트를 시작합니다..."

# sudo 권한 확인
check_sudo

# 사용자 계정 감지 및 설정
detect_user

# 시스템 업데이트 및 필요한 패키지 설치
update_system

# 다운로드 디렉토리 생성
create_download_dir

# nodeddkkee_env.sh 파일 실행
if [ -f "/home/${USER_NAME}/nodeddkkee_env.sh" ]; then
    chmod +x "/home/${USER_NAME}/nodeddkkee_env.sh"
    source "/home/${USER_NAME}/nodeddkkee_env.sh"
else
    error_exit "nodeddkkee_env.sh 파일이 존재하지 않습니다."
fi

echo "시스템 확인 및 준비가 완료되었습니다."