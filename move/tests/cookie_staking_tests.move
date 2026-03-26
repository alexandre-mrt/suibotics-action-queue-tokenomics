#[test_only]
module action_queue_tokenomics::cookie_staking_tests;

use action_queue_tokenomics::cookie_staking::{Self, StakePool, StakePosition};
use action_queue_tokenomics::cookie_token::{Self, FaucetState, COOKIE_TOKEN};
use sui::clock;
use sui::coin::Coin;
use sui::test_scenario::{Self as ts};

const ADMIN: address = @0xAD;
const USER: address = @0xB0;
const USER2: address = @0xC1;

// ─── Tests ─────────────────────────────────────────────────────────────────

#[test]
fun test_stake_success() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 5_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 5_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // Verify StakePosition was transferred to USER
    ts::next_tx(&mut scenario, USER);
    {
        let position = ts::take_from_sender<StakePosition>(&scenario);
        assert!(cookie_staking::get_stake_amount(&position) == 5_000_000_000);
        ts::return_to_sender(&scenario, position);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = cookie_staking::EZeroAmount)]
fun test_stake_zero_fails() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 0, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_unstake_success() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    // Stake
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 3_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // Unstake
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let position = ts::take_from_sender<StakePosition>(&scenario);
        cookie_staking::unstake(&mut pool, position, ts::ctx(&mut scenario));
        assert!(cookie_staking::get_total_staked(&pool) == 0);
        ts::return_shared(pool);
    };

    // Verify tokens returned
    ts::next_tx(&mut scenario, USER);
    {
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 3_000_000_000);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}

#[test]
fun test_get_stake_amount() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 7_500_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let position = ts::take_from_sender<StakePosition>(&scenario);
        assert!(cookie_staking::get_stake_amount(&position) == 7_500_000_000);
        ts::return_to_sender(&scenario, position);
    };

    ts::end(scenario);
}

#[test]
fun test_get_total_staked() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 2_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 2_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 2_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 3_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 5_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    ts::end(scenario);
}

#[test]
fun test_multiple_stakers() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    // USER stakes
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 4_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 4_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // USER2 stakes
    ts::next_tx(&mut scenario, USER2);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 2_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 6_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 10_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // Verify both positions
    ts::next_tx(&mut scenario, USER);
    {
        let position = ts::take_from_sender<StakePosition>(&scenario);
        assert!(cookie_staking::get_stake_amount(&position) == 4_000_000_000);
        ts::return_to_sender(&scenario, position);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let position = ts::take_from_sender<StakePosition>(&scenario);
        assert!(cookie_staking::get_stake_amount(&position) == 6_000_000_000);
        ts::return_to_sender(&scenario, position);
    };

    ts::end(scenario);
}

#[test]
fun test_stake_and_unstake_full_cycle() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    // Stake
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 10_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 10_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // Verify position exists
    ts::next_tx(&mut scenario, USER);
    {
        let position = ts::take_from_sender<StakePosition>(&scenario);
        assert!(cookie_staking::get_stake_amount(&position) == 10_000_000_000);
        ts::return_to_sender(&scenario, position);
    };

    // Unstake
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let position = ts::take_from_sender<StakePosition>(&scenario);
        cookie_staking::unstake(&mut pool, position, ts::ctx(&mut scenario));
        assert!(cookie_staking::get_total_staked(&pool) == 0);
        ts::return_shared(pool);
    };

    // Verify tokens returned
    ts::next_tx(&mut scenario, USER);
    {
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 10_000_000_000);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}

#[test]
fun test_unstake_returns_tokens() {
    let mut scenario = ts::begin(ADMIN);
    {
        let ctx = ts::ctx(&mut scenario);
        cookie_staking::init_for_testing(ctx);
        cookie_token::init_for_testing(ctx);
    };

    // USER and USER2 both stake
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 1_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 5_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let mut faucet = ts::take_shared<FaucetState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        let mut clk = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clk, 2_000);
        let payment = cookie_token::mint_for_testing(&mut faucet, 8_000_000_000, ctx);
        cookie_staking::stake(&mut pool, payment, &clk, ctx);
        assert!(cookie_staking::get_total_staked(&pool) == 13_000_000_000);
        clock::destroy_for_testing(clk);
        ts::return_shared(pool);
        ts::return_shared(faucet);
    };

    // USER unstakes
    ts::next_tx(&mut scenario, USER);
    {
        let mut pool = ts::take_shared<StakePool>(&scenario);
        let position = ts::take_from_sender<StakePosition>(&scenario);
        cookie_staking::unstake(&mut pool, position, ts::ctx(&mut scenario));
        // Only USER2's stake remains
        assert!(cookie_staking::get_total_staked(&pool) == 8_000_000_000);
        ts::return_shared(pool);
    };

    // Verify USER got exactly their tokens back
    ts::next_tx(&mut scenario, USER);
    {
        let coin = ts::take_from_sender<Coin<COOKIE_TOKEN>>(&scenario);
        assert!(coin.value() == 5_000_000_000);
        ts::return_to_sender(&scenario, coin);
    };

    ts::end(scenario);
}
