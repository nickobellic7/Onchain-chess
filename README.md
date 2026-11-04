# Onchain Chess

Play 1v1 chess for USDC on Arc Testnet. Stake USDC, challenge anyone (or invite a friend), and the winner takes the pot. Every move is validated by a smart contract.

Built with [Arc Studio](https://studio.arc.io)

**Live app:** https://nikobel7-app-aac8ef68-f1cb-49bc-9531-64916499fd6e.static.hf.space

**Contract (Arc Testnet):** [0xdfe7256f52cfc4540e129d140c52b5c431ce08ef](https://explorer.testnet.arc.io/address/0xdfe7256f52cfc4540e129d140c52b5c431ce08ef)

## Features

- Create open or invite-only games with a USDC stake (or free games)
- Choose your color and a time limit per move
- Join open challenges, spectate live games, share a game link
- Resign, offer or accept a draw, or claim a win when the opponent's clock runs out
- Payouts are automatic; any payout that cannot be sent is available to withdraw from the lobby

## Rules

Win by capturing the enemy king. Castling and en passant are not included, and moving into check is allowed. Draws are by agreement.

## Tech stack

Vite, React, TypeScript, Tailwind CSS, wagmi, viem, ConnectKit. Solidity contract built with Foundry and OpenZeppelin.

## Development

Prerequisites: [Bun](https://bun.sh) and [Foundry](https://getfoundry.sh).

```bash
bun install
bun run dev
```

Other commands: `bun run check` (lint and typecheck), `bun run contracts:build`, `bun run contracts:test`.

### Environment variables

- `VITE_CHESS_ADDRESS`: address of the deployed chess contract on Arc Testnet.
- `RPC_PROXY_BASE_URL`, `RPC_PROXY_TOKEN`, `RPC_PROXY_CHAINS`: provisioned by Arc Studio, optional outside Arc Studio.
