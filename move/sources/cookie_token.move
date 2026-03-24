module action_queue_tokenomics::cookie_token;

use sui::coin::{Self, Coin, TreasuryCap};
use sui::clock::Clock;
use sui::event;
use sui::table::{Self, Table};

// ─── Constants ─────────────────────────────────────────────────────────────

const MAX_CLAIMS_PER_EPOCH: u64 = 3;
// 10 COOKIE with 9 decimals
const CLAIM_AMOUNT: u64 = 10_000_000_000;
const DECIMALS: u8 = 9;

// ─── Error codes ───────────────────────────────────────────────────────────

const EFaucetLimitReached: u64 = 0;

// ─── OTW ───────────────────────────────────────────────────────────────────

public struct COOKIE_TOKEN has drop {}

// ─── Structs ───────────────────────────────────────────────────────────────

public struct ClaimRecord has store {
    epoch: u64,
    count: u64,
}

public struct FaucetState has key {
    id: UID,
    treasury_cap: TreasuryCap<COOKIE_TOKEN>,
    claims: Table<address, ClaimRecord>,
    max_claims_per_epoch: u64,
    claim_amount: u64,
}

// ─── Events ────────────────────────────────────────────────────────────────

public struct FaucetClaimed has copy, drop {
    claimer: address,
    amount: u64,
    epoch: u64,
}

public struct TokensMinted has copy, drop {
    recipient: address,
    amount: u64,
}

// ─── Init ──────────────────────────────────────────────────────────────────

#[allow(deprecated_usage)]
fun init(witness: COOKIE_TOKEN, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency(
        witness,
        DECIMALS,
        b"COOKIE",
        b"Cookie Token",
        b"Action queue payment token for the robotics platform",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);

    let faucet_state = FaucetState {
        id: object::new(ctx),
        treasury_cap,
        claims: table::new(ctx),
        max_claims_per_epoch: MAX_CLAIMS_PER_EPOCH,
        claim_amount: CLAIM_AMOUNT,
    };
    transfer::share_object(faucet_state);
}

// ─── Public functions ──────────────────────────────────────────────────────

/// Claim COOKIE tokens from the faucet.
/// Rate-limited to max_claims_per_epoch per address per epoch.
#[allow(lint(self_transfer))]
public fun claim_faucet(
    faucet: &mut FaucetState,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let claimer = ctx.sender();
    let current_epoch = clock.timestamp_ms() / 86_400_000;

    if (faucet.claims.contains(claimer)) {
        let record = faucet.claims.borrow_mut(claimer);
        if (record.epoch == current_epoch) {
            assert!(record.count < faucet.max_claims_per_epoch, EFaucetLimitReached);
            record.count = record.count + 1;
        } else {
            record.epoch = current_epoch;
            record.count = 1;
        };
    } else {
        faucet.claims.add(claimer, ClaimRecord {
            epoch: current_epoch,
            count: 1,
        });
    };

    let amount = faucet.claim_amount;
    let minted = coin::mint(&mut faucet.treasury_cap, amount, ctx);
    transfer::public_transfer(minted, claimer);

    event::emit(FaucetClaimed {
        claimer,
        amount,
        epoch: current_epoch,
    });

    event::emit(TokensMinted {
        recipient: claimer,
        amount,
    });
}

/// Returns the balance of a COOKIE coin object.
public fun get_balance(coin: &Coin<COOKIE_TOKEN>): u64 {
    coin.value()
}

// ─── Test helpers ──────────────────────────────────────────────────────────

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(COOKIE_TOKEN {}, ctx);
}

#[test_only]
public fun mint_for_testing(
    faucet: &mut FaucetState,
    amount: u64,
    ctx: &mut TxContext,
): Coin<COOKIE_TOKEN> {
    coin::mint(&mut faucet.treasury_cap, amount, ctx)
}
