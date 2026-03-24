/**
 * ActionQueueClient — TypeScript SDK for interacting with the action_queue Move module.
 */

import type { SuiClient } from "@mysten/sui/client";
import type { Keypair } from "@mysten/sui/cryptography";
import { Transaction } from "@mysten/sui/transactions";
import type {
	ActionQueueState,
	ActionRecord,
	ApiResponse,
	DequeueParams,
	EnqueueParams,
	TransactionResult,
} from "./types.js";

// Object IDs required for clock in transactions
const CLOCK_OBJECT_ID = "0x6";

export class ActionQueueClient {
	private readonly client: SuiClient;
	private readonly packageId: string;
	private readonly queueObjectId: string;

	constructor(client: SuiClient, packageId: string, queueObjectId: string) {
		this.client = client;
		this.packageId = packageId;
		this.queueObjectId = queueObjectId;
	}

	/**
	 * Enqueue a robot action. Requires a COOKIE coin object with sufficient balance.
	 */
	async enqueueAction(
		signer: Keypair,
		params: EnqueueParams,
	): Promise<ApiResponse<TransactionResult>> {
		if (params.actionType < 0 || params.actionType > 4) {
			return { success: false, error: "Invalid action type: must be 0-4" };
		}

		try {
			const tx = new Transaction();

			tx.moveCall({
				target: `${this.packageId}::action_queue::enqueue`,
				arguments: [
					tx.object(this.queueObjectId),
					tx.pure.u8(params.actionType),
					tx.pure.vector("u8", params.params),
					tx.object(params.cookieCoinId),
					tx.object(CLOCK_OBJECT_ID),
				],
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
			return { success: false, error: `enqueueAction failed: ${message}` };
		}
	}

	/**
	 * Dequeue the first pending action. Requires AdminCap.
	 */
	async dequeueAction(
		signer: Keypair,
		params: DequeueParams,
	): Promise<ApiResponse<TransactionResult>> {
		try {
			const tx = new Transaction();

			tx.moveCall({
				target: `${this.packageId}::action_queue::dequeue`,
				arguments: [
					tx.object(this.queueObjectId),
					tx.object(params.adminCapId),
					tx.object(CLOCK_OBJECT_ID),
				],
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
			return { success: false, error: `dequeueAction failed: ${message}` };
		}
	}

	/**
	 * Read the current queue length from on-chain state.
	 */
	async getQueueLength(): Promise<ApiResponse<number>> {
		try {
			const obj = await this.client.getObject({
				id: this.queueObjectId,
				options: { showContent: true },
			});

			if (!obj.data?.content || obj.data.content.dataType !== "moveObject") {
				return { success: false, error: "Queue object not found or invalid type" };
			}

			const fields = obj.data.content.fields as Record<string, unknown>;
			const actions = fields.actions;
			const length = Array.isArray(actions) ? actions.length : Number(fields.action_count ?? 0);

			return { success: true, data: length };
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			return { success: false, error: `getQueueLength failed: ${message}` };
		}
	}

	/**
	 * Read completed action history from on-chain state.
	 */
	async getHistory(): Promise<ApiResponse<ActionRecord[]>> {
		try {
			const obj = await this.client.getObject({
				id: this.queueObjectId,
				options: { showContent: true },
			});

			if (!obj.data?.content || obj.data.content.dataType !== "moveObject") {
				return { success: false, error: "Queue object not found or invalid type" };
			}

			const fields = obj.data.content.fields as Record<string, unknown>;
			const rawHistory = fields.history;

			if (!Array.isArray(rawHistory)) {
				return { success: true, data: [] };
			}

			const history: ActionRecord[] = rawHistory.map((item: unknown) => {
				const record = item as Record<string, unknown>;
				return {
					id: BigInt(String(record.id ?? 0)),
					actionType: Number(record.action_type ?? 0) as ActionRecord["actionType"],
					params: new Uint8Array(Array.isArray(record.params) ? (record.params as number[]) : []),
					creator: String(record.creator ?? ""),
					createdAt: BigInt(String(record.created_at ?? 0)),
					executedAt: BigInt(String(record.executed_at ?? 0)),
				};
			});

			return { success: true, data: history };
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			return { success: false, error: `getHistory failed: ${message}` };
		}
	}

	/**
	 * Read the full queue state summary.
	 */
	async getQueueState(): Promise<ApiResponse<ActionQueueState>> {
		try {
			const obj = await this.client.getObject({
				id: this.queueObjectId,
				options: { showContent: true },
			});

			if (!obj.data?.content || obj.data.content.dataType !== "moveObject") {
				return { success: false, error: "Queue object not found or invalid type" };
			}

			const fields = obj.data.content.fields as Record<string, unknown>;
			const actions = fields.actions;
			const history = fields.history;

			return {
				success: true,
				data: {
					queueLength: Array.isArray(actions) ? actions.length : 0,
					historyLength: Array.isArray(history) ? history.length : 0,
					actionCount: BigInt(String(fields.action_count ?? 0)),
				},
			};
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			return { success: false, error: `getQueueState failed: ${message}` };
		}
	}
}
