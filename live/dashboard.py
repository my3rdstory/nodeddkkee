import streamlit as st
import requests
import time
from datetime import datetime
from dotenv import load_dotenv
import os
from pathlib import Path

# 환경 변수 로드
env_path = Path('.env')
load_dotenv(dotenv_path=env_path)

# 페이지 설정
st.set_page_config(
    page_title="비트코인 노드 정보",
    layout="wide"
)

# CSS 스타일 추가
st.markdown("""
<style>
    /* 전체 배경색 설정 */
    .stApp {
        background-color: #f5f7fa;
    }
    
    /* 메인 컨테이너 너비 제한 */
    .main .block-container {
        max-width: 70%;
        padding-left: 5%;
        padding-right: 5%;
        padding-top: 3rem;
        margin: 0 auto;
    }
    
    /* 정보 영역 카드 스타일 */
    div[data-testid="stVerticalBlock"] > div > div[data-testid="stVerticalBlock"] {
        background-color: white;
        border-radius: 15px;
        padding: 1.5rem;
        margin: 0.5rem 0;
        box-shadow: 0 2px 12px rgba(0,0,0,0.04);
        border: 1px solid #eef1f5;
        max-width: 100%;
    }
    
    /* 데이터 항목 카드 스타일 */
    .element-container p {
        background-color: white;
        border-radius: 8px;
        padding: 0.8rem 1rem;
        margin: 0rem 0 2rem 0;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        border: 1px solid #eef1f5;
        max-width: 100%;        
    }
    
    /* 제목 스타일 */
    h1 {
        font-size: 1.5rem !important;
        font-weight: 600 !important;
        margin-bottom: 0.5rem !important;
        color: #1a1f36 !important;
    }
    
    /* 서브타이틀 스타일 */
    h3 {
        font-size: 1.3rem !important;
        font-weight: 500 !important;
        color: #1a1f36 !important;
        margin-top: 0 !important;
        margin-bottom: 0.5rem !important;
    }
    
    /* 텍스트 스타일 */
    .element-container p {
        color: #4f566b;
        font-size: 1rem;
    }
    
    /* 값 강조 스타일 */
    .element-container p strong {
        color: #1a1f36;
        font-weight: 500;
    }
    
    /* 레이아웃 정렬 */
    div.row-widget.stHorizontal {
        gap: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# RPC 설정
RPC_URL = "http://localhost:8332"
RPC_USER = os.getenv("RPC_USER")
RPC_PASS = os.getenv("RPC_PASS")

if not RPC_USER or not RPC_PASS:
    st.error("환경 변수가 설정되지 않았습니다. .env 파일을 확인해주세요.")
    st.stop()

RPC_AUTH = (RPC_USER, RPC_PASS)

def make_rpc_request(method, params=[]):
    try:
        response = requests.post(
            RPC_URL,
            json={
                "jsonrpc": "1.0",
                "id": "curltest",
                "method": method,
                "params": params
            },
            auth=RPC_AUTH,
            timeout=5
        )
        if response.status_code == 401:
            st.error("RPC 인증 실패: 사용자 이름과 비밀번호를 확인해주세요.")
            return None
        return response.json()["result"]
    except requests.exceptions.ConnectionError:
        st.error("RPC 연결 실패: 비트코인 노드가 실행 중인지 확인해주세요.")
        return None
    except requests.exceptions.Timeout:
        st.error("RPC 요청 시간 초과")
        return None
    except Exception as e:
        st.error(f"RPC 요청 실패: {str(e)}")
        return None

# 타이틀
st.title("비트코인 노드 정보")

# 자동 새로고침
if "refresh_counter" not in st.session_state:
    st.session_state.refresh_counter = 0
    st.session_state.last_refresh = time.time()

current_time = time.time()
if current_time - st.session_state.last_refresh >= 10:
    st.session_state.refresh_counter += 1
    st.session_state.last_refresh = current_time

# 데이터 가져오기
col1, col2 = st.columns(2)

with col1:
    # 타임체인 정보
    with st.container():
        st.subheader("🔗 타임체인 정보")
        blockchain_info = make_rpc_request("getblockchaininfo")
        if blockchain_info:            
            st.markdown(f"""
                **체인**: {blockchain_info.get('chain')}<br>
                **블록 수**: {blockchain_info.get('blocks'):,}<br>
                **검증 진행률**: {blockchain_info.get('verificationprogress', 0) * 100:.2f}%<br>
                **최고 난이도**: {blockchain_info.get('difficulty', 0):,}<br>
                **체인 사이즈**: {blockchain_info.get('size_on_disk', 0) / 1024 / 1024 / 1024:.2f} GB
            """, unsafe_allow_html=True)

    # 메모리풀 정보
    with st.container():
        st.subheader("💭 메모리풀 정보")
        mempool_info = make_rpc_request("getmempoolinfo")
        if mempool_info:
            st.markdown(f"""
                **트랜잭션 수**: {mempool_info.get('size', 0):,}<br>
                **메모리 사용량**: {mempool_info.get('usage', 0) / 1024 / 1024:.2f} MB<br>
                **총 수수료**: {mempool_info.get('total_fee', 0)} BTC
            """, unsafe_allow_html=True)

with col2:
    # 네트워크 정보
    with st.container():
        st.subheader("🌐 네트워크 정보")
        network_info = make_rpc_request("getnetworkinfo")
        if network_info:
            version = str(network_info.get('version', 0)).zfill(6)
            formatted_version = f"{version[:2]}.{version[2:4]}.{version[4:]}"
            relayfee = network_info.get('relayfee', 0)
            relayfee_sats = int(relayfee * 100_000_000)  # BTC to satoshi
            st.markdown(f"""
                **버전**: {formatted_version}<br>
                **서브버전**: {network_info.get('subversion')}<br>
                **연결된 노드 수**: {network_info.get('connections')}<br>
                **릴레이 수수료**: {relayfee:.8f} BTC ({relayfee_sats:,} satoshi)<br>
                **네트워크**: {'활성' if network_info.get('networkactive') else '비활성'}
            """, unsafe_allow_html=True)

    # 마이닝 정보
    with st.container():
        st.subheader("⛏️ 마이닝 정보")
        mining_info = make_rpc_request("getmininginfo")
        if mining_info:
            st.markdown(f"""
                **현재 해시레이트**: {mining_info.get('networkhashps', 0) / 1e18:.2f} EH/s<br>
                **현재 블록 난이도**: {mining_info.get('difficulty', 0):,}<br>
                **채굴 중**: {'예' if mining_info.get('generate') else '아니오'}
            """, unsafe_allow_html=True)

# 시스템 정보
with st.container():
    st.subheader("💻 시스템 정보")
    system_info = make_rpc_request("getsysteminfo")
    if system_info:
        st.markdown(f"""
            **CPU 사용률**: {system_info.get('cpu_percent')}%<br>
            **메모리 사용률**: {system_info.get('memory_percent')}%<br>
            **디스크 사용률**: {system_info.get('disk_percent')}%<br>
            **프로세스 수**: {system_info.get('process_count')}<br>
            **가동 시간**: {system_info.get('uptime_hours', 0):.1f}시간
        """, unsafe_allow_html=True)

# 자동 새로고침을 위한 스크립트
st.markdown(
    f"""
    <script>
        setTimeout(function(){{
            window.location.reload();
        }}, 10000);
    </script>
    """,
    unsafe_allow_html=True
) 