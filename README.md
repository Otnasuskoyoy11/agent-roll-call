# Agent Roll Call

A daily on-chain roll call for **Agent ID** holders, built for the Binance
Agent ID Hackathon (Binance Wallet × BNB Chain).

**Live page:** https://otnasuskoyoy11.github.io/agent-roll-call/
**Contract (BNB Chain):** https://bscscan.com/address/0xd6d3f3f41ee421e256583e0333f792cd128bdc24

## What it does

If your wallet holds an Agent ID, you can sign today's roll call — once per
UTC day. The contract records your check-in count and streak, plus the global
counters (total check-ins, distinct agents). That is the whole product.

## How Agent ID is used

Agent ID is the contract's only write permission. The single state-changing
function, `checkIn()`, first calls `balanceOf(msg.sender)` on the official
Agent ID registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) and reverts
if the caller holds no Agent ID. Because Agent IDs are non-transferable and
limited to one per user, a streak belongs to a durable agent identity —
a sybil-resistant proof of ongoing presence.

## Safety by construction

- No payable functions — the contract cannot receive funds
- No token, no transfers, no approvals
- No owner, no admin, no pause, no upgrade — the registry address is immutable
- Source verified: Sourcify exact match (creation + runtime)

Contract source: [`contracts/AgentRollCall.sol`](contracts/AgentRollCall.sol)
(MIT, Solidity 0.8.24).

## Checking in

Open the live page, connect your own wallet (injected wallet only — no QR
login, no pairing codes), and press **Check in today**. Your wallet will ask
you to confirm the single `checkIn()` transaction; it costs only that
transaction's gas.
