/**
 * CookieClient — TypeScript SDK for interacting with the cookie_token Move module.
 */

import type { SuiClient } from "@mysten/sui/client";
import type { Keypair } from "@mysten/sui/cryptography";
import { Transaction } from "@mysten/sui/transactions";
import type { ApiResponse, TransactionResult } from "./types.js";

const CLOCK_OBJECT_ID = "0x6";
const COOKIE_TOKEN_DECIMALS = 9;
const COOKIE_TOKEN_DIVISOR = 10 ** COOKIE_TOKEN_DECIMALS;

export class CookieClient {
	private readonly client: SuiClient;
	private readonly packageId: string;

	constructor(client: SuiClient, packageId: string) {
		this.client = client;
		this.packageId = packageId;
	}

	/**
	 * Claim COOKIE tokens from the faucet. Rate-limited per epoch.
	 */
	async claimFaucet(
		signer: Keypair,
		faucetStateId: string,
	): Promise<ApiResponse<TransactionResult>> {
		try {
			const tx = new Transaction();

			tx.moveCall({
				target: `${this.packageId}::cookie_token::claim_faucet`,
				arguments: [tx.object(faucetStateId), tx.object(CLOCK_OBJECT_ID)],
			});

			const result = await this.client.signAndExecuteTransaction({
				signer,
				transaction: tx,
				options: {
					showEffects: true,
				},
			});

			const status = result.effects?.status.status;
			if (status !== "success") {
				return {
					success: false,
					error: result.effects?.status.error ?? "Transaction failed",
				};
			}

			return {
				success: true,
				data: {
					digest: result.digest,
					success: true,
				},
			};
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			return { success: false, error: `claimFaucet failed: ${message}` };
		}
	}

	/**
	 * Get the total COOKIE balance for an address (in base units).
	 */
	async getBalance(address: string): Promise<ApiResponse<bigint>> {
		try {
			const coinType = `${this.packageId}::cookie_token::COOKIE_TOKEN`;
			const coins = await this.client.getCoins({ owner: address, coinType });

			const total = coins.data.reduce((sum, coin) => sum + BigInt(coin.balance), 0n);

			return { success: true, data: total };
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			return { success: false, error: `getBalance failed: ${message}` };
		}
	}

	/**
	 * Get COOKIE balance formatted as a human-readable decimal string.
	 * Example: 10_000_000_000 base units -> "10.000000000"
	 */
	async getFormattedBalance(address: string): Promise<ApiResponse<string>> {
		const result = await this.getBalance(address);
		if (!result.success || result.data === undefined) {
			return { success: false, error: result.error };
		}

		const whole = result.data / BigInt(COOKIE_TOKEN_DIVISOR);
		const fraction = result.data % BigInt(COOKIE_TOKEN_DIVISOR);
		const formatted = `${whole}.${String(fraction).padStart(COOKIE_TOKEN_DECIMALS, "0")}`;

		return { success: true, data: formatted };
	}
}
