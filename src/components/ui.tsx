import { useEffect, type ReactNode } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useModal } from 'connectkit'
import { useAccount, useSwitchChain } from 'wagmi'
import { Loader2, X } from 'lucide-react'
import { CHAIN_ID } from '@/lib/chess'

type Variant = 'primary' | 'secondary' | 'danger'

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-[var(--accent)] text-white hover:bg-[var(--accent-hover)]',
  secondary: 'glass-pill text-[var(--ink)] hover:bg-white/80',
  danger: 'bg-white/60 text-[var(--danger)] ring-1 ring-[var(--danger)]/40 hover:bg-white/90',
}

interface TxButtonProps {
  label: string
  onClick: () => void
  /** Real in-flight step from the transaction hook, e.g. "Allow USDC". */
  step?: string | null
  disabled?: boolean
  variant?: Variant
  /** Skip the connect / switch-network gates (for purely local actions). */
  local?: boolean
  className?: string
}

export function TxButton({ label, onClick, step, disabled, variant = 'primary', local, className = '' }: TxButtonProps) {
  const { isConnected, chainId } = useAccount()
  const { setOpen } = useModal()
  const { switchChain, isPending: switching } = useSwitchChain()

  let text: ReactNode = label
  let action = onClick
  let off = disabled

  if (!local && !isConnected) {
    text = 'Connect wallet'
    action = () => setOpen(true)
    off = false
  } else if (!local && chainId !== CHAIN_ID) {
    text = switching ? 'Switching…' : 'Switch to Arc Testnet'
    action = () => switchChain({ chainId: CHAIN_ID })
    off = switching
  } else if (step) {
    text = (
      <span className="flex items-center justify-center gap-2">
        <Loader2 className="size-4 animate-spin" aria-hidden /> {step}…
      </span>
    )
    off = true
  }

  return (
    <button
      type="button"
      onClick={action}
      disabled={off}
      className={`min-h-11 w-full rounded-2xl px-4 py-3 text-sm font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)] enabled:active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-45 ${VARIANTS[variant]} ${className}`}
    >
      {text}
    </button>
  )
}

export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title: string; children: ReactNode }) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
        >
          <div className="absolute inset-0 bg-black/25 backdrop-blur-sm" />
          <motion.section
            role="dialog"
            aria-modal="true"
            aria-label={title}
            className="relative max-h-[92dvh] w-full max-w-md overflow-y-auto rounded-t-3xl sm:rounded-3xl"
            style={{ background: 'rgba(255,255,255,0.9)', backdropFilter: 'blur(40px) saturate(200%)', WebkitBackdropFilter: 'blur(40px) saturate(200%)' }}
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', stiffness: 380, damping: 36 }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="spectral h-1" />
            <div className="flex items-center justify-between px-5 pb-1 pt-4">
              <h2 className="display text-xl font-bold">{title}</h2>
              <button
                type="button"
                onClick={onClose}
                aria-label="Close"
                className="flex size-9 items-center justify-center rounded-full text-[var(--muted)] hover:bg-black/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
              >
                <X className="size-5" />
              </button>
            </div>
            <div className="px-5 pb-6 pt-2">{children}</div>
          </motion.section>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

export function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={`min-h-10 rounded-full px-4 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)] ${
        active ? 'bg-[var(--accent)] text-white' : 'glass-pill text-[var(--ink-2)] hover:bg-white/80'
      }`}
    >
      {children}
    </button>
  )
}

export function Badge({ tone = 'neutral', children }: { tone?: 'neutral' | 'success' | 'danger' | 'accent'; children: ReactNode }) {
  const tones = {
    neutral: 'bg-black/5 text-[var(--ink-2)]',
    success: 'bg-[rgba(26,128,71,0.12)] text-[var(--success)]',
    danger: 'bg-[rgba(186,43,76,0.1)] text-[var(--danger)]',
    accent: 'bg-[var(--accent)] text-white',
  }
  return <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.06em] ${tones[tone]}`}>{children}</span>
}
