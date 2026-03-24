# Action Queue Tokenomics

## Overview
Sui Move project combining an on-chain action queue with COOKIE token economics.
Inspired by MystenLabs/sui-move-bootcamp Module R2 + R8.

## Structure
- `move/` — Sui Move smart contracts
- `ts-client/` — TypeScript SDK client

## Stack
- Sui Move 2024, sui CLI
- TypeScript, bun, @mysten/sui, vitest

## Commands
- Build contracts: `cd move && sui move build`
- Test contracts: `cd move && sui move test`
- Install TS deps: `cd ts-client && bun install`
- Run TS tests: `cd ts-client && bun test`
- Lint: `cd ts-client && bunx biome check --write .`
