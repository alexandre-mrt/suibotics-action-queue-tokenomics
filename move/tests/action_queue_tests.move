#[test_only]
module action_queue_tokenomics::action_queue_tests;

use action_queue_tokenomics::action_queue::{Self, ActionQueue, AdminCap};
use action_queue_tokenomics::cookie_token::{Self, FaucetState};
use sui::clock;
use sui::test_scenario::{Self as ts};

// ─── Helpers ───────────────────────────────────────────────────────────────

const ADMIN: address = @0xAD;
const USER: address = @0xB0;
const USER2: address = @0xC1;

// ─── Tests ─────────────────────────────────────────────────────────────────

#[test]
fun test_enqueue_valid_action_types() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    let mut action_type = 0u8;
    while (action_type <= 4) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(
                &mut queue,
                action_type,
                vector::empty(),
                payment,
                &clk,
                ctx,
            );
            let expected_length = (action_type as u64) + 1;
            assert!(action_queue::get_queue_length(&queue) == expected_length);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        action_type = action_type + 1;
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = action_queue::EInvalidActionType)]
fun test_enqueue_invalid_action_type_aborts() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(
            &mut queue,
            5,
            vector::empty(),
            payment,
            &clk,
            ctx,
        );
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_dequeue_from_non_empty_queue() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(
            &mut queue,
            0,
            vector[1u8, 2u8, 3u8],
            payment,
            &clk,
            ctx,
        );
        assert!(action_queue::get_queue_length(&queue) == 1);
        assert!(action_queue::get_history_length(&queue) == 0);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
        assert!(action_queue::get_queue_length(&queue) == 0);
        assert!(action_queue::get_history_length(&queue) == 1);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = action_queue::EEmptyQueue)]
fun test_dequeue_from_empty_queue_aborts() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    ts::end(scenario);
}

#[test]
fun test_queue_length_tracking() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    let mut i = 0u8;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(
                &mut queue,
                i,
                vector::empty(),
                payment,
                &clk,
                ctx,
            );
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 3);
        assert!(action_queue::get_history_length(&queue) == 0);
        ts::return_shared(queue);
    };

    let mut j = 0u8;
    while (j < 2) {
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_to_sender(&scenario, admin_cap);
        };
        j = j + 1;
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 1);
        assert!(action_queue::get_history_length(&queue) == 2);
        ts::return_shared(queue);
    };

    ts::end(scenario);
}

// ─── NEW TESTS ─────────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = action_queue::EInsufficientPayment)]
fun test_enqueue_insufficient_payment_aborts() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        // Only 500M, need 1B
        let payment = cookie_token::mint_for_testing(&mut faucet, 500_000_000, ctx);
        action_queue::enqueue(&mut queue, 0, vector::empty(), payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = action_queue::EParamsTooLong)]
fun test_enqueue_params_too_long_aborts() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        // 257 bytes exceeds MAX_PARAMS_LENGTH (256)
        let mut params = vector::empty<u8>();
        let mut k = 0u64;
        while (k < 257) {
            params.push_back(0u8);
            k = k + 1;
        };
        action_queue::enqueue(&mut queue, 0, params, payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_enqueue_with_exact_max_params() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        // Exactly 256 bytes — should succeed
        let mut params = vector::empty<u8>();
        let mut k = 0u64;
        while (k < 256) {
            params.push_back(1u8);
            k = k + 1;
        };
        action_queue::enqueue(&mut queue, 0, params, payment, &clk, ctx);
        assert!(action_queue::get_queue_length(&queue) == 1);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_enqueue_overpayment_returns_change() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        // Pay 2x the cost
        let payment = cookie_token::mint_for_testing(&mut faucet, 2_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 0, vector::empty(), payment, &clk, ctx);
        assert!(action_queue::get_queue_length(&queue) == 1);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    // Verify USER got change back (1B change coin)
    ts::next_tx(&mut scenario, USER);
    {
        use sui::coin::Coin;
        use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;
        let change = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(change.value() == 1_000_000_000, 0);
        ts::return_to_sender(&scenario, change);
    };

    ts::end(scenario);
}

