import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

interface NodeInfo {
  blockchainInfo: any;
  networkInfo: any;
  mempoolInfo: any;
  walletInfo: any;
  miningInfo: any;
}

function App() {
  const [nodeInfo, setNodeInfo] = useState<NodeInfo | null>(null)
  const [error, setError] = useState<string>('')

  useEffect(() => {
    const fetchNodeInfo = async () => {
      try {
        const methods = [
          { method: 'getblockchaininfo', setter: 'blockchainInfo' },
          { method: 'getnetworkinfo', setter: 'networkInfo' },
          { method: 'getmempoolinfo', setter: 'mempoolInfo' },
          { method: 'getwalletinfo', setter: 'walletInfo' },
          { method: 'getmininginfo', setter: 'miningInfo' }
        ]

        const results = await Promise.all(
          methods.map(({ method }) =>
            axios.post('/api', {
              jsonrpc: '1.0',
              id: 'curltest',
              method,
              params: []
            }, {
              headers: {
                'Content-Type': 'application/json',
              },
              auth: {
                username: 'mybtc',
                password: 'bitcoin'
              }
            }).catch(() => null)
          )
        )

        const info: any = {}
        results.forEach((response, index) => {
          if (response && response.data) {
            info[methods[index].setter] = response.data.result
          }
        })

        setNodeInfo(info)
      } catch (err) {
        console.error('Error:', err)
        setError('비트코인 RPC 연결 실패')
      }
    }

    fetchNodeInfo()
    const interval = setInterval(fetchNodeInfo, 10000) // 10초마다 갱신
    return () => clearInterval(interval)
  }, [])

  if (error) return <div>에러: {error}</div>
  if (!nodeInfo) return <div>로딩중...</div>

  const { blockchainInfo, networkInfo, mempoolInfo, walletInfo, miningInfo } = nodeInfo

  return (
    <div className="container">
      <h1>비트코인 노드 정보</h1>
      
      <div className="info-section">
        <h2>🔗 블록체인 정보</h2>
        <div className="info-box">
          <p>체인: {blockchainInfo?.chain}</p>
          <p>블록 수: {blockchainInfo?.blocks.toLocaleString()}</p>
          <p>헤더 수: {blockchainInfo?.headers.toLocaleString()}</p>
          <p>검증 진행률: {(blockchainInfo?.verificationprogress * 100).toFixed(2)}%</p>
          <p>최고 난이도: {blockchainInfo?.difficulty.toLocaleString()}</p>
          <p>체인 사이즈: {(blockchainInfo?.size_on_disk / 1024 / 1024 / 1024).toFixed(2)} GB</p>
        </div>
      </div>

      <div className="info-section">
        <h2>🌐 네트워크 정보</h2>
        <div className="info-box">
          <p>버전: {networkInfo?.version}</p>
          <p>서브버전: {networkInfo?.subversion}</p>
          <p>연결된 노드 수: {networkInfo?.connections}</p>
          <p>릴레이 수수료: {networkInfo?.relayfee} BTC</p>
          <p>네트워크: {networkInfo?.networkactive ? '활성' : '비활성'}</p>
        </div>
      </div>

      <div className="info-section">
        <h2>💭 메모리풀 정보</h2>
        <div className="info-box">
          <p>트랜잭션 수: {mempoolInfo?.size.toLocaleString()}</p>
          <p>메모리 사용량: {(mempoolInfo?.usage / 1024 / 1024).toFixed(2)} MB</p>
          <p>총 수수료: {mempoolInfo?.total_fee} BTC</p>
        </div>
      </div>

      {walletInfo && (
        <div className="info-section">
          <h2>💰 지갑 정보</h2>
          <div className="info-box">
            <p>잔액: {walletInfo?.balance} BTC</p>
            <p>미확인 잔액: {walletInfo?.unconfirmed_balance} BTC</p>
            <p>트랜잭션 수: {walletInfo?.txcount}</p>
          </div>
        </div>
      )}

      {miningInfo && (
        <div className="info-section">
          <h2>⛏️ 마이닝 정보</h2>
          <div className="info-box">
            <p>현재 해시레이트: {(miningInfo?.networkhashps / 1e18).toFixed(2)} EH/s</p>
            <p>현재 블록 난이도: {miningInfo?.difficulty.toLocaleString()}</p>
            <p>채굴 중: {miningInfo?.generate ? '예' : '아니오'}</p>
          </div>
        </div>
      )}
    </div>
  )
}

export default App
