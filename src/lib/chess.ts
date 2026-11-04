import { BaseError, ContractFunctionRevertedError, type Address } from 'viem'
import { arcTestnet } from 'viem/chains'
import { getUsdc } from '@/onchain-facts'
import { formatUnitsFixed, usdcDecimalsFor } from '@/onchain-money'

export const CHAIN_ID = arcTestnet.id

export const CHESS_ADDRESS = import.meta.env.VITE_CHESS_ADDRESS as Address

const usdcFact = getUsdc(CHAIN_ID)
if (!usdcFact) throw new Error('USDC is not registered for Arc Testnet')
export const USDC_ADDRESS = usdcFact.address as Address

export const STATUS = { None: 0, Open: 1, Active: 2, Finished: 3, Cancelled: 4 } as const
export const END = { None: 0, KingCaptured: 1, Resigned: 2, Timeout: 3, DrawAgreed: 4, Cancelled: 5 } as const

export const ZERO: Address = '0x0000000000000000000000000000000000000000'

export interface GameData {
  id: bigint
  white: Address
  black: Address
  invited: Address
  wager: bigint
  moveTimeout: number
  lastMoveAt: number
  moveCount: number
  status: number
  endReason: number
  whiteToMove: boolean
  drawOfferedBy: number
  winner: Address
  board: bigint
}

export const same = (a?: string, b?: string) => !!a && !!b && a.toLowerCase() === b.toLowerCase()
export const isZero = (a: string) => a === ZERO

export const shortAddr = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`

export const fmtUsdc = (raw: bigint) => formatUnitsFixed(raw, usdcDecimalsFor(CHAIN_ID), 2)

export const creatorOf = (g: GameData): Address => (isZero(g.white) ? g.black : g.white)

export function mySide(g: GameData, me?: string): 'white' | 'black' | null {
  if (same(g.white, me)) return 'white'
  if (same(g.black, me)) return 'black'
  return null
}

// ---- board helpers -------------------------------------------------------

export const FILES = 'abcdefgh'
export const squareName = (i: number) => `${FILES[i % 8]}${Math.floor(i / 8) + 1}`

export function decodeBoard(board: bigint): number[] {
  const out: number[] = []
  for (let i = 0; i < 64; i++) out.push(Number((board >> BigInt(i * 4)) & 15n))
  return out
}

export const kindOf = (p: number) => p & 7
export const isWhitePiece = (p: number) => p !== 0 && (p & 8) === 0

// Filled glyphs for both colours, tinted via CSS. U+FE0E forces text presentation.
const GLYPHS = ['', '\u265F', '\u265E', '\u265D', '\u265C', '\u265B', '\u265A']
export const glyph = (p: number) => (GLYPHS[kindOf(p)] ?? '') + '\uFE0E'

export const PIECE_NAMES = ['', 'pawn', 'knight', 'bishop', 'rook', 'queen', 'king']
export const pieceName = (p: number) => `${isWhitePiece(p) ? 'white' : 'black'} ${PIECE_NAMES[kindOf(p)]}`

const START_COUNTS = [0, 8, 2, 2, 2, 1, 1]

/** Pieces each side has lost, derived from the live board (no history needed). */
export function capturedPieces(squares: number[]) {
  const have = { w: [0, 0, 0, 0, 0, 0, 0], b: [0, 0, 0, 0, 0, 0, 0] }
  for (const p of squares) {
    if (p === 0) continue
    ;(isWhitePiece(p) ? have.w : have.b)[kindOf(p)]++
  }
  const lost = (counts: number[], white: boolean) => {
    const list: number[] = []
    for (let k = 5; k >= 1; k--) {
      const missing = Math.max(0, START_COUNTS[k] - counts[k])
      for (let n = 0; n < missing; n++) list.push(white ? k : 8 + k)
    }
    return list
  }
  return { lostWhite: lost(have.w, true), lostBlack: lost(have.b, false) }
}

/** Find the last move by diffing two boards. */
export function diffMove(prev: number[], next: number[]): { from: number; to: number } | null {
  let from = -1
  let to = -1
  for (let i = 0; i < 64; i++) {
    if (prev[i] === next[i]) continue
    if (next[i] === 0) from = i
    else to = i
  }
  return from >= 0 && to >= 0 ? { from, to } : null
}

// ---- copy ----------------------------------------------------------------

export function endText(g: GameData, me?: string): { title: string; detail: string; tone: 'win' | 'loss' | 'draw' | 'neutral' } {
  const pot = fmtUsdc(g.wager * 2n)
  const mine = mySide(g, me)
  if (g.status === STATUS.Cancelled) return { title: 'Game cancelled', detail: 'The wager was refunded.', tone: 'neutral' }
  if (g.endReason === END.DrawAgreed) {
    return { title: 'Draw agreed', detail: `Both wagers (${fmtUsdc(g.wager)} USDC) were returned.`, tone: 'draw' }
  }
  const reason =
    g.endReason === END.KingCaptured ? 'by capturing the king' : g.endReason === END.Resigned ? 'by resignation' : 'on time'
  const winnerSide = same(g.winner, g.white) ? 'White' : 'Black'
  if (!mine) return { title: `${winnerSide} wins`, detail: `Won ${reason}. Pot: ${pot} USDC.`, tone: 'neutral' }
  const iWon = same(g.winner, me)
  return iWon
    ? { title: 'You won', detail: `Victory ${reason}. ${pot} USDC paid out.`, tone: 'win' }
    : { title: 'You lost', detail: `Defeat ${reason}.`, tone: 'loss' }
}

export const TIMEOUT_CHOICES = [
  { label: '1 min', seconds: 60 },
  { label: '5 min', seconds: 300 },
  { label: '1 hour', seconds: 3600 },
  { label: '1 day', seconds: 86400 },
]

export const fmtClock = (secs: number) => {
  const s = Math.max(0, Math.floor(secs))
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`
  return `${m}:${String(sec).padStart(2, '0')}`
}

