# Savings Account Smart Contract 💰  

**Description:**  
Welcome to the Savings Account Smart Contract! This is a decentralized application that allows users to securely deposit and withdraw digital assets while keeping track of their balances. It operates on the blockchain, ensuring transparency and security for all users. Whether you’re looking to save for the future or manage your funds more effectively, this contract has got you covered!  

---

## Features 🚀  

- **Deposit Funds:**  
  Users can deposit funds into their savings account. The contract will ensure that only positive amounts can be deposited.  

- **Withdraw Funds:**  
  Withdraw funds at any time, as long as there are sufficient funds in your account. No overdrafts here—just straightforward transactions.  

- **Balance Check:**  
  Retrieve the current balance of any account, providing complete visibility into your savings.  

---

## Functions 📜  

### Public Functions  

#### `deposit`  
**Parameters:**  
- `amount (uint)`: The amount to be deposited into the user's savings account.  

**Behavior:**  
- Ensures that the deposit amount is greater than zero.  
- Adds the deposit amount to the user's balance.  

**Returns:**  
- `ok true`: If the deposit was successful.  
- `err u101`: If the deposit amount is zero or negative.  

---

#### `withdraw`  
**Parameters:**  
- `amount (uint)`: The amount to withdraw from the savings account.  

**Behavior:**  
- Ensures that the withdrawal amount is greater than zero.  
- Checks if the user has sufficient funds to make the withdrawal.  
- Deducts the withdrawal amount from the user’s balance if successful.  

**Returns:**  
- `ok true`: If the withdrawal was successful.  
- `err u100`: If the user has insufficient funds for the requested withdrawal.  
- `err u101`: If the withdrawal amount is zero or negative.  

---

#### `get-balance`  
**Parameters:**  
- `user (principal)`: The principal address of the user whose balance is being checked.  

**Returns:**  
- `uint`: The current balance of the specified user. If the user has no balance, the function returns `0`.  

---

## Unit Tests 🧪  

Unit tests have been implemented to validate all contract functionalities and edge cases. Below are the tests performed:

### Deposit and Withdrawal Tests  

1. **Deposit Funds:**  
   - Users can deposit funds into their savings account. The contract ensures the deposit amount is positive and updates the balance correctly.  

2. **Withdraw Funds (Sufficient Balance):**  
   - Users can withdraw funds as long as they have a sufficient balance. The balance is updated accordingly after the withdrawal.  

3. **Withdraw Funds (Insufficient Balance):**  
   - The contract prevents users from withdrawing more funds than they have in their account, maintaining security and trust.  

4. **Balance Retrieval:**  
   - Users can check their balance at any time, and the system ensures it reflects their current deposits and withdrawals.  

5. **Edge Case - Zero or Negative Amounts:**  
   - Both deposits and withdrawals are validated to ensure no zero or negative amounts are processed, maintaining correct account management.  

---

## Example Usage 📝  

### Deposit Funds  
```clarity
(deposit 100)
```  

### Withdraw Funds  
```clarity
(withdraw 50)
```  

### Check Balance  
```clarity
(get-balance tx-sender)
```  

---

## Deployment 🚀  

To deploy the contract:
1. Deploy the `Savings Account` contract to your desired blockchain network.  
2. Ensure all users can interact with the contract through their wallet interfaces.  
3. Run the provided unit tests to confirm everything is working smoothly.  

---

## Contributing 🤝  

We welcome contributions! Fork this repository, make your changes, and submit a pull request. If you have ideas for new features or improvements, feel free to open an issue or discuss it with us.  

---

## License 📄  

This project is open-source under the MIT License.  