module action_queue_tokenomics::action_queue;

use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::event;
use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;

// ─── Constants ─────────────────────────────────────────────────────────────

const MAX_ACTION_TYPE: u8 = 4;
// 1 COOKIE (9 decimals)
const ACTION_COST: u64 = 1_000_000_000;
const MAX_HISTORY: u64 = 1000;
const MAX_PARAMS_LENGTH: u64 = 256;

// ─── Error codes ───────────────────────────────────────────────────────────

const EInvalidActionType: u64 = 0;
const EEmptyQueue: u64 = 1;
const EInsufficientPayment: u64 = 2;
const EParamsTooLong: u64 = 3;
const ENoFeesToWithdraw: u64 = 4;

// ─── Structs ───────────────────────────────────────────────────────────────

public struct Action has store {
    id: u64,
    action_type: u8,
    params: vector<u8>,
    creator: address,
    created_at: u64,
}

public struct ActionRecord has store {
    id: u64,
    action_type: u8,
    params: vector<u8>,
    creator: address,
    created_at: u64,
    executed_at: u64,
}

public struct ActionQueue has key {
    id: UID,
    actions: vector<Action>,
    history: vector<ActionRecord>,
    action_count: u64,
    fees: Balance<COOKIE_TOKEN>,
}

public struct AdminCap has key, store {
    id: UID,
}

// ─── Events ────────────────────────────────────────────────────────────────

public struct ActionEnqueued has copy, drop {
    action_type: u8,
    creator: address,
    queue_length: u64,
}

public struct ActionDequeued has copy, drop {
    action_type: u8,
    executor: address,
}

// ─── Init ──────────────────────────────────────────────────────────────────

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::transfer(admin_cap, ctx.sender());

    let queue = ActionQueue {
        id: object::new(ctx),
        actions: vector::empty(),
        history: vector::empty(),
        action_count: 0,
        fees: balance::zero(),
    };
    transfer::share_object(queue);
}

// ─── Public functions ──────────────────────────────────────────────────────

/// Enqueue a robot action. Requires at least ACTION_COST COOKIE tokens.
/// Exact cost is retained in the queue fee balance; change is returned to sender.
#[allow(lint(self_transfer))]
public fun enqueue(
    queue: &mut ActionQueue,
    action_type: u8,
    params: vector<u8>,
    mut payment: Coin<COOKIE_TOKEN>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(action_type <= MAX_ACTION_TYPE, EInvalidActionType);
    assert!(params.length() <= MAX_PARAMS_LENGTH, EParamsTooLong);
    assert!(payment.value() >= ACTION_COST, EInsufficientPayment);

    // Split exact cost from payment
    let fee_coin = payment.split(ACTION_COST, ctx);
    queue.fees.join(coin::into_balance(fee_coin));

    // Return change to sender if any remains
    if (payment.value() > 0) {
        transfer::public_transfer(payment, ctx.sender());
    } else {
        coin::destroy_zero(payment);
    };

    let action_id = queue.action_count;
    queue.action_count = queue.action_count + 1;

    queue.actions.push_back(Action {
        id: action_id,
        action_type,
        params,
        creator: ctx.sender(),
        created_at: clock.timestamp_ms(),
    });

    let queue_length = queue.actions.length();

    event::emit(ActionEnqueued {
        action_type,
        creator: ctx.sender(),
        queue_length,
    });
}

/// Dequeue the first pending action, moving it to history. Admin only.
public fun dequeue(
    queue: &mut ActionQueue,
    _: &AdminCap,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(!queue.actions.is_empty(), EEmptyQueue);

    let Action { id, action_type, params, creator, created_at } = queue.actions.remove(0);

    if (queue.history.length() >= MAX_HISTORY) {
        let ActionRecord { id: _, action_type: _, params: _, creator: _, created_at: _, executed_at: _ } = queue.history.remove(0);
    };

    queue.history.push_back(ActionRecord {
        id,
        action_type,
        params,
        creator,
        created_at,
        executed_at: clock.timestamp_ms(),
    });

    event::emit(ActionDequeued {
        action_type,
        executor: ctx.sender(),
    });
}

/// Withdraw accumulated fees. Admin only.
#[allow(lint(self_transfer))]
public fun withdraw_fees(
    queue: &mut ActionQueue,
    _: &AdminCap,
    ctx: &mut TxContext,
) {
    let amount = queue.fees.value();
    assert!(amount > 0, ENoFeesToWithdraw);
    let coin = coin::from_balance(queue.fees.split(amount), ctx);
    transfer::public_transfer(coin, ctx.sender());
}

/// Returns the number of pending actions in the queue.
public fun get_queue_length(queue: &ActionQueue): u64 {
    queue.actions.length()
}

/// Returns the number of completed actions in history.
public fun get_history_length(queue: &ActionQueue): u64 {
    queue.history.length()
}

// ─── Test helpers ──────────────────────────────────────────────────────────

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