// ---- errors --------------------------------------------------------------

const REVERT_COPY: Record<string, string> = {
  IllegalMove: 'That move is not legal.',
  NotYourTurn: 'It is not your turn.',
  MoveTimedOut: 'Your clock ran out. Your opponent can claim the win.',
  InvalidPromotion: 'Pick a piece to promote to.',
  NotTimedOut: 'The clock has not run out yet.',
  CannotJoinOwnGame: 'You cannot join your own game.',
  NotInvited: 'This game is reserved for another player.',
  InvalidStatus: 'This game is no longer in that state.',
  NotPlayer: 'You are not a player in this game.',
  NoDrawOffer: 'There is no draw offer to accept.',
  CannotAcceptOwnDraw: 'Your opponent has to accept your draw offer.',
  InvalidMoveTimeout: 'Pick a move clock between 1 minute and 30 days.',
  InvalidInvitation: 'You cannot invite yourself.',
  NotCreator: 'Only the creator can cancel this game.',
  NothingOwed: 'Nothing to withdraw.',
}

/** Returns user-facing copy, or null when the user simply cancelled in their wallet. */
export function describeError(err: unknown): string | null {
  if (err instanceof BaseError) {
    const reverted = err.walk((e) => e instanceof ContractFunctionRevertedError)
    if (reverted instanceof ContractFunctionRevertedError) {
      const name = reverted.data?.errorName
      if (name && REVERT_COPY[name]) return REVERT_COPY[name]
    }
    if (err.walk((e) => (e as { name?: string }).name === 'UserRejectedRequestError')) return null
  }
  const msg = err instanceof Error ? err.message.toLowerCase() : ''
  if (msg.includes('user rejected') || msg.includes('user denied')) return null
  if (msg.includes('insufficient') || msg.includes('exceeds balance')) return 'Not enough USDC for this. Use "Get test USDC" in the sidebar.'
  if (msg.includes('network') || msg.includes('timeout')) return 'Network issue. Please try again.'
  return 'Transaction failed. Please try again.'
}
