#[test_only]
module action_queue_tokenomics::action_queue_tests;

use action_queue_tokenomics::action_queue::{Self, ActionQueue, AdminCap};
use action_queue_tokenomics::cookie_token::{Self, FaucetState};
use sui::clock;
use sui::test_scenario::{Self as ts};

// ─── Helpers ───────────────────────────────────────────────────────────────

const ADMIN: address = @0xAD;
const USER: address = @0xB0;

// ─── Tests ─────────────────────────────────────────────────────────────────

#[test]
fun test_enqueue_valid_action_types() {
    let mut scenario = ts::begin(ADMIN);

    // Init both modules
    {
        let ctx = ts::ctx(&mut scenario);
        action_queue::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    // Enqueue each valid action type
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
        // action_type = 5 is invalid
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

    // Enqueue one action
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

    // Dequeue as admin
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

    // Enqueue 3 actions
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

    // Verify queue length is 3
    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 3);
        assert!(action_queue::get_history_length(&queue) == 0);
        ts::return_shared(queue);
    };

    // Dequeue 2 actions
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

    // Verify: 1 pending, 2 in history
    ts::next_tx(&mut scenario, ADMIN);
    {
        let queue = ts::take_shared<ActionQueue>(&scenario);
        assert!(action_queue::get_queue_length(&queue) == 1);
        assert!(action_queue::get_history_length(&queue) == 2);
        ts::return_shared(queue);
    };

    ts::end(scenario);
}
