import { useEffect, useMemo, useRef, useState } from 'react'
import { ArrowLeft, Crown, Eye, Loader2 } from 'lucide-react'
import { useAccount } from 'wagmi'
import { chessAbi } from '@/lib/chessAbi'
import {
  CHAIN_ID,
  CHESS_ADDRESS,
  STATUS,
  capturedPieces,
  decodeBoard,
  diffMove,
  endText,
  fmtClock,
  fmtUsdc,
  glyph,
  isWhitePiece,
  kindOf,
  mySide,
} from '@/lib/chess'
import { useChainNow, useGame, useTargets } from '@/hooks/useChessData'
import { useTx } from '@/hooks/useTx'
import { Badge, Sheet } from '@/components/ui'
import { Board } from '@/components/Board'
import { PlayerBar } from '@/components/PlayerBar'
import { GameActions } from '@/components/GameActions'

const PROMOTIONS = [
  { type: 5, label: 'Queen' },
  { type: 4, label: 'Rook' },
  { type: 3, label: 'Bishop' },
  { type: 2, label: 'Knight' },
]

export function GameView({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { game, isLoading, isError } = useGame(id)
  const { address } = useAccount()
  const tx = useTx()
  const now = useChainNow()

  const [selected, setSelected] = useState<number | null>(null)
  const [promo, setPromo] = useState<{ from: number; to: number } | null>(null)
  const [lastMove, setLastMove] = useState<{ from: number; to: number } | null>(null)
  const prevBoard = useRef<number[] | null>(null)

  const squares = useMemo(() => (game ? decodeBoard(game.board) : []), [game])
  const targets = useTargets(selected, game?.board ?? 0n, game?.whiteToMove ?? true)

  // Highlight the last move by comparing consecutive live boards.
  useEffect(() => {
    if (squares.length === 0) return
    if (prevBoard.current) {
      const moved = diffMove(prevBoard.current, squares)
      if (moved) setLastMove(moved)
    }
    prevBoard.current = squares
  }, [squares])

  if (isError) return <Message onBack={onBack} text="Could not load this game. It may not exist." />
  if (isLoading || !game) {
    return (
      <div className="flex items-center justify-center gap-2 py-24 text-[var(--muted)]">
        <Loader2 className="size-5 animate-spin" /> Loading game…
      </div>
    )
  }

  const side = mySide(game, address)
  const active = game.status === STATUS.Active
  const myTurn = active && side !== null && game.whiteToMove === (side === 'white')
  const interactive = myTurn && !tx.busy
  const deadline = game.lastMoveAt + game.moveTimeout
  const remaining = deadline - now
  const flipped = side === 'black'
  const { lostWhite, lostBlack } = capturedPieces(squares)
  const finished = game.status === STATUS.Finished || game.status === STATUS.Cancelled
  const result = finished ? endText(game, address) : null

  const submitMove = async (from: number, to: number, promotion: number) => {
    const receipt = await tx.send('Moving', () =>
      tx.writeContractAsync({ address: CHESS_ADDRESS, abi: chessAbi, functionName: 'makeMove', args: [game.id, from, to, promotion], chainId: CHAIN_ID }),
    )
    if (receipt) setSelected(null)
  }

  const onSquare = (i: number) => {
    if (!interactive) return
    const piece = squares[i]
    if (selected !== null && targets.has(i)) {
      const mover = squares[selected]
      const lastRank = game.whiteToMove ? 7 : 0
      if (kindOf(mover) === 1 && Math.floor(i / 8) === lastRank) setPromo({ from: selected, to: i })
      else void submitMove(selected, i, 0)
      return
    }
    const mine = piece !== 0 && isWhitePiece(piece) === (side === 'white')
    setSelected(mine && i !== selected ? i : null)
  }

  const clockFor = (color: 'white' | 'black') => {
    if (!active) return undefined
    const toMove = game.whiteToMove === (color === 'white')
    return toMove ? fmtClock(remaining) : fmtClock(game.moveTimeout)
  }

  const top = flipped ? 'white' : 'black'
  const bottom = flipped ? 'black' : 'white'
  const bar = (color: 'white' | 'black') => (
    <PlayerBar
      color={color}
      address={color === 'white' ? game.white : game.black}
      isMe={side === color}
      captured={color === 'white' ? lostBlack : lostWhite}
      active={active && game.whiteToMove === (color === 'white')}
      clock={clockFor(color)}
      clockDanger={active && game.whiteToMove === (color === 'white') && remaining <= 10}
    />
  )

  const pot = game.status === STATUS.Open ? game.wager : game.wager * 2n

  return (
    <div>
      <button
        type="button"
        onClick={onBack}
        className="mb-4 inline-flex min-h-10 items-center gap-1.5 rounded-full px-2 text-sm font-semibold text-[var(--ink-2)] hover:bg-black/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
      >
        <ArrowLeft className="size-4" /> Lobby
      </button>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,560px)_minmax(0,1fr)]">
        <div className="space-y-2.5">
          {bar(top)}
          <Board squares={squares} flipped={flipped} selected={selected} targets={targets} lastMove={lastMove} interactive={interactive} onSquare={onSquare} />
          {bar(bottom)}
        </div>

        <aside className="space-y-3">
          <section className="glass-card rounded-3xl p-5">
            <div className="mb-3 flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">Game #{game.id.toString()}</span>
              <StatusBadge status={game.status} myTurn={myTurn} />
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className="display text-5xl font-bold tabular-nums">{fmtUsdc(pot)}</span>
              <span className="text-lg font-medium text-[var(--subtle)]">USDC</span>
            </div>
            <p className="mt-1 text-xs text-[var(--muted)]">
              {game.wager === 0n ? 'Free game, nothing at stake.' : game.status === STATUS.Open ? 'Stake waiting for a challenger. Winner takes the pot.' : 'Held by the contract. Winner takes the pot.'}
            </p>
          </section>

          {result && <ResultCard result={result} />}

          {!finished && (
            <section className="glass-card rounded-3xl p-5">
              {active && side && (
                <p className="mb-3 text-sm font-medium">
                  {tx.step ? `${tx.step}…` : myTurn ? 'Your move. Tap a piece, then a highlighted square.' : "Waiting for your opponent's move."}
                </p>
              )}
              {active && !side && (
                <p className="mb-1 flex items-center gap-2 text-sm text-[var(--muted)]">
                  <Eye className="size-4" /> You are watching this game live.
                </p>
              )}
              <GameActions game={game} remaining={remaining} />
            </section>
          )}

          <section className="glass-inner rounded-2xl p-4 text-xs leading-relaxed text-[var(--muted)]">
            <div className="mb-1 font-semibold text-[var(--ink-2)]">Rules on this table</div>
            Every move is checked by the contract. Win by capturing the enemy king. Castling and en passant are not included, and moving into check is allowed. Each move has a {fmtClock(game.moveTimeout)} clock.
          </section>
        </aside>
      </div>

      <Sheet open={promo !== null} onClose={() => setPromo(null)} title="Promote pawn">
        <div className="grid grid-cols-4 gap-2">
          {PROMOTIONS.map((p) => (
            <button
              key={p.type}
              type="button"
              onClick={() => {
                if (!promo) return
                const { from, to } = promo
                setPromo(null)
                void submitMove(from, to, p.type)
              }}
              className="glass-inner flex min-h-20 flex-col items-center justify-center gap-1 rounded-2xl hover:bg-white/80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
            >
              <span className={`piece text-4xl ${side === 'white' ? 'piece-w' : 'piece-b'}`}>{glyph(p.type + (side === 'white' ? 0 : 8))}</span>
              <span className="text-xs font-semibold">{p.label}</span>
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  )
}

function StatusBadge({ status, myTurn }: { status: number; myTurn: boolean }) {
  if (status === STATUS.Open) return <Badge>Open</Badge>
  if (status === STATUS.Active) return myTurn ? <Badge tone="accent">Your turn</Badge> : <Badge tone="success">Live</Badge>
  if (status === STATUS.Cancelled) return <Badge>Cancelled</Badge>
  return <Badge>Finished</Badge>
}

function ResultCard({ result }: { result: ReturnType<typeof endText> }) {
  const color = result.tone === 'win' ? 'var(--success)' : result.tone === 'loss' ? 'var(--danger)' : 'var(--ink)'
  return (
    <section className="glass-card overflow-hidden rounded-3xl">
      {result.tone === 'win' && <div className="spectral h-1" />}
      <div className="flex items-start gap-3 p-5">
        <Crown className="mt-1 size-5 shrink-0" style={{ color }} />
        <div>
          <div className="display text-2xl font-bold" style={{ color }}>{result.title}</div>
          <p className="mt-1 text-sm text-[var(--muted)]">{result.detail}</p>
        </div>
      </div>
    </section>
  )
}

function Message({ text, onBack }: { text: string; onBack: () => void }) {
  return (
    <div className="glass-card mx-auto max-w-md rounded-3xl p-6 text-center">
      <p className="mb-4 text-sm text-[var(--muted)]">{text}</p>
      <button type="button" onClick={onBack} className="min-h-11 rounded-2xl bg-[var(--accent)] px-5 text-sm font-semibold text-white">
        Back to lobby
      </button>
    </div>
  )
}
