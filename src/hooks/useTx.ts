import { useCallback, useState } from 'react'
import { erc20Abi, type Hash, type TransactionReceipt } from 'viem'
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { CHAIN_ID, CHESS_ADDRESS, USDC_ADDRESS, describeError } from '@/lib/chess'

/**
 * Runs wallet transactions one at a time with honest status:
 * the label is only shown while the wallet or the chain is actually working.
 */
export function useTx() {
  const { address, chainId } = useAccount()
  const { writeContractAsync } = useWriteContract()
  const { switchChainAsync } = useSwitchChain()
  const publicClient = usePublicClient({ chainId: CHAIN_ID })
  const queryClient = useQueryClient()
  const [step, setStep] = useState<string | null>(null)
  const [lastTx, setLastTx] = useState<Hash | null>(null)

  const send = useCallback(
    async (label: string, submit: () => Promise<Hash>): Promise<TransactionReceipt | null> => {
      try {
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID })
        setStep(label)
        const hash = await submit()
        setLastTx(hash)
        if (!publicClient) throw new Error('network unavailable')
        const receipt = await publicClient.waitForTransactionReceipt({ hash })
        if (receipt.status !== 'success') throw new Error('Transaction reverted')
        await queryClient.invalidateQueries()
        return receipt
      } catch (err) {
        const message = describeError(err)
        if (message) toast.error(message)
        return null
      } finally {
        setStep(null)
      }
    },
    [chainId, publicClient, queryClient, switchChainAsync],
  )

  /** Approves exactly `amount` USDC for the chess contract when the allowance is too low. */
  const ensureAllowance = useCallback(
    async (amount: bigint): Promise<boolean> => {
      if (amount === 0n || !address || !publicClient) return true
      const allowance = await publicClient.readContract({
        address: USDC_ADDRESS,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [address, CHESS_ADDRESS],
      })
      if (allowance >= amount) return true
      const receipt = await send('Allow USDC', () =>
        writeContractAsync({
          address: USDC_ADDRESS,
          abi: erc20Abi,
          functionName: 'approve',
          args: [CHESS_ADDRESS, amount],
          chainId: CHAIN_ID,
        }),
      )
      return receipt !== null
    },
    [address, publicClient, send, writeContractAsync],
  )

  return { address, step, lastTx, send, ensureAllowance, writeContractAsync, busy: step !== null }
}
