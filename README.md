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

### 설치 방법

1. 리눅스가 설치되어 있는 기기에 접속할 별도 컴퓨터를 사용하거나, 리눅스 설치되어 있는 기기에 키보드 연결합니다.

- 리눅스 기기에 별도로 연결하려면 ssh 방식으로 접속해야 합니다.
- 윈도우 기준으로 터미널을 찾아 실행합니다.
- 깜빡이는 커서에 ssh 연결 명령어를 입력해야 합니다.
- 아이디가 mybtc이고 접속 주소가 192.168.1.3 이라고 가정하면, 아래와 같은 명령어를 입력합니다.
- 패스워드 입력하라고 나오면 설정된 패스워드를 오타없이 입력합니다.

```bash
ssh mybtc@192.168.1.3
```

2. 리눅스에 ssh로 접속했다면 이제 아래 스크립트를 복사한 후에 터미널 창에 붙여 넣고 엔터를 칩니다.

- 모든 파일은 한꺼번에 다운로드 받을 수 있는 명령어입니다. 
- 동작 절차는 모두 쉘스크립트로 작성되어 있으므로 별도의 설치 프로그램 없이 바로 실행할 수 있습니다.

```bash
wget https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/auto.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/0_check.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/1_node.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/2_electrs.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/3_tor.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/del.sh \
     https://raw.githubusercontent.com/my3rdstory/fullnodeddkkee/main/nodeddkkee_env.sh 
```

3. 다운로드 후 아래 명령어로 실행합니다. 

- 실행 중에 계속 진행을 위해 물어보는 경우가 있습니다. 대부분 Y, y, yes 등을 입력하면 계속 진행할 수 있습니다.
- 따로 악성 프로그램을 설치하지 않으니 그냥 설치해도 됩니다. 소스를 열어 봐도 별거 없을거에요.

```bash
sudo bash auto.sh
```

4. 설치는 4단계로 이루어져 있습니다.

- 가장 먼저 설치 환경을 체크합니다.
- 비트코인 코어 노드를 설치합니다.
- 일렉트럼 서버를 설치합니다.
- 토르를 설치하고, 토르 접속 정보를 파일로 생성합니다.

## 기능
- Bitcoin Core v28.1 자동 설치 및 설정
- 토르 네트워크 통합으로 익명성 보장
- RPC 인터페이스 자동 구성
- 시스템 서비스로 자동 실행 설정
- 타임체인 데이터 검증 및 저장
- 토르 히든 서비스를 통한 원격 접속 지원
- 토르 정보 자동으로 저장

## 사용 방법
1. 설치가 완료된 후 다음 명령어로 비트코인 노드 상태를 확인할 수 있습니다.

- 윈도우 터미널 화면 분할 기능을 이용해서 2개 이상의 현황을 살펴볼 수도 있습니다.
- 윈도우 파워쉘 기준으로 alt+shift+d 단축키 누르면 창을 2개로 분리할 수 있습니다.
- 각 창에 하나는 코어 블록 다운로드 확인 명령어를, 다른 창에는 풀크럼 로그 실시간 확인 명령어를 입력하면 2개의 설치 및 동기화 현황을 실시간으로 지켜볼 수 있습니다.

```bash
# 타임체인 정보 확인
bitcoin-cli getblockchaininfo

# 코어 피어 연결 정보 확인
bitcoin-cli getpeerinfo

# 코어 블록 다운로드 로그 확인
tail -f ~/.bitcoin/debug.log

# 일렉트럼 최근 5분 로그 확인
sudo journalctl -u electrs.service --since="-5 minutes"

# 토르 정보 확인
nano tor_info.json

# 코어 인바운드/아웃바운드 현황 확인
bitcoin-cli getpeerinfo | jq '{inbound:map(select(.inbound==true)) | length, outbound:map(select(.inbound==false)) | length}'

# 노드의 기기 현황 확인 - glances 사용
glances

# 노드의 기기 현황 확인 - htop 사용
htop

```
2. del.sh 실행하면 동기화한 타임체인 전체와 일렉트럼 데이터베이스 등 재설치 필요 없는 것들은 삭제합니다.
3. 실행 중 멈췄다면 auto.sh를 다시 실행해 보세요.
4. 그래도 안된다면 에러 메시지 보면서 스스로 대응하셔야 합니다.
5. 상세한 내용은 맨 아래 스페셜땡쓰 링크에서 확인하세요.

## 토르 네트워크 연결
스크립트는 토르 네트워크를 통한 익명 연결을 자동으로 설정합니다:
- 아웃바운드 연결: 일반 인터넷 사용
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