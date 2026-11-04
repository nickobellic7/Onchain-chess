import { ChevronRight } from 'lucide-react'
import { STATUS, creatorOf, endText, fmtClock, fmtUsdc, isZero, mySide, shortAddr, type GameData } from '@/lib/chess'
import { Badge } from '@/components/ui'

export function GameRow({ game, me, onOpen }: { game: GameData; me?: string; onOpen: (id: bigint) => void }) {
  const side = mySide(game, me)
  const myTurn = game.status === STATUS.Active && side !== null && game.whiteToMove === (side === 'white')
  const opponent = side === 'white' ? game.black : side === 'black' ? game.white : creatorOf(game)

  let badge = <Badge>Finished</Badge>
  if (game.status === STATUS.Open) badge = <Badge tone="success">Open</Badge>
  else if (game.status === STATUS.Active) badge = myTurn ? <Badge tone="accent">Your turn</Badge> : <Badge tone="success">Live</Badge>
  else if (game.status === STATUS.Cancelled) badge = <Badge>Cancelled</Badge>

  const subtitle =
    game.status === STATUS.Finished || game.status === STATUS.Cancelled
      ? endText(game, me).title
      : `${isZero(opponent) ? 'Open seat' : `vs ${shortAddr(opponent)}`} · ${fmtClock(game.moveTimeout)} per move`

  return (
    <button
      type="button"
      onClick={() => onOpen(game.id)}
      className="glass-inner flex min-h-16 w-full items-center gap-3 rounded-2xl px-4 py-3 text-left transition-colors hover:bg-white/80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
    >
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold tabular-nums">#{game.id.toString()}</span>
          {badge}
        </div>
        <div className="mt-0.5 truncate text-xs text-[var(--muted)]">{subtitle}</div>
      </div>
      <div className="text-right">
        <div className="display text-lg font-bold tabular-nums">{game.wager === 0n ? 'Free' : fmtUsdc(game.wager)}</div>
        {game.wager !== 0n && <div className="text-[10px] font-medium uppercase tracking-[0.08em] text-[var(--subtle)]">USDC each</div>}
      </div>
      <ChevronRight className="size-4 shrink-0 text-[var(--subtle)]" aria-hidden />
    </button>
  )
}
