import { Clock } from 'lucide-react'
import { glyph, isWhitePiece, isZero, shortAddr } from '@/lib/chess'

interface PlayerBarProps {
  color: 'white' | 'black'
  address: string
  isMe: boolean
  /** Opponent pieces this player has taken. */
  captured: number[]
  active: boolean
  clock?: string
  clockDanger?: boolean
}

export function PlayerBar({ color, address, isMe, captured, active, clock, clockDanger }: PlayerBarProps) {
  return (
    <div
      className={`glass-inner flex min-h-14 items-center justify-between gap-3 rounded-2xl px-3 py-2 transition-shadow ${
        active ? 'shadow-[0_0_0_2px_var(--focus)]' : ''
      }`}
    >
      <div className="flex min-w-0 items-center gap-3">
        <span
          className="size-8 shrink-0 rounded-full"
          style={{
            background: color === 'white' ? '#fff' : 'var(--ink)',
            boxShadow: '0 0 0 1.5px var(--ink), 0 2px 6px rgba(18,45,69,0.2)',
          }}
          aria-hidden
        />
        <div className="min-w-0">
          <div className="truncate text-sm font-semibold">
            {isMe ? 'You' : isZero(address) ? 'Waiting for opponent' : shortAddr(address)}
            <span className="ml-2 text-xs font-medium capitalize text-[var(--subtle)]">{color}</span>
          </div>
          <div className="flex h-5 items-center gap-0.5 overflow-hidden" aria-label="Captured pieces">
            {captured.map((p, i) => (
              <span key={i} className={`piece text-[15px] ${isWhitePiece(p) ? 'piece-w' : 'piece-b'}`} style={{ WebkitTextStrokeWidth: isWhitePiece(p) ? 1 : 0.4 }}>
                {glyph(p)}
              </span>
            ))}
          </div>
        </div>
      </div>
      {clock && (
        <span
          className={`flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-semibold tabular-nums ${
            clockDanger ? 'bg-[rgba(186,43,76,0.12)] text-[var(--danger)]' : active ? 'bg-[var(--accent)] text-white' : 'bg-black/5 text-[var(--ink-2)]'
          }`}
        >
          <Clock className="size-3.5" aria-hidden /> {clock}
        </span>
      )}
    </div>
  )
}
