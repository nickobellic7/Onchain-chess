import { useEffect, useMemo, useRef, useState } from 'react'
import { erc20Abi, type ContractFunctionReturnType } from 'viem'
import { useBlock, useReadContract, useReadContracts } from 'wagmi'
import { chessAbi } from '@/lib/chessAbi'
import { CHAIN_ID, CHESS_ADDRESS, USDC_ADDRESS, type GameData } from '@/lib/chess'

type GameStruct = ContractFunctionReturnType<typeof chessAbi, 'view', 'getGame'>

function toGame(id: bigint, g: GameStruct): GameData {
  return {
    id,
    white: g.white,
    black: g.black,
    invited: g.invited,
    wager: g.wager,
    moveTimeout: Number(g.moveTimeout),
    lastMoveAt: Number(g.lastMoveAt),
    moveCount: Number(g.moveCount),
    status: Number(g.status),
    endReason: Number(g.endReason),
    whiteToMove: g.whiteToMove,
    drawOfferedBy: Number(g.drawOfferedBy),
    winner: g.winner,
    board: g.board,
  }
}

/** The most recent games, newest first. */
export function useGames(limit = 30) {
  const count = useReadContract({
    address: CHESS_ADDRESS,
    abi: chessAbi,
    functionName: 'gameCount',
    chainId: CHAIN_ID,
    query: { refetchInterval: 4000 },
  })
  const total = Number(count.data ?? 0n)
  const ids = useMemo(() => Array.from({ length: Math.min(limit, total) }, (_, i) => BigInt(total - i)), [limit, total])

  const reads = useReadContracts({
    contracts: ids.map(
      (id) => ({ address: CHESS_ADDRESS, abi: chessAbi, functionName: 'getGame', args: [id], chainId: CHAIN_ID }) as const,
    ),
    query: { enabled: ids.length > 0, refetchInterval: 4000 },
  })

  const games = useMemo<GameData[]>(
    () => (reads.data ?? []).flatMap((r, i) => (r.status === 'success' ? [toGame(ids[i], r.result)] : [])),
    [reads.data, ids],
  )

  return { games, total, isLoading: count.isLoading || (ids.length > 0 && reads.isLoading), isError: count.isError || reads.isError }
}

/** One game, polled while it is on screen. */
export function useGame(id: bigint | null) {
  const read = useReadContract({
    address: CHESS_ADDRESS,
    abi: chessAbi,
    functionName: 'getGame',
    args: id === null ? undefined : [id],
    chainId: CHAIN_ID,
    query: { enabled: id !== null, refetchInterval: 1500 },
  })
  const game = useMemo(() => (id !== null && read.data ? toGame(id, read.data) : null), [id, read.data])
  return { game, isLoading: read.isLoading, isError: read.isError }
}

/** Squares the piece on `from` may move to, straight from the contract's own rules. */
export function useTargets(from: number | null, boardKey: bigint, whiteToMove: boolean) {
  const read = useReadContract({
    address: CHESS_ADDRESS,
    abi: chessAbi,
    functionName: 'legalTargets',
    args: from === null ? undefined : [boardKey, whiteToMove, from],
    chainId: CHAIN_ID,
    query: { enabled: from !== null, staleTime: Infinity, gcTime: 60_000 },
  })
  return useMemo(() => {
    const set = new Set<number>()
    const mask = read.data
    if (from === null || mask === undefined) return set
    for (let i = 0; i < 64; i++) if ((mask >> BigInt(i)) & 1n) set.add(i)
    return set
  }, [read.data, from])
}

export function useUsdcBalance(address?: `0x${string}`) {
  const read = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: CHAIN_ID,
    query: { enabled: !!address, refetchInterval: 5000 },
  })
  return { balance: read.data, isLoading: read.isLoading }
}

export function useOwed(address?: `0x${string}`) {
  const read = useReadContract({
    address: CHESS_ADDRESS,
    abi: chessAbi,
    functionName: 'owed',
    args: address ? [address] : undefined,
    chainId: CHAIN_ID,
    query: { enabled: !!address, refetchInterval: 8000 },
  })
  return read.data ?? 0n
}

/** Seconds since epoch, corrected to the chain's own clock so timeouts match the contract. */
export function useChainNow() {
  const block = useBlock({ chainId: CHAIN_ID, query: { refetchInterval: 6000 } })
  const offset = useRef(0)
  const [now, setNow] = useState(() => Date.now() / 1000)

  useEffect(() => {
    if (block.data) offset.current = Number(block.data.timestamp) - Date.now() / 1000
  }, [block.data])

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now() / 1000 + offset.current), 1000)
    return () => clearInterval(t)
  }, [])

  return now
}
