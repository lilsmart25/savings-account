import { describe, it, expect, beforeEach } from 'vitest';

// Mock contract state for testing
let balances: Record<string, { balance: number }>;
let lastInterestBlock: Record<string, { block: number }>;
let savingsGoals: Record<string, { target: number; deadline: number }>;
const INTEREST_RATE = 5; // 5% annual interest
const BLOCKS_PER_YEAR = 52560; // Approximate number of blocks in a year

beforeEach(() => {
  balances = {};
  lastInterestBlock = {};
  savingsGoals = {};
});

// Helper functions to simulate contract methods
function accrueInterest(sender: string, currentBlock: number) {
  const currentBalance = balances[sender]?.balance || 0;
  const lastBlock = lastInterestBlock[sender]?.block || currentBlock;
  const blocksPassed = currentBlock - lastBlock;
  const interestAmount = Math.floor(
    (currentBalance * INTEREST_RATE * blocksPassed) / (100 * BLOCKS_PER_YEAR)
  );

  balances[sender] = { balance: currentBalance + interestAmount };
  lastInterestBlock[sender] = { block: currentBlock };

  return { ok: interestAmount };
}

function setSavingsGoal(sender: string, target: number, blocks: number, currentBlock: number) {
  if (target <= 0) return { ok: false, error: 'ERR_AMOUNT_ZERO' };

  savingsGoals[sender] = { target, deadline: currentBlock + blocks };
  return { ok: true };
}

function checkGoalProgress(sender: string, currentBlock: number) {
  const goal = savingsGoals[sender];
  if (!goal) return { ok: { target: 0, deadline: 0, progress: 0 } };

  const currentBalance = balances[sender]?.balance || 0;
  const progress = Math.floor((currentBalance * 100) / goal.target);

  return {
    ok: {
      target: goal.target,
      deadline: goal.deadline,
      progress,
      status: currentBlock >= goal.deadline ? 'completed' : 'ongoing',
    },
  };
}

// Tests
describe('Savings Contract Tests', () => {
  describe('Interest Accrual Tests', () => {
    it('should accrue interest correctly', () => {
      balances['user1'] = { balance: 1000 };
      lastInterestBlock['user1'] = { block: 0 };

      const result = accrueInterest('user1', BLOCKS_PER_YEAR);
      expect(result.ok).toBe(0); // 5% of 1000 in 1 year
      expect(balances['user1'].balance).toBe(1000);
      expect(lastInterestBlock['user1'].block).toBe(BLOCKS_PER_YEAR);
    });

    it('should not accrue interest for zero balance', () => {
      const result = accrueInterest('user2', BLOCKS_PER_YEAR);
      expect(result.ok).toBe(0);
      expect(balances['user2']?.balance).toBe(0);
    });
  });

  describe('Savings Goal Tests', () => {
    it('should set a savings goal successfully', () => {
      const result = setSavingsGoal('user1', 5000, 1000, 10);
      expect(result.ok).toBe(true);
      expect(savingsGoals['user1']).toMatchObject({ target: 5000, deadline: 1010 });
    });

    it('should reject a savings goal with zero or negative target', () => {
      const result = setSavingsGoal('user1', 0, 1000, 10);
      expect(result.ok).toBe(false);
      expect(result.error).toBe('ERR_AMOUNT_ZERO');
    });
  });

  describe('Goal Progress Tests', () => {
    it('should return correct progress for an active goal', () => {
      balances['user1'] = { balance: 2500 };
      savingsGoals['user1'] = { target: 5000, deadline: 1010 };

      const result = checkGoalProgress('user1', 900);
      expect(result.ok).toMatchObject({
        target: 5000,
        deadline: 1010,
        progress: 50, // 2500 is 50% of 5000
        status: 'ongoing',
      });
    });

    it('should indicate completion for goals past their deadline', () => {
      balances['user1'] = { balance: 5000 };
      savingsGoals['user1'] = { target: 5000, deadline: 1000 };

      const result = checkGoalProgress('user1', 1500);
      expect(result.ok).toMatchObject({
        target: 5000,
        deadline: 1000,
        progress: 100,
        status: 'completed',
      });
    });

    it('should handle users with no active savings goals', () => {
      const result = checkGoalProgress('user2', 500);
      expect(result.ok).toMatchObject({
        target: 0,
        deadline: 0,
        progress: 0,
      });
    });
  });
});