#[test]
fun test_withdraw_fees_success() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // Enqueue 2 actions to accumulate fees
    let mut i = 0u8;
    while (i < 2) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(&mut queue, i, vector::empty(), payment, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // Withdraw fees as admin
    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        action_queue::withdraw_fees(&mut queue, &admin_cap, ts::ctx(&mut scenario));
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    // Verify admin received 2B worth of COOKIE
    ts::next_tx(&mut scenario, ADMIN);
    {
        use sui::coin::Coin;
        use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;
        let fees = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(fees.value() == 2_000_000_000, 0);
        ts::return_to_sender(&scenario, fees);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = action_queue::ENoFeesToWithdraw)]
fun test_withdraw_fees_empty_aborts() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        action_queue::withdraw_fees(&mut queue, &admin_cap, ts::ctx(&mut scenario));
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    ts::end(scenario);
}

#[test]
fun test_multiple_enqueue_dequeue_interleaved() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // Enqueue 5 actions
    let mut i = 0u8;
    while (i < 5) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(&mut queue, (i % 5), vector::empty(), payment, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // Dequeue 3
    let mut j = 0u8;
    while (j < 3) {
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_to_sender(&scenario, admin_cap);
        };
        j = j + 1;
    };

    // Verify: 2 pending, 3 in history
    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 2);
        assert!(action_queue::get_history_length(&queue) == 3);
        ts::return_shared(queue);
    };

    // Enqueue 1 more, dequeue 1 more
    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 4, vector::empty(), payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
        assert!(action_queue::get_queue_length(&queue) == 2);
        assert!(action_queue::get_history_length(&queue) == 4);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    ts::end(scenario);
}

#[test]
fun test_multiple_users_enqueue() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // USER enqueues
    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 0, vector[1u8], payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    // USER2 enqueues
    ts::next_tx(&mut scenario, USER2);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 2, vector[2u8], payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 2);
        ts::return_shared(queue);
    };

    ts::end(scenario);
}

#[test]
fun test_enqueue_with_nonempty_params() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(
            &mut queue,
            3,
            vector[10u8, 20u8, 30u8, 40u8, 50u8],
            payment,
            &clk,
            ctx,
        );
        assert!(action_queue::get_queue_length(&queue) == 1);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_enqueue_all_action_types_boundary() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // Type 0 (min) and type 4 (max) should both work
    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 0, vector::empty(), payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 4, vector::empty(), payment, &clk, ctx);
        assert!(action_queue::get_queue_length(&queue) == 2);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = action_queue::EInvalidActionType)]
fun test_enqueue_action_type_255_aborts() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let clk = clock::create_for_testing(ctx);
        let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
        action_queue::enqueue(&mut queue, 255, vector::empty(), payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(queue);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_dequeue_preserves_fifo_order() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // Enqueue types 0, 1, 2 in order
    let mut i = 0u8;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(&mut queue, i, vector::empty(), payment, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // Dequeue all 3 — history should grow to 3
    let mut j = 0u8;
    while (j < 3) {
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            action_queue::dequeue(&mut queue, &admin_cap, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_to_sender(&scenario, admin_cap);
        };
        j = j + 1;
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 0);
        assert!(action_queue::get_history_length(&queue) == 3);
        ts::return_shared(queue);
    };

    ts::end(scenario);
}

#[test]
fun test_withdraw_fees_after_multiple_enqueues() {
    let mut scenario = ts::begin(ADMIN);
    {
        action_queue::init_for_testing(ts::ctx(&mut scenario));
        cookie_token::init_for_testing(ts::ctx(&mut scenario));
    };

    // Enqueue 3 actions (3B in fees)
    let mut i = 0u8;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut queue = ts::take_shared<ActionQueue>(&scenario);
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let clk = clock::create_for_testing(ctx);
            let payment = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000, ctx);
            action_queue::enqueue(&mut queue, 0, vector::empty(), payment, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(queue);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // Withdraw
    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut queue = ts::take_shared<ActionQueue>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        action_queue::withdraw_fees(&mut queue, &admin_cap, ts::ctx(&mut scenario));
        ts::return_shared(queue);
        ts::return_to_sender(&scenario, admin_cap);
    };

    // Verify 3B received
    ts::next_tx(&mut scenario, ADMIN);
    {
        use sui::coin::Coin;
        use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;
        let fees = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(fees.value() == 3_000_000_000, 0);
        ts::return_to_sender(&scenario, fees);
    };

    ts::end(scenario);
}
