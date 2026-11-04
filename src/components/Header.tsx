import { ConnectKitButton } from 'connectkit'
import { Crown } from 'lucide-react'

export function Header({ onHome }: { onHome: () => void }) {
  return (
    <header className="mb-6 flex items-center justify-between">
      <button
        type="button"
        onClick={onHome}
        className="flex min-h-10 items-center gap-2 rounded-full pr-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)]"
      >
        <span className="flex size-9 items-center justify-center rounded-xl bg-[var(--accent)] text-white">
          <Crown className="size-5" aria-hidden />
        </span>
        <span className="display text-lg font-bold">Onchain Chess</span>
      </button>

      <ConnectKitButton.Custom>
        {({ isConnected, show, truncatedAddress }) => (
          <button
            type="button"
            onClick={show}
            className={`min-h-10 rounded-full px-4 text-xs font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus)] ${
              isConnected ? 'glass-pill text-[var(--ink)]' : 'bg-[var(--accent)] text-white hover:bg-[var(--accent-hover)]'
            }`}
          >
            {isConnected ? <span className="mono">{truncatedAddress}</span> : 'Connect'}
          </button>
        )}
      </ConnectKitButton.Custom>
    </header>
  )
}
