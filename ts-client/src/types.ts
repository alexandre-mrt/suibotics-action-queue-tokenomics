/**
 * TypeScript interfaces matching the Move structs for action_queue_tokenomics.
 */

// Action type identifiers matching the Move constants
export const ACTION_TYPES = {
	WALK: 0,
	TURN: 1,
	SIT: 2,
	STAND: 3,
	WAVE: 4,
} as const;

export type ActionType = (typeof ACTION_TYPES)[keyof typeof ACTION_TYPES];

export interface Action {
	readonly id: bigint;
	readonly actionType: ActionType;
	readonly params: Uint8Array;
	readonly creator: string;
	readonly createdAt: bigint;
}

export interface ActionRecord extends Action {
	readonly executedAt: bigint;
}

export interface ActionQueueState {
	readonly queueLength: number;
	readonly historyLength: number;
	readonly actionCount: bigint;
}

export interface ClaimRecord {
	readonly epoch: bigint;
	readonly count: bigint;
}

export interface EnqueueParams {
	readonly actionType: ActionType;
	readonly params: number[];
	readonly cookieCoinId: string;
}

export interface DequeueParams {
	readonly adminCapId: string;
}

export interface ApiResponse<T> {
	readonly success: boolean;
	readonly data?: T;
	readonly error?: string;
}

export interface TransactionResult {
	readonly digest: string;
	readonly success: boolean;
	readonly error?: string;
}
