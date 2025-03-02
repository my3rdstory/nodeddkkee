# 노드딸깍이(Nodeddkkee)

## 소개
![노드딸깍이](nodeddkkee.jpg)

이 프로젝트는 비트코인 코어 노드를 쉽게 설치하고 설정할 수 있는 자동화 스크립트입니다. 토르 네트워크를 통한 익명성을 제공하며, 비트코인 타임체인을 완전히 검증하고 저장할 수 있습니다. 풀크럼을 통해 와치온리 지갑을 내 노드와 연동할 수 있는 토르 주소를 제공합니다.

## 시작하기

### 필수 조건
- 리눅스 운영체제 (Ubuntu/Debian 계열 권장)
- 최소 1TB 이상의 저장 공간
- 최소 8GB RAM
- 안정적인 인터넷 연결
- sudo 권한이 있는 사용자 계정

### 설치
```bash
# 스크립트 다운로드
wget https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/auto.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/0_check.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/1_node.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/2_fulcrum.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/3_tor.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/del.sh https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/nodeddkkee_env.sh 

# 스크립트 실행
sudo bash auto.sh
```

## 기능
- Bitcoin Core v28.1 자동 설치 및 설정
- 토르 네트워크 통합으로 익명성 보장
- RPC 인터페이스 자동 구성
- 시스템 서비스로 자동 실행 설정
- 타임체인 데이터 검증 및 저장
- 토르 히든 서비스를 통한 원격 접속 지원
- 토르 정보 자동으로 저장

## 사용 방법
1. 설치가 완료된 후 다음 명령어로 비트코인 노드 상태를 확인할 수 있습니다:
```bash
# 타임체인 정보 확인
bitcoin-cli getblockchaininfo

# 코어 피어 연결 정보 확인
bitcoin-cli getpeerinfo

# 코어 블록 다운로드 로그 확인
tail -f ~/.bitcoin/debug.log

# 풀크럼 로그 실시간 확인
sudo journalctl -fu fulcrum.service

# 토르 정보 확인
nano tor_info.json
```
2. del.sh 실행하면 설치한 모든 소프트웨어와 등록했던 설정이 지워집니다. 단, .bitcoin과 fulcrum_db 디렉토리는 남겨둡니다.
3. 실행 중 멈췄다면 auto.sh를 다시 실행해 보세요.
4. 그래도 안된다면 에러 메시지 보면서 스스로 대응하세요.
5. 상세한 내용은 맨 아래 스페셜땡쓰 링크에서 확인하세요.

## 토르 네트워크 연결
스크립트는 토르 네트워크를 통한 익명 연결을 자동으로 설정합니다:
- 아웃바운드 연결: 일반 인터넷 사용 (직접 연결)
- 인바운드 연결: 토르 네트워크를 통해서만 허용
- 토르 히든 서비스 주소를 통해 원격에서 노드에 접속 가능

## 주의
저는 코딩 못합니다. 커서 조져서 대충 만든거에요. 제 오드로이드 H4 기기에서만 테스트했습니다. 다른 기기에서 동작을 보장하지 않습니다. 수정 요청하지 마시고 포크해서 마음껏 사용하세요.

## 라이센스
이 프로젝트는 오픈소스로 제공됩니다. 자유롭게 포크하여 사용하세요.

## 연락처
- 작성자: DedSec
- 엑스: https://x.com/_orangepillkr
- 유튜브: https://www.youtube.com/@orangepillkr/
- 스페셜땡쓰: 셀프카스타드님 https://florentine-porkpie-563.notion.site/2e905cab90ae4a979711ec40bbb85d64?v=7c329be91bd44a03928fcfa3ed4c3fe4 