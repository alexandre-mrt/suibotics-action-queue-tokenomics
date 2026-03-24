import type { SuiClient } from "@mysten/sui/client";
import type { Keypair } from "@mysten/sui/cryptography";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ActionQueueClient } from "../src/client.js";
import { CookieClient } from "../src/cookie-client.js";
import { ACTION_TYPES } from "../src/types.js";

// ─── Mock helpers ──────────────────────────────────────────────────────────

const MOCK_PACKAGE_ID = "0xabc123";
const MOCK_QUEUE_ID = "0xqueue456";
const MOCK_FAUCET_ID = "0xfaucet789";
const MOCK_DIGEST = "CKnmh5X9RYMn1QqxFdnhBkH3LQ29Ps5dDw5y4SZBvNqR";

function createMockSuiClient(overrides: Partial<SuiClient> = {}): SuiClient {
	return {
		signAndExecuteTransaction: vi.fn().mockResolvedValue({
			digest: MOCK_DIGEST,
			effects: { status: { status: "success" } },
		}),
		getObject: vi.fn().mockResolvedValue({
			data: {
				content: {
					dataType: "moveObject",
					fields: {
						actions: [],
						history: [],
						action_count: "0",
					},
				},
			},
		}),
		getCoins: vi.fn().mockResolvedValue({
			data: [{ balance: "10000000000" }, { balance: "5000000000" }],
		}),
		...overrides,
	} as unknown as SuiClient;
}

function createMockKeypair(): Keypair {
	return {
		toSuiAddress: vi.fn().mockReturnValue("0xsender"),
		sign: vi.fn(),
		getPublicKey: vi.fn(),
		signTransaction: vi.fn(),
		signPersonalMessage: vi.fn(),
	} as unknown as Keypair;
}

// ─── ActionQueueClient tests ───────────────────────────────────────────────

describe("ActionQueueClient", () => {
	let client: ActionQueueClient;
	let mockSui: SuiClient;
	let mockSigner: Keypair;

	beforeEach(() => {
		mockSui = createMockSuiClient();
		mockSigner = createMockKeypair();
		client = new ActionQueueClient(mockSui, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);
	});

	describe("enqueueAction", () => {
		it("should build and submit an enqueue transaction", async () => {
			const result = await client.enqueueAction(mockSigner, {
				actionType: ACTION_TYPES.WALK,
				params: [1, 0],
				cookieCoinId: "0xcookie_coin_id",
			});

			expect(result.success).toBe(true);
			expect(result.data?.digest).toBe(MOCK_DIGEST);
			expect(mockSui.signAndExecuteTransaction).toHaveBeenCalledOnce();
		});

		it("should return error when transaction fails", async () => {
			const failingSui = createMockSuiClient({
				signAndExecuteTransaction: vi.fn().mockResolvedValue({
					digest: MOCK_DIGEST,
					effects: { status: { status: "failure", error: "Insufficient payment" } },
				}) as SuiClient["signAndExecuteTransaction"],
			});
			const failingClient = new ActionQueueClient(failingSui, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);

			const result = await failingClient.enqueueAction(mockSigner, {
				actionType: ACTION_TYPES.WAVE,
				params: [],
				cookieCoinId: "0xcookie_coin_id",
			});

			expect(result.success).toBe(false);
			expect(result.error).toContain("Insufficient payment");
		});

		it("should handle network errors gracefully", async () => {
			const errorSui = createMockSuiClient({
				signAndExecuteTransaction: vi
					.fn()
					.mockRejectedValue(
						new Error("Network timeout"),
					) as SuiClient["signAndExecuteTransaction"],
			});
			const errorClient = new ActionQueueClient(errorSui, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);

			const result = await errorClient.enqueueAction(mockSigner, {
				actionType: ACTION_TYPES.SIT,
				params: [],
				cookieCoinId: "0xcookie_coin_id",
			});

			expect(result.success).toBe(false);
			expect(result.error).toContain("Network timeout");
		});

		it("should accept all valid action types", async () => {
			for (const actionType of Object.values(ACTION_TYPES)) {
				const result = await client.enqueueAction(mockSigner, {
					actionType,
					params: [],
					cookieCoinId: "0xcoin",
				});
				expect(result.success).toBe(true);
			}
		});
	});

	describe("dequeueAction", () => {
		it("should build and submit a dequeue transaction", async () => {
			const result = await client.dequeueAction(mockSigner, {
				adminCapId: "0xadmin_cap",
			});

			expect(result.success).toBe(true);
			expect(result.data?.digest).toBe(MOCK_DIGEST);
			expect(mockSui.signAndExecuteTransaction).toHaveBeenCalledOnce();
		});

		it("should return error on dequeue failure", async () => {
			const failingSui = createMockSuiClient({
				signAndExecuteTransaction: vi.fn().mockResolvedValue({
					digest: MOCK_DIGEST,
					effects: { status: { status: "failure", error: "Empty queue" } },
				}) as SuiClient["signAndExecuteTransaction"],
			});
			const failingClient = new ActionQueueClient(failingSui, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);

			const result = await failingClient.dequeueAction(mockSigner, {
				adminCapId: "0xadmin_cap",
			});

			expect(result.success).toBe(false);
			expect(result.error).toContain("Empty queue");
		});
	});

	describe("getQueueLength", () => {
		it("should return 0 for empty queue", async () => {
			const result = await client.getQueueLength();

			expect(result.success).toBe(true);
			expect(result.data).toBe(0);
		});

		it("should return the correct length when queue has items", async () => {
			const suiWithItems = createMockSuiClient({
				getObject: vi.fn().mockResolvedValue({
					data: {
						content: {
							dataType: "moveObject",
							fields: {
								actions: [
									{ id: "0", action_type: 0, params: [], creator: "0xA", created_at: "1" },
									{ id: "1", action_type: 1, params: [], creator: "0xB", created_at: "2" },
								],
								history: [],
								action_count: "2",
							},
						},
					},
				}) as SuiClient["getObject"],
			});
			const clientWithItems = new ActionQueueClient(suiWithItems, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);

			const result = await clientWithItems.getQueueLength();

			expect(result.success).toBe(true);
			expect(result.data).toBe(2);
		});

		it("should return error when object is not found", async () => {
			const missingSui = createMockSuiClient({
				getObject: vi.fn().mockResolvedValue({
					data: null,
				}) as SuiClient["getObject"],
			});
			const missingClient = new ActionQueueClient(missingSui, MOCK_PACKAGE_ID, MOCK_QUEUE_ID);

			const result = await missingClient.getQueueLength();

			expect(result.success).toBe(false);
		});
	});

	describe("getHistory", () => {
		it("should return empty array when no history", async () => {
			const result = await client.getHistory();

			expect(result.success).toBe(true);
			expect(result.data).toEqual([]);
		});

		it("should parse history records correctly", async () => {
			const suiWithHistory = createMockSuiClient({
				getObject: vi.fn().mockResolvedValue({
					data: {
						content: {
							dataType: "moveObject",
							fields: {
								actions: [],
								history: [
									{
										id: "0",
										action_type: "2",
										params: [],
										creator: "0xCreator",
										created_at: "1000",
										executed_at: "2000",
									},
								],
								action_count: "1",
							},
						},
					},
				}) as SuiClient["getObject"],
			});
			const clientWithHistory = new ActionQueueClient(
				suiWithHistory,
				MOCK_PACKAGE_ID,
				MOCK_QUEUE_ID,
			);

			const result = await clientWithHistory.getHistory();

			expect(result.success).toBe(true);
			expect(result.data).toHaveLength(1);
			expect(result.data?.[0].actionType).toBe(2);
			expect(result.data?.[0].createdAt).toBe(1000n);
			expect(result.data?.[0].executedAt).toBe(2000n);
		});
	});
});

// ─── CookieClient tests ────────────────────────────────────────────────────

describe("CookieClient", () => {
	let cookieClient: CookieClient;
	let mockSui: SuiClient;
	let mockSigner: Keypair;

	beforeEach(() => {
		mockSui = createMockSuiClient();
		mockSigner = createMockKeypair();
		cookieClient = new CookieClient(mockSui, MOCK_PACKAGE_ID);
	});

	describe("claimFaucet", () => {
		it("should build and submit a claim transaction", async () => {
			const result = await cookieClient.claimFaucet(mockSigner, MOCK_FAUCET_ID);

			expect(result.success).toBe(true);
			expect(result.data?.digest).toBe(MOCK_DIGEST);
			expect(mockSui.signAndExecuteTransaction).toHaveBeenCalledOnce();
		});

		it("should return error when claim fails", async () => {
			const failingSui = createMockSuiClient({
				signAndExecuteTransaction: vi.fn().mockResolvedValue({
					digest: MOCK_DIGEST,
					effects: { status: { status: "failure", error: "Rate limit reached" } },
				}) as SuiClient["signAndExecuteTransaction"],
			});
			const failingClient = new CookieClient(failingSui, MOCK_PACKAGE_ID);

			const result = await failingClient.claimFaucet(mockSigner, MOCK_FAUCET_ID);

			expect(result.success).toBe(false);
			expect(result.error).toContain("Rate limit reached");
		});
	});

	describe("getBalance", () => {
		it("should sum all coin balances for the address", async () => {
			const result = await cookieClient.getBalance("0xsomeaddress");

			expect(result.success).toBe(true);
			// 10_000_000_000 + 5_000_000_000
			expect(result.data).toBe(15_000_000_000n);
		});

		it("should return 0 for address with no coins", async () => {
			const emptySui = createMockSuiClient({
				getCoins: vi.fn().mockResolvedValue({ data: [] }) as SuiClient["getCoins"],
			});
			const emptyClient = new CookieClient(emptySui, MOCK_PACKAGE_ID);

			const result = await emptyClient.getBalance("0xempty");

			expect(result.success).toBe(true);
			expect(result.data).toBe(0n);
		});
	});

	describe("getFormattedBalance", () => {
		it("should format balance correctly with 9 decimals", async () => {
			const result = await cookieClient.getFormattedBalance("0xsomeaddress");

			expect(result.success).toBe(true);
			// 15_000_000_000 / 1e9 = 15.000000000
			expect(result.data).toBe("15.000000000");
		});

		it("should format fractional amounts correctly", async () => {
			const fractionalSui = createMockSuiClient({
				getCoins: vi.fn().mockResolvedValue({
					data: [{ balance: "1500000000" }],
				}) as SuiClient["getCoins"],
			});
			const fractionalClient = new CookieClient(fractionalSui, MOCK_PACKAGE_ID);

			const result = await fractionalClient.getFormattedBalance("0xaddr");

			expect(result.success).toBe(true);
			// 1_500_000_000 / 1e9 = 1.500000000
			expect(result.data).toBe("1.500000000");
		});
	});
});

// ─── ACTION_TYPES constant tests ───────────────────────────────────────────

describe("ACTION_TYPES", () => {
	it("should have correct numeric values matching Move constants", () => {
		expect(ACTION_TYPES.WALK).toBe(0);
		expect(ACTION_TYPES.TURN).toBe(1);
		expect(ACTION_TYPES.SIT).toBe(2);
		expect(ACTION_TYPES.STAND).toBe(3);
		expect(ACTION_TYPES.WAVE).toBe(4);
	});
});
