#!/bin/bash

# 프로그램명: 노드딸깍이(Nodeddkkee)
# 작성자: DedSec
# 엑스: https://x.com/_orangepillkr
# 유튜브: https://www.youtube.com/@orangepillkr/
# 스페셜땡쓰: 셀프카스타드님 https://florentine-porkpie-563.notion.site/2e905cab90ae4a979711ec40bbb85d64?v=7c329be91bd44a03928fcfa3ed4c3fe4
# 라이선스: 없음
# 주의: 저는 코딩 못합니다. 커서 조져서 대충 만든거에요. 제 오드로이드 H4 기기에서만 테스트했습니다. 다른 기기에서 동작을 보장하지 않습니다. 수정 요청하지 마시고 포크해서 마음껏 사용하세요. 

# 설치 스크립트 순서 지정

# 오류 처리 함수 정의
error_exit() {
    echo "오류: $1" >&2
    exit 1
}

# 스크립트 실행 권한 확인 및 부여
check_script_permissions() {
    local script=$1
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo "$script에 실행 권한 부여 중..."
            chmod +x "$script" || error_exit "$script에 실행 권한을 부여할 수 없습니다."
        fi
    else
        error_exit "$script 파일이 존재하지 않습니다."
    fi
}

# 스크립트 실행
run_script() {
    local script=$1
    local description=$2
        
    echo "[$description] 스크립트 실행 중..."
        
    check_script_permissions "$script"
    
    # 스크립트 실행
    ./"$script" || error_exit "$script 실행에 실패했습니다."
    
        echo "[$description] 스크립트 실행 완료"
        echo ""
}

# 메인 실행 흐름
echo "노드딸깍이(Nodeddkkee) 설치 스크립트를 시작합니다..."

# 각 스크립트 순서대로 실행
run_script "0_check.sh" "시스템 확인 및 준비"
run_script "1_node.sh" "Bitcoin Core 설치"
run_script "2_fulcrum.sh" "Fulcrum 설치"
run_script "3_tor.sh" "Tor 설정"

echo "모든 설치 스크립트가 성공적으로 완료되었습니다!"
echo "노드딸깍이(Nodeddkkee) 설치가 완료되었습니다."

