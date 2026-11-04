import { useState } from 'react'
import { isAddress, parseEventLogs } from 'viem'
import { chessAbi } from '@/lib/chessAbi'
import { CHAIN_ID, CHESS_ADDRESS, TIMEOUT_CHOICES, ZERO, fmtUsdc } from '@/lib/chess'
import { parseUsdc } from '@/onchain-money'
import { useUsdcBalance } from '@/hooks/useChessData'
import { useTx } from '@/hooks/useTx'
import { Chip, Sheet, TxButton } from '@/components/ui'

const QUICK = ['0', '1', '5', '10']
const MAX_WAGER = 1_000_000_000_000n // 1,000,000 USDC in raw units, a sanity cap for the form

export function CreateSheet({ open, onClose, onCreated }: { open: boolean; onClose: () => void; onCreated: (id: bigint) => void }) {
  const tx = useTx()
  const { balance } = useUsdcBalance(tx.address)
  const [amount, setAmount] = useState('1')
  const [timeout, setTimeoutSecs] = useState(300)
  const [white, setWhite] = useState(true)
  const [invite, setInvite] = useState('')

  let wager: bigint | null = null
  try {
    wager = amount === '' ? null : parseUsdc(amount)
  } catch {
    wager = null
  }
  const inviteOk = invite === '' || (isAddress(invite) && invite.toLowerCase() !== tx.address?.toLowerCase())
  const tooPoor = wager !== null && balance !== undefined && balance < wager
  const valid = wager !== null && wager <= MAX_WAGER && inviteOk
  const blocked = !valid || tooPoor

  const create = async () => {
    if (wager === null) return
    if (!(await tx.ensureAllowance(wager))) return
    const receipt = await tx.send('Creating game', () =>
      tx.writeContractAsync({
        address: CHESS_ADDRESS,
        abi: chessAbi,
        functionName: 'createGame',
        args: [wager, timeout, white, invite === '' ? ZERO : (invite as `0x${string}`)],
        chainId: CHAIN_ID,
      }),
    )
    if (!receipt) return
    const [created] = parseEventLogs({ abi: chessAbi, logs: receipt.logs, eventName: 'GameCreated' })
    if (created) onCreated(created.args.id)
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title="New game">
      <div className="space-y-5">
        <div>
          <label htmlFor="wager" className="mb-2 block text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
            Your stake
          </label>
          <div className="glass-inner rounded-2xl p-4">
            <div className="flex items-baseline gap-2">
              <input
                id="wager"
                inputMode="decimal"
                value={amount}
                placeholder="0.00"
                onChange={(e) => {
                  const v = e.target.value.replace(/[^0-9.]/g, '')
                  if (/^\d*\.?\d{0,6}$/.test(v)) setAmount(v)
                }}
                className="display w-full bg-transparent text-4xl font-bold tabular-nums outline-none placeholder:text-slate-300"
              />
              <span className="text-sm font-medium text-[var(--subtle)]">USDC</span>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              {QUICK.map((q) => (
                <Chip key={q} active={amount === q} onClick={() => setAmount(q)}>
                  {q === '0' ? 'Free' : q}
                </Chip>
              ))}
              <span className="ml-auto text-xs tabular-nums text-[var(--subtle)]">
                {balance === undefined ? 'Balance unavailable' : `Balance: ${fmtUsdc(balance)}`}
              </span>
            </div>
          </div>
        </div>

        <div>
          <div className="mb-2 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">Time per move</div>
          <div className="flex flex-wrap gap-2">
            {TIMEOUT_CHOICES.map((t) => (
              <Chip key={t.seconds} active={timeout === t.seconds} onClick={() => setTimeoutSecs(t.seconds)}>
                {t.label}
              </Chip>
            ))}
          </div>
        </div>

        <div>
          <div className="mb-2 text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">Play as</div>
          <div className="flex gap-2">
            <Chip active={white} onClick={() => setWhite(true)}>White</Chip>
            <Chip active={!white} onClick={() => setWhite(false)}>Black</Chip>
          </div>
        </div>

        <div>
          <label htmlFor="invite" className="mb-2 block text-xs font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
            Invite one player (optional)
          </label>
          <input
            id="invite"
            value={invite}
            onChange={(e) => setInvite(e.target.value.trim())}
            placeholder="0x… leave empty for an open game"
            spellCheck={false}
            className="mono glass-inner w-full rounded-2xl px-4 py-3 text-xs outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
          />
          {!inviteOk && <p className="mt-1.5 text-xs text-[var(--danger)]">Enter a valid address that is not your own.</p>}
        </div>

        <div className="glass-inner space-y-1.5 rounded-2xl p-4 text-sm">
          <Row label="You stake" value={wager === null ? '–' : `${fmtUsdc(wager)} USDC`} />
          <Row label="Winner takes" value={wager === null ? '–' : `${fmtUsdc(wager * 2n)} USDC`} strong />
        </div>

        <TxButton
          label={tooPoor ? 'Not enough USDC' : 'Create game'}
          step={tx.step}
          disabled={blocked}
          onClick={() => void create()}
        />
      </div>
    </Sheet>
  )
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-[var(--muted)]">{label}</span>
      <span className={`tabular-nums ${strong ? 'font-bold' : 'font-medium'}`}>{value}</span>
    </div>
  )
}
