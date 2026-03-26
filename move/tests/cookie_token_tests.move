#[test_only]
module action_queue_tokenomics::cookie_token_tests;

use action_queue_tokenomics::cookie_token::{Self, FaucetState, COOKIE_TOKEN};
use sui::clock;
use sui::coin::Coin;
use sui::test_scenario::{Self as ts};

const ADMIN: address = @0xAD;
const USER: address = @0xC0;
const USER2: address = @0xC1;

const MS_PER_DAY: u64 = 86_400_000;

// ─── Tests ─────────────────────────────────────────────────────────────────

#[test]
fun test_faucet_claim_transfers_tokens() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

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

    ts::next_tx(&mut scenario, USER);
    {
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 10_000_000_000);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}

#[test]
fun test_faucet_rate_limiting_allows_max_claims() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

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

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = cookie_token::EFaucetLimitReached)]
fun test_faucet_rate_limiting_blocks_over_max() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

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
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

    // Exhaust claims in epoch 0
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

    // Claim in epoch 1 — should succeed
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, MS_PER_DAY + 1);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

// ─── NEW TESTS ─────────────────────────────────────────────────────────────

#[test]
fun test_multiple_users_independent_limits() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

    // USER claims 3 times (max)
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

    // USER2 can still claim (independent limit)
    ts::next_tx(&mut scenario, USER2);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 5000);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    // Verify USER2 got tokens
    ts::next_tx(&mut scenario, USER2);
    {
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 10_000_000_000, 0);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}

#[test]
fun test_get_balance_returns_correct_value() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let coin = cookie_token::mint_for_testing(&mut faucet, 42_000_000_000, ctx);
        assert!(cookie_token::get_balance(&coin) == 42_000_000_000, 0);
        transfer::public_transfer(coin, USER);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_faucet_claim_across_three_epochs() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

    // Claim in epoch 0
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    // Claim in epoch 1
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, MS_PER_DAY + 1);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    // Claim in epoch 2
    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 2 * MS_PER_DAY + 1);
        cookie_token::claim_faucet(&mut faucet, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_mint_for_testing_various_amounts() {
    let mut scenario = ts::begin(ADMIN);
    { cookie_token::init_for_testing(ts::ctx(&mut scenario)); };

    ts::next_tx(&mut scenario, USER);
    {
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);

        // Mint 0
        let zero_coin = cookie_token::mint_for_testing(&mut faucet, 0, ctx);
        assert!(zero_coin.value() == 0, 0);
        sui::coin::destroy_zero(zero_coin);

        // Mint 1
        let one_coin = cookie_token::mint_for_testing(&mut faucet, 1, ctx);
        assert!(one_coin.value() == 1, 1);
        transfer::public_transfer(one_coin, USER);

        // Mint large amount
        let big_coin = cookie_token::mint_for_testing(&mut faucet, 1_000_000_000_000, ctx);
        assert!(big_coin.value() == 1_000_000_000_000, 2);
        transfer::public_transfer(big_coin, USER);

        ts::return_shared(faucet);
    };

    ts::end(scenario);
}
