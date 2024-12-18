import { describe, it, beforeEach, expect } from 'vitest';

const mockSavingsAccount = {
  state: {
    balances: {} as Record<string, number>, // Maps users to balances
  },

  deposit: (user: string, amount: number) => {
    if (amount <= 0) return { error: 101 }; // Amount cannot be zero or negative
    const currentBalance = mockSavingsAccount.state.balances[user] || 0;
    mockSavingsAccount.state.balances[user] = currentBalance + amount;
    return { value: true };
  },

  withdraw: (user: string, amount: number) => {
    if (amount <= 0) return { error: 101 }; // Amount cannot be zero or negative
    const currentBalance = mockSavingsAccount.state.balances[user] || 0;
    if (currentBalance >= amount) {
      mockSavingsAccount.state.balances[user] -= amount;
      return { value: true };
    }
    return { error: 100 }; // Insufficient funds
  },

  getBalance: (user: string) => {
    return mockSavingsAccount.state.balances[user] || 0;
  },
};

describe('Savings Account Contract', () => {
  let user1: string, user2: string;

  beforeEach(() => {
    // Reset mock state and initialize user principals
    user1 = 'ST1234...';
    user2 = 'ST5678...';

    mockSavingsAccount.state = {
      balances: {},
    };
  });

  it('should allow a user to deposit STX tokens', () => {
    const result = mockSavingsAccount.deposit(user1, 100);
    expect(result).toEqual({ value: true });
    expect(mockSavingsAccount.state.balances[user1]).toBe(100);
  });

  it('should allow a user to withdraw tokens if they have sufficient balance', () => {
    mockSavingsAccount.deposit(user1, 100);
    const result = mockSavingsAccount.withdraw(user1, 50);
    expect(result).toEqual({ value: true });
    expect(mockSavingsAccount.state.balances[user1]).toBe(50);
  });

  it('should prevent a user from withdrawing more than their balance', () => {
    mockSavingsAccount.deposit(user1, 100);
    const result = mockSavingsAccount.withdraw(user1, 150);
    expect(result).toEqual({ error: 100 });
    expect(mockSavingsAccount.state.balances[user1]).toBe(100);
  });

  it('should return the correct balance for a user', () => {
    mockSavingsAccount.deposit(user1, 200);
    const balance = mockSavingsAccount.getBalance(user1);
    expect(balance).toBe(200);
  });

  it('should return zero for a user with no balance', () => {
    const balance = mockSavingsAccount.getBalance(user2);
    expect(balance).toBe(0);
  });
});
