import { useCallback, useEffect, useState } from 'react'
import { CHESS_ADDRESS } from '@/lib/chess'
import { Header } from '@/components/Header'
import { Lobby } from '@/components/Lobby'
import { GameView } from '@/components/GameView'

function readGameParam(): bigint | null {
  const raw = new URLSearchParams(window.location.search).get('game')
  return raw && /^\d{1,18}$/.test(raw) ? BigInt(raw) : null
}

export default function App() {
  const [gameId, setGameId] = useState<bigint | null>(readGameParam)

  useEffect(() => {
    const onPop = () => setGameId(readGameParam())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])

  const open = useCallback((id: bigint | null) => {
    window.history.pushState(null, '', id === null ? '/' : `/?game=${id.toString()}`)
    setGameId(id)
  }, [])

  return (
    <div className="relative min-h-dvh overflow-hidden">
      <div className="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden>
        <div style={{ position: 'absolute', top: '8%', left: '5%', width: 280, height: 280, borderRadius: '50%', background: 'radial-gradient(circle, rgba(133,177,237,0.22) 0%, transparent 70%)', filter: 'blur(60px)' }} />
        <div style={{ position: 'absolute', bottom: '8%', right: '8%', width: 260, height: 260, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,205,131,0.2) 0%, transparent 70%)', filter: 'blur(58px)' }} />
      </div>
      <div className="relative z-10 mx-auto max-w-5xl px-4 pb-24 pt-6">
        <Header onHome={() => open(null)} />
        {!CHESS_ADDRESS ? (
          <p className="glass-card mx-auto max-w-md rounded-3xl p-6 text-center text-sm text-[var(--muted)]">
            The chess contract address is not configured. Set VITE_CHESS_ADDRESS in .env and restart the dev server.
          </p>
        ) : gameId === null ? (
          <Lobby onOpen={open} />
        ) : (
          <GameView key={gameId.toString()} id={gameId} onBack={() => open(null)} />
        )}
      </div>
    </div>
  )
}
