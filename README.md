# PostgreSQL Secure Banking Transaction System

A production-inspired Banking Management System built using PostgreSQL that demonstrates transaction processing, concurrency handling, audit logging, retry mechanisms, triggers, views, indexing, and PL/pgSQL programming.

This project is designed to simulate how modern banking systems securely transfer money while maintaining data consistency and integrity.

---

## Features

- Secure Account Management
- Money Transfer Function
- Automatic UUID Transaction Reference
- Transaction History
- Balance Checking
- Audit Logging
- Automatic Timestamp Updates
- Deadlock Prevention
- Retry Mechanism for Failed Transactions
- Row-Level Locking using FOR UPDATE
- Optimized Database Indexes
- Analytical Views
- Performance Testing using EXPLAIN ANALYZE

---

## Technologies Used

- PostgreSQL 
- PL/pgSQL
- pgcrypto Extension
- SQL
- UUID
- JSONB
- Triggers
- Views
- Indexes

---

## Database Structure

### Tables

### Accounts
Stores customer account information.

Columns include:

- Account Number
- Account Holder
- Email
- Phone
- Balance
- Account Status
- Created Time
- Updated Time

---

### Transactions

Stores every money transfer between accounts.

Features:

- UUID Transaction Reference
- Sender Account
- Receiver Account
- Transfer Amount
- Transaction Status
- Remarks
- Timestamp

---

### Audit Log

Maintains complete history of INSERT, UPDATE and DELETE operations.

Stores:

- Table Name
- Operation
- Record ID
- Old Data
- New Data
- User
- Timestamp

---

## Functions

### get_account_id()

Returns Account ID using Account Number.

---

### get_balance()

Returns current account balance.

---

### transfer_money()

Performs secure money transfer with validations.

Includes:

- Balance Validation
- Active Account Validation
- Duplicate Transaction Prevention
- Same Account Check
- Row-Level Locking
- Automatic Transaction Recording

---

### transfer_with_retry()

Automatically retries transaction if deadlock or serialization failure occurs.

---

### get_transaction_history()

Returns complete transaction history for an account.

---

## Triggers

### Timestamp Trigger

Automatically updates `updated_at` whenever a record changes.

---

### Audit Trigger

Automatically records every INSERT, UPDATE and DELETE operation.

---

## Views

### account_summary

Quick overview of all accounts.

---

### successful_transactions

Displays only successful transfers.

---

### bank_statistics

Shows:

- Total Accounts
- Total Money
- Average Balance
- Highest Balance
- Lowest Balance

---

## Performance Optimization

Indexes are created on frequently searched columns including:

- Account Number
- Account Status
- Transaction Reference
- Sender Account
- Receiver Account
- Transaction Time
- Transaction Status
- Audit Timestamp

Performance testing is demonstrated using:

```sql
EXPLAIN ANALYZE
```

---

## Security Features

- UUID Transaction References
- CHECK Constraints
- UNIQUE Constraints
- Foreign Keys
- Row-Level Locking
- Deadlock Prevention
- Retry Logic
- Audit Trail
- Data Validation

---

## Sample Workflow

1. Create Accounts
2. Check Account Balance
3. Transfer Money
4. Record Transaction
5. Update Balances
6. Store Audit Logs
7. View Transaction History
8. Analyze Performance

---

## Folder Structure

```
PostgreSQL-Secure-Banking-Transaction-System/
│
├── banking_system.sql
├── README.md
└── screenshots/
```

---

## Learning Outcomes

This project demonstrates practical implementation of:

- Database Design
- Constraints
- Indexing
- Views
- Triggers
- Stored Functions
- PL/pgSQL
- Transactions
- Concurrency Control
- Deadlock Handling
- Audit Logging
- Performance Optimization

---

## Future Improvements

- User Authentication
- Account Creation Procedure
- Deposit Module
- Withdraw Module
- Monthly Statements
- Role-Based Access Control
- Scheduled Reports
- REST API Integration

---

## Author

**Tanuja Sharma**

BCA Student | SQL | PostgreSQL | Data Analytics

---

## License

This project is intended for learning and educational purposes.
