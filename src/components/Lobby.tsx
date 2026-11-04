import { useState, type ReactNode } from 'react'
import { Loader2, Swords } from 'lucide-react'
import { useAccount } from 'wagmi'
import { chessAbi } from '@/lib/chessAbi'
import { CHAIN_ID, CHESS_ADDRESS, STATUS, fmtUsdc, isZero, mySide, same } from '@/lib/chess'
import { useGames, useOwed, useUsdcBalance } from '@/hooks/useChessData'
import { useTx } from '@/hooks/useTx'
import { CreateSheet } from '@/components/CreateSheet'
import { GameRow } from '@/components/GameRow'
import { TxButton } from '@/components/ui'

export function Lobby({ onOpen }: { onOpen: (id: bigint) => void }) {
  const { address } = useAccount()
  const { games, isLoading, isError } = useGames()
  const { balance } = useUsdcBalance(address)
  const owed = useOwed(address)
  const tx = useTx()
  const [creating, setCreating] = useState(false)

  const inPlay = (g: (typeof games)[number]) => g.status === STATUS.Open || g.status === STATUS.Active
  const mine = games.filter((g) => inPlay(g) && mySide(g, address) !== null)
  const challenges = games.filter(
    (g) => g.status === STATUS.Open && mySide(g, address) === null && (isZero(g.invited) || same(g.invited, address)),
  )
  const rest = games.filter((g) => !mine.includes(g) && !challenges.includes(g)).slice(0, 8)

  const withdraw = () =>
    tx.send('Withdrawing', () =>
      tx.writeContractAsync({ address: CHESS_ADDRESS, abi: chessAbi, functionName: 'withdrawOwed', chainId: CHAIN_ID }),
    )

  return (
    <div className="mx-auto max-w-xl space-y-4">
      <section className="glass-card overflow-hidden rounded-3xl">
        <div className="spectral h-1" />
        <div className="p-6">
          <div className="mb-4 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
            <Swords className="size-4" aria-hidden /> Arc Testnet
          </div>
          <h1 className="display text-balance text-4xl font-bold leading-[1.05]">Chess, settled in USDC.</h1>
          <p className="mt-3 max-w-[48ch] text-pretty text-sm text-[var(--muted)]">
            Stake USDC, play a friend or a stranger, and winner takes the pot. Every move is validated by the contract, so nobody can cheat or walk away with the money.
          </p>
          <div className="mt-5 flex items-end justify-between gap-4">
            <div>
              <div className="text-xs font-semibold text-[var(--muted)]">Your balance</div>
              <div className="flex items-baseline gap-1">
                <span className="display text-3xl font-bold tabular-nums">{address ? (balance === undefined ? '…' : fmtUsdc(balance)) : '–'}</span>
                <span className="text-sm font-medium text-[var(--subtle)]">USDC</span>
              </div>
            </div>
            <div className="w-44">
              <TxButton label="New game" onClick={() => setCreating(true)} />
            </div>
          </div>
        </div>
      </section>

      {owed > 0n && (
        <section className="glass-card flex items-center justify-between gap-3 rounded-3xl p-4">
          <div>
            <div className="text-sm font-semibold">{fmtUsdc(owed)} USDC waiting</div>
            <div className="text-xs text-[var(--muted)]">A payout could not be sent automatically. Withdraw it here.</div>
          </div>
          <div className="w-32">
            <TxButton label="Withdraw" step={tx.step} onClick={() => void withdraw()} />
          </div>
        </section>
      )}

      {isLoading && (
        <div className="flex items-center justify-center gap-2 py-10 text-sm text-[var(--muted)]">
          <Loader2 className="size-4 animate-spin" /> Loading games…
        </div>
      )}
      {isError && <p className="py-6 text-center text-sm text-[var(--danger)]">Could not load games. Retrying…</p>}

      {!isLoading && !isError && games.length === 0 && (
        <p className="glass-inner rounded-2xl p-6 text-center text-sm text-[var(--muted)]">No games yet. Start the first one.</p>
      )}

      <Section title="Your games" items={mine} me={address} onOpen={onOpen} />
      <Section title="Open challenges" items={challenges} me={address} onOpen={onOpen} />
      <Section title="Recent games" items={rest} me={address} onOpen={onOpen} />

      <CreateSheet
        open={creating}
        onClose={() => setCreating(false)}
        onCreated={(id) => {
          setCreating(false)
          onOpen(id)
        }}
      />
    </div>
  )
}

function Section({ title, items, me, onOpen }: { title: string; items: Parameters<typeof GameRow>[0]['game'][]; me?: string; onOpen: (id: bigint) => void }): ReactNode {
  if (items.length === 0) return null
  return (
    <section>
      <h2 className="mb-2 px-1 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">{title}</h2>
      <div className="space-y-2">
        {items.map((g) => (
          <GameRow key={g.id.toString()} game={g} me={me} onOpen={onOpen} />
        ))}
      </div>
    </section>
  )
}
