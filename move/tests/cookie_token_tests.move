#[test_only]
module action_queue_tokenomics::cookie_token_tests;

use action_queue_tokenomics::cookie_token::{Self, FaucetState};
use sui::clock;
use sui::test_scenario::{Self as ts};

// ─── Helpers ───────────────────────────────────────────────────────────────

const ADMIN: address = @0xAD;
const USER: address = @0xC0;

// Milliseconds per day (epoch boundary)
const MS_PER_DAY: u64 = 86_400_000;

// ─── Tests ─────────────────────────────────────────────────────────────────

#[test]
fun test_faucet_claim_transfers_tokens() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    // Verify USER received a coin
    ts::next_tx(&mut scenario, USER);
    {
        use sui::coin::Coin;
        use action_queue_tokenomics::cookie_token::COOKIE_TOKEN;
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 10_000_000_000);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}

#[test]
fun test_faucet_rate_limiting_allows_max_claims() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        cookie_token::init_for_testing(ctx);
    };

    // Claim 3 times (the max per epoch) — all should succeed
    let mut i = 0u64;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let mut clk = clock::create_for_testing(ctx);
            // All in the same epoch (day 0)
            clock::set_for_testing(&mut clk, i * 1000 + 1);
            cookie_token::claim_faucet(&mut faucet, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = cookie_token::EFaucetLimitReached)]
fun test_faucet_rate_limiting_blocks_over_max() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        cookie_token::init_for_testing(ctx);
    };

    // Claim 3 times successfully
    let mut i = 0u64;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let mut clk = clock::create_for_testing(ctx);
            clock::set_for_testing(&mut clk, i * 1000 + 1);
            cookie_token::claim_faucet(&mut faucet, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // 4th claim in same epoch must fail
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 4000);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_faucet_resets_on_new_epoch() {
    let mut scenario = ts::begin(ADMIN);

    {
        let ctx = ts::ctx(&mut scenario);
        cookie_token::init_for_testing(ctx);
    };

    // Claim 3 times in epoch 0
    let mut i = 0u64;
    while (i < 3) {
        ts::next_tx(&mut scenario, USER);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            let mut clk = clock::create_for_testing(ctx);
            clock::set_for_testing(&mut clk, i * 1000 + 1);
            cookie_token::claim_faucet(&mut faucet, &clk, ctx);
            clock::destroy_for_testing(clk);
            ts::return_shared(faucet);
        };
        i = i + 1;
    };

    // Claim once in epoch 1 — should succeed (reset)
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        // Move to next day (epoch 1)
        clock::set_for_testing(&mut clk, MS_PER_DAY + 1);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}
