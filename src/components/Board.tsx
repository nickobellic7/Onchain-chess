import { FILES, glyph, isWhitePiece, pieceName, squareName } from '@/lib/chess'

interface BoardProps {
  squares: number[]
  flipped: boolean
  selected: number | null
  targets: Set<number>
  lastMove: { from: number; to: number } | null
  interactive: boolean
  onSquare: (index: number) => void
}

export function Board({ squares, flipped, selected, targets, lastMove, interactive, onSquare }: BoardProps) {
  const ranks = flipped ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0]
  const files = flipped ? [7, 6, 5, 4, 3, 2, 1, 0] : [0, 1, 2, 3, 4, 5, 6, 7]

  return (
    <div
      className="mx-auto aspect-square w-full max-w-[560px] overflow-hidden rounded-2xl shadow-[0_12px_40px_rgba(18,45,69,0.16)] ring-1 ring-[var(--border)]"
      style={{ containerType: 'inline-size' }}
      role="grid"
      aria-label="Chess board"
    >
      <div className="grid h-full w-full grid-cols-8 grid-rows-8">
        {ranks.flatMap((rank) =>
          files.map((file) => {
            const i = rank * 8 + file
            const piece = squares[i] ?? 0
            const dark = (rank + file) % 2 === 0
            const isSelected = selected === i
            const isTarget = targets.has(i)
            const isLast = lastMove !== null && (lastMove.from === i || lastMove.to === i)
            const showRank = file === files[0]
            const showFile = rank === ranks[7]
            return (
              <button
                key={i}
                type="button"
                role="gridcell"
                disabled={!interactive}
                onClick={() => onSquare(i)}
                aria-label={`${squareName(i)}${piece ? ` ${pieceName(piece)}` : ' empty'}${isTarget ? ', legal move' : ''}`}
                className="relative flex items-center justify-center focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[var(--focus)] disabled:cursor-default"
                style={{ background: dark ? 'var(--sq-dark)' : 'var(--sq-light)' }}
              >
                {isLast && <span className="absolute inset-0" style={{ background: 'rgba(255,205,131,0.55)' }} />}
                {isSelected && <span className="absolute inset-0" style={{ background: 'rgba(95,190,255,0.55)' }} />}
                {showRank && (
                  <span className="absolute left-[4%] top-[3%] text-[clamp(8px,2.2cqw,12px)] font-semibold" style={{ color: dark ? 'var(--sq-light)' : 'var(--sq-dark)' }}>
                    {rank + 1}
                  </span>
                )}
                {showFile && (
                  <span className="absolute bottom-[3%] right-[5%] text-[clamp(8px,2.2cqw,12px)] font-semibold" style={{ color: dark ? 'var(--sq-light)' : 'var(--sq-dark)' }}>
                    {FILES[file]}
                  </span>
                )}
                {piece !== 0 && (
                  <span
                    className={`piece relative ${isWhitePiece(piece) ? 'piece-w' : 'piece-b'}`}
                    style={{ fontSize: '9.6cqw', transform: isSelected ? 'scale(1.08)' : undefined, transition: 'transform 120ms ease' }}
                  >
                    {glyph(piece)}
                  </span>
                )}
                {isTarget && piece === 0 && <span className="absolute size-[26%] rounded-full" style={{ background: 'rgba(18,45,69,0.35)' }} />}
                {isTarget && piece !== 0 && <span className="absolute inset-[6%] rounded-full" style={{ boxShadow: 'inset 0 0 0 4px rgba(186,43,76,0.7)' }} />}
              </button>
            )
          }),
        )}
      </div>
    </div>
  )
}
