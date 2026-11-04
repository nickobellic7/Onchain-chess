import { useEffect, useState } from 'react'
import { Copy, Handshake, Flag, Timer } from 'lucide-react'
import { toast } from 'sonner'
import { chessAbi } from '@/lib/chessAbi'
import { buildShareLink } from '@/lib/share'
import { CHAIN_ID, CHESS_ADDRESS, STATUS, creatorOf, fmtUsdc, isZero, mySide, same, shortAddr, type GameData } from '@/lib/chess'
import { useUsdcBalance } from '@/hooks/useChessData'
import { useTx } from '@/hooks/useTx'
import { TxButton } from '@/components/ui'

type SimpleCall = 'resign' | 'offerDraw' | 'acceptDraw' | 'claimTimeout' | 'cancelGame'

export function GameActions({ game, remaining }: { game: GameData; remaining: number }) {
  const tx = useTx()
  const { balance } = useUsdcBalance(tx.address)
  const side = mySide(game, tx.address)
  const [confirmResign, setConfirmResign] = useState(false)
  const [link, setLink] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    void buildShareLink(`/?game=${game.id}`).then((url) => live && setLink(url))
    return () => {
      live = false
    }
  }, [game.id])

  const call = (label: string, functionName: SimpleCall) =>
    tx.send(label, () => tx.writeContractAsync({ address: CHESS_ADDRESS, abi: chessAbi, functionName, args: [game.id], chainId: CHAIN_ID }))

  const join = async () => {
    if (!(await tx.ensureAllowance(game.wager))) return
    await tx.send('Joining', () =>
      tx.writeContractAsync({ address: CHESS_ADDRESS, abi: chessAbi, functionName: 'joinGame', args: [game.id], chainId: CHAIN_ID }),
    )
  }

  const copyLink = async () => {
    if (!link) return
    try {
      await navigator.clipboard.writeText(link)
      toast.success('Invite link copied')
    } catch {
      toast.error('Could not copy. Select the link and copy it manually.')
    }
  }

  // ---- Open game --------------------------------------------------------
  if (game.status === STATUS.Open) {
    const isCreator = same(creatorOf(game), tx.address)
    if (isCreator) {
      return (
        <div className="space-y-3">
          <p className="text-sm text-[var(--muted)]">
            {isZero(game.invited) ? 'Waiting for an opponent to match your stake.' : `Reserved for ${shortAddr(game.invited)}.`} Your {fmtUsdc(game.wager)} USDC is held by the contract until someone joins.
          </p>
          <div className="glass-inner flex items-center gap-2 rounded-2xl p-2 pl-3">
            <span className="mono min-w-0 flex-1 truncate text-xs text-[var(--ink-2)]">{link ?? 'Preparing link…'}</span>
            <button
              type="button"
              onClick={() => void copyLink()}
              disabled={!link}
              className="flex min-h-10 items-center gap-1.5 rounded-xl bg-[var(--accent)] px-3 text-xs font-semibold text-white disabled:opacity-40"
            >
              <Copy className="size-3.5" /> Copy
            </button>
          </div>
          <TxButton variant="secondary" label="Cancel and refund" step={tx.step} onClick={() => void call('Cancelling', 'cancelGame')} />
        </div>
      )
    }
    const reserved = !isZero(game.invited) && !same(game.invited, tx.address)
    const poor = balance !== undefined && balance < game.wager
    return (
      <div className="space-y-3">
        {reserved ? (
          <p className="text-sm text-[var(--muted)]">This game is reserved for {shortAddr(game.invited)}.</p>
        ) : (
          <TxButton
            label={poor ? 'Not enough USDC' : game.wager === 0n ? 'Join free game' : `Join for ${fmtUsdc(game.wager)} USDC`}
            step={tx.step}
            disabled={poor}
            onClick={() => void join()}
          />
        )}
        {poor && <p className="text-xs text-[var(--muted)]">Use Get test USDC in the Arc Studio sidebar to top up.</p>}
      </div>
    )
  }

  // ---- Active game (players only) --------------------------------------
  if (game.status !== STATUS.Active || !side) return null

  const meNum = side === 'white' ? 1 : 2
  const myTurn = game.whiteToMove === (side === 'white')
  const expired = remaining <= 0
  const canClaim = expired && !myTurn
  const incoming = game.drawOfferedBy !== 0 && game.drawOfferedBy !== meNum
  const sent = game.drawOfferedBy === meNum

  return (
    <div className="space-y-2.5">
      {canClaim && (
        <TxButton label="Claim win on time" step={tx.step} onClick={() => void call('Claiming', 'claimTimeout')} />
      )}
      {expired && myTurn && (
        <p className="flex items-center gap-2 rounded-2xl bg-[rgba(186,43,76,0.1)] p-3 text-sm text-[var(--danger)]">
          <Timer className="size-4 shrink-0" /> Your clock ran out. Your opponent can claim the win.
        </p>
      )}
      {incoming && (
        <div className="glass-inner rounded-2xl p-3">
          <p className="mb-2 text-sm font-medium">Your opponent offers a draw. Both stakes are returned.</p>
          <TxButton label="Accept draw" step={tx.step} onClick={() => void call('Accepting', 'acceptDraw')} />
        </div>
      )}
      <div className="grid grid-cols-2 gap-2">
        <TxButton
          variant="secondary"
          label={sent ? 'Draw offered' : 'Offer draw'}
          step={tx.step}
          disabled={sent}
          onClick={() => void call('Offering', 'offerDraw')}
        />
        {confirmResign ? (
          <TxButton variant="danger" label="Confirm resign" step={tx.step} onClick={() => void call('Resigning', 'resign').then(() => setConfirmResign(false))} />
        ) : (
          <button
            type="button"
            onClick={() => setConfirmResign(true)}
            className="glass-pill flex min-h-11 items-center justify-center gap-2 rounded-2xl px-4 py-3 text-sm font-semibold text-[var(--danger)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
          >
            <Flag className="size-4" /> Resign
          </button>
        )}
      </div>
      {sent && (
        <p className="flex items-center gap-2 text-xs text-[var(--muted)]">
          <Handshake className="size-3.5" /> Waiting for your opponent. Any move cancels the offer.
        </p>
      )}
    </div>
  )
}
