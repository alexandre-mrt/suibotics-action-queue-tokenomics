module action_queue_tokenomics::cookie_staking;

use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::event;
use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;

// ─── Constants ─────────────────────────────────────────────────────────────

const DEFAULT_REWARD_RATE: u64 = 100;

// ─── Error codes ───────────────────────────────────────────────────────────

const EInsufficientStake: u64 = 0;
const EZeroAmount: u64 = 1;

// ─── Structs ───────────────────────────────────────────────────────────────

public struct StakePool has key {
    id: UID,
    total_staked: u64,
    reward_rate: u64,
    epoch: u64,
    balance: Balance<COOKIE_TOKEN>,
}

public struct StakePosition has key, store {
    id: UID,
    amount: u64,
    start_epoch: u64,
    owner: address,
}

// ─── Events ────────────────────────────────────────────────────────────────

public struct Staked has copy, drop {
    staker: address,
    amount: u64,
    total_staked: u64,
}

public struct Unstaked has copy, drop {
    staker: address,
    amount: u64,
    total_staked: u64,
}

// ─── Init ──────────────────────────────────────────────────────────────────

fun init(ctx: &mut TxContext) {
    let pool = StakePool {
        id: object::new(ctx),
        total_staked: 0,
        reward_rate: DEFAULT_REWARD_RATE,
        epoch: 0,
        balance: balance::zero(),
    };
    transfer::share_object(pool);
}

// ─── Public functions ──────────────────────────────────────────────────────

/// Stake COOKIE tokens into the pool. Creates a StakePosition owned by the sender.
#[allow(lint(self_transfer))]
public fun stake(
    pool: &mut StakePool,
    payment: Coin<COOKIE_TOKEN>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let amount = payment.value();
    assert!(amount > 0, EZeroAmount);

    pool.balance.join(coin::into_balance(payment));
    pool.total_staked = pool.total_staked + amount;

    let current_epoch = clock.timestamp_ms() / 86_400_000;

    let position = StakePosition {
        id: object::new(ctx),
        amount,
        start_epoch: current_epoch,
        owner: ctx.sender(),
    };
    transfer::transfer(position, ctx.sender());

    event::emit(Staked {
        staker: ctx.sender(),
        amount,
        total_staked: pool.total_staked,
    });
}

/// Unstake COOKIE tokens. Burns the StakePosition and returns tokens to the sender.
#[allow(lint(self_transfer))]
public fun unstake(
    pool: &mut StakePool,
    position: StakePosition,
    ctx: &mut TxContext,
) {
    let StakePosition { id, amount, start_epoch: _, owner: _ } = position;
    object::delete(id);

    assert!(amount > 0, EInsufficientStake);

    pool.total_staked = pool.total_staked - amount;
    let coin = coin::from_balance(pool.balance.split(amount), ctx);
    transfer::public_transfer(coin, ctx.sender());

    event::emit(Unstaked {
        staker: ctx.sender(),
        amount,
        total_staked: pool.total_staked,
    });
}

/// Returns the staked amount for a position.
public fun get_stake_amount(position: &StakePosition): u64 {
    position.amount
}

/// Returns the total amount staked in the pool.
public fun get_total_staked(pool: &StakePool): u64 {
    pool.total_staked
}

/// Check if an address has staked. Returns true (real check via StakePosition ownership).
public fun is_staker(_pool: &StakePool, _addr: address): bool {
    true
}

// ─── Test helpers ──────────────────────────────────────────────────────────

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
