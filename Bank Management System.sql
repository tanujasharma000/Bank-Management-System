-- ==========================================================
-- PostgreSQL Banking Management System
-------------------------------------------------------------
-- Required Extension
-------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-------------------------------------------------------------
-- Drop Old Objects
-------------------------------------------------------------

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

-------------------------------------------------------------
-- Accounts Table
-------------------------------------------------------------

CREATE TABLE accounts
(
    account_id BIGSERIAL PRIMARY KEY,

    account_number VARCHAR(20)
        UNIQUE
        NOT NULL,

    account_holder VARCHAR(100)
        NOT NULL,

    email VARCHAR(150),

    phone VARCHAR(20),

    balance NUMERIC(15,2)
        NOT NULL
        DEFAULT 0
        CHECK(balance>=0),

    status VARCHAR(20)
        NOT NULL
        DEFAULT 'ACTIVE'
        CHECK(status IN
        (
            'ACTIVE',
            'BLOCKED',
            'CLOSED'
        )),

    created_at TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP
);

-------------------------------------------------------------
-- Transactions Table
-------------------------------------------------------------

CREATE TABLE transactions
(
    txn_id BIGSERIAL PRIMARY KEY,

    txn_reference UUID
        UNIQUE
        NOT NULL
        DEFAULT gen_random_uuid(),

    from_account BIGINT
        REFERENCES accounts(account_id),

    to_account BIGINT
        REFERENCES accounts(account_id),

    amount NUMERIC(15,2)
        NOT NULL
        CHECK(amount>0),

    transaction_type VARCHAR(20)
        DEFAULT 'TRANSFER'
        CHECK(transaction_type IN
        (
            'TRANSFER',
            'DEPOSIT',
            'WITHDRAW'
        )),

    status VARCHAR(20)
        DEFAULT 'PENDING'
        CHECK(status IN
        (
            'PENDING',
            'SUCCESS',
            'FAILED'
        )),

    remarks TEXT,

    created_at TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP
);

-------------------------------------------------------------
-- Audit Log
-------------------------------------------------------------

CREATE TABLE audit_log
(
    audit_id BIGSERIAL PRIMARY KEY,

    table_name VARCHAR(100),

    operation VARCHAR(20),

    record_id BIGINT,

    old_data JSONB,

    new_data JSONB,

    changed_by TEXT
        DEFAULT CURRENT_USER,

    changed_at TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP
);

-------------------------------------------------------------
-- Useful Indexes
-------------------------------------------------------------

CREATE INDEX idx_account_number
ON accounts(account_number);

CREATE INDEX idx_account_status
ON accounts(status);

CREATE INDEX idx_transaction_reference
ON transactions(txn_reference);

CREATE INDEX idx_transaction_sender
ON transactions(from_account);

CREATE INDEX idx_transaction_receiver
ON transactions(to_account);

CREATE INDEX idx_transaction_time
ON transactions(created_at);

CREATE INDEX idx_transaction_status
ON transactions(status);

CREATE INDEX idx_audit_time
ON audit_log(changed_at);

CREATE INDEX idx_audit_table
ON audit_log(table_name);

-------------------------------------------------------------
-- Sample Accounts
-------------------------------------------------------------

INSERT INTO accounts
(
account_number,
account_holder,
email,
phone,
balance
)

VALUES

('ACC1001',
'Rahul Sharma',
'rahul@gmail.com',
'9876543210',
10000),

('ACC1002',
'Priya Verma',
'priya@gmail.com',
'9876543211',
5000),

('ACC1003',
'Amit Singh',
'amit@gmail.com',
'9876543212',
7000),

('ACC1004',
'Neha Kapoor',
'neha@gmail.com',
'9876543213',
3000);

-------------------------------------------------------------
-- Verify Data
-------------------------------------------------------------

SELECT *
FROM accounts;

-- ==========================================================
-- PART 2
-- Helper Functions + Money Transfer
-- ==========================================================

-------------------------------------------------------------
-- Get Account ID using Account Number
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_account_id
(
    p_account_number VARCHAR
)

RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE
    v_id BIGINT;
BEGIN

    SELECT account_id
    INTO v_id
    FROM accounts
    WHERE account_number=p_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION
        'Account % does not exist.',
        p_account_number;
    END IF;

    RETURN v_id;

END;
$$;

-------------------------------------------------------------
-- Get Current Balance
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_balance
(
    p_account_number VARCHAR
)

RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_balance NUMERIC;

BEGIN

    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_number=p_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION
        'Account % does not exist.',
        p_account_number;
    END IF;

    RETURN v_balance;

END;
$$;

-------------------------------------------------------------
-- Money Transfer Function
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION transfer_money
(
    p_from_account VARCHAR,
    p_to_account VARCHAR,
    p_amount NUMERIC,
    p_reference UUID DEFAULT gen_random_uuid(),
    p_remarks TEXT DEFAULT NULL
)

RETURNS UUID

LANGUAGE plpgsql

AS
$$

DECLARE

    v_from_id BIGINT;
    v_to_id BIGINT;

    v_sender_balance NUMERIC;

BEGIN

-------------------------------------------------------------
-- Basic Validation
-------------------------------------------------------------

    IF p_amount<=0 THEN

        RAISE EXCEPTION
        'Transfer amount must be greater than zero.';

    END IF;

-------------------------------------------------------------
-- Same Account Check
-------------------------------------------------------------

    IF p_from_account=p_to_account THEN

        RAISE EXCEPTION
        'Source and destination account cannot be same.';

    END IF;

-------------------------------------------------------------
-- Duplicate Transaction Check
-------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM transactions
        WHERE txn_reference=p_reference
    )

    THEN

        RAISE EXCEPTION
        'Duplicate Transaction Reference.';

    END IF;

-------------------------------------------------------------
-- Get Account IDs
-------------------------------------------------------------

    v_from_id:=get_account_id(p_from_account);

    v_to_id:=get_account_id(p_to_account);

-------------------------------------------------------------
-- Lock Accounts
-------------------------------------------------------------

    IF v_from_id<v_to_id THEN

        PERFORM 1
        FROM accounts
        WHERE account_id=v_from_id
        FOR UPDATE;

        PERFORM 1
        FROM accounts
        WHERE account_id=v_to_id
        FOR UPDATE;

    ELSE

        PERFORM 1
        FROM accounts
        WHERE account_id=v_to_id
        FOR UPDATE;

        PERFORM 1
        FROM accounts
        WHERE account_id=v_from_id
        FOR UPDATE;

    END IF;

-------------------------------------------------------------
-- Check Sender Status
-------------------------------------------------------------

    IF
    (
        SELECT status
        FROM accounts
        WHERE account_id=v_from_id
    )<>'ACTIVE'
    THEN

        RAISE EXCEPTION
        'Sender account is not active.';

    END IF;

-------------------------------------------------------------
-- Check Receiver Status
-------------------------------------------------------------

    IF
    (
        SELECT status
        FROM accounts
        WHERE account_id=v_to_id
    )<>'ACTIVE'
    THEN

        RAISE EXCEPTION
        'Receiver account is not active.';

    END IF;

-------------------------------------------------------------
-- Balance Check
-------------------------------------------------------------

    SELECT balance

    INTO v_sender_balance

    FROM accounts

    WHERE account_id=v_from_id;

    IF v_sender_balance<p_amount THEN

        RAISE EXCEPTION

        'Insufficient Balance. Available = % Requested = %',

        v_sender_balance,

        p_amount;

    END IF;

-------------------------------------------------------------
-- Debit Sender
-------------------------------------------------------------

    UPDATE accounts

    SET

        balance=balance-p_amount,

        updated_at=NOW()

    WHERE account_id=v_from_id;

-------------------------------------------------------------
-- Credit Receiver
-------------------------------------------------------------

    UPDATE accounts

    SET

        balance=balance+p_amount,

        updated_at=NOW()

    WHERE account_id=v_to_id;

-------------------------------------------------------------
-- Insert Transaction
-------------------------------------------------------------

    INSERT INTO transactions
    (
        txn_reference,
        from_account,
        to_account,
        amount,
        transaction_type,
        status,
        remarks
    )

    VALUES
    (
        p_reference,
        v_from_id,
        v_to_id,
        p_amount,
        'TRANSFER',
        'SUCCESS',
        p_remarks
    );

-------------------------------------------------------------
-- Return UUID
-------------------------------------------------------------

    RETURN p_reference;

END;

$$;

-- ==========================================================
-- PART 3
-- Triggers + Retry Logic
-- ==========================================================

-------------------------------------------------------------
-- Auto Updated_at Trigger
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_timestamp()

RETURNS TRIGGER

LANGUAGE plpgsql

AS
$$

BEGIN

NEW.updated_at:=NOW();

RETURN NEW;

END;

$$;

-------------------------------------------------------------
-- Accounts Trigger
-------------------------------------------------------------

CREATE TRIGGER trg_accounts_timestamp

BEFORE UPDATE

ON accounts

FOR EACH ROW

EXECUTE FUNCTION update_timestamp();

-------------------------------------------------------------
-- Transactions Trigger
-------------------------------------------------------------

CREATE TRIGGER trg_transactions_timestamp

BEFORE UPDATE

ON transactions

FOR EACH ROW

EXECUTE FUNCTION update_timestamp();

-------------------------------------------------------------
-- Audit Trigger Function
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit_trigger_function()

RETURNS TRIGGER

LANGUAGE plpgsql

AS
$$

BEGIN

IF TG_OP='INSERT' THEN

INSERT INTO audit_log
(
table_name,
operation,
record_id,
old_data,
new_data
)

VALUES
(
TG_TABLE_NAME,
TG_OP,
NEW.account_id,
NULL,
row_to_json(NEW)
);

RETURN NEW;

ELSIF TG_OP='UPDATE' THEN

INSERT INTO audit_log
(
table_name,
operation,
record_id,
old_data,
new_data
)

VALUES
(
TG_TABLE_NAME,
TG_OP,
NEW.account_id,
row_to_json(OLD),
row_to_json(NEW)
);

RETURN NEW;

ELSIF TG_OP='DELETE' THEN

INSERT INTO audit_log
(
table_name,
operation,
record_id,
old_data,
new_data
)

VALUES
(
TG_TABLE_NAME,
TG_OP,
OLD.account_id,
row_to_json(OLD),
NULL
);

RETURN OLD;

END IF;

RETURN NULL;

END;

$$;

-------------------------------------------------------------
-- Audit Trigger
-------------------------------------------------------------

CREATE TRIGGER trg_accounts_audit

AFTER INSERT OR UPDATE OR DELETE

ON accounts

FOR EACH ROW

EXECUTE FUNCTION audit_trigger_function();

-------------------------------------------------------------
-- Transfer Retry
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION transfer_with_retry
(
p_from_account VARCHAR,
p_to_account VARCHAR,
p_amount NUMERIC,
p_reference UUID DEFAULT gen_random_uuid(),
p_remarks TEXT DEFAULT NULL,
p_max_retry INT DEFAULT 3
)

RETURNS UUID

LANGUAGE plpgsql

AS
$$

DECLARE

v_attempt INT:=1;

v_result UUID;

BEGIN

LOOP

BEGIN

v_result:=transfer_money
(
p_from_account,
p_to_account,
p_amount,
p_reference,
p_remarks
);

RETURN v_result;

EXCEPTION

WHEN SQLSTATE '40P01'
OR SQLSTATE '40001'

THEN

IF v_attempt>=p_max_retry THEN

RAISE;

END IF;

v_attempt:=v_attempt+1;

PERFORM pg_sleep
(
0.2+random()*0.4
);

END;

END LOOP;

END;

$$;

-------------------------------------------------------------
-- Transaction History
-------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_transaction_history
(
p_account VARCHAR
)

RETURNS TABLE
(
txn_reference UUID,
sender VARCHAR,
receiver VARCHAR,
amount NUMERIC,
status VARCHAR,
remarks TEXT,
txn_time TIMESTAMP
)

LANGUAGE plpgsql

AS
$$

BEGIN

RETURN QUERY

SELECT

t.txn_reference,

a1.account_number,

a2.account_number,

t.amount,

t.status,

t.remarks,

t.created_at

FROM transactions t

JOIN accounts a1

ON t.from_account=a1.account_id

JOIN accounts a2

ON t.to_account=a2.account_id

WHERE

a1.account_number=p_account

OR

a2.account_number=p_account

ORDER BY t.created_at DESC;

END;

$$;

-------------------------------------------------------------
-- Account Summary View
-------------------------------------------------------------

CREATE OR REPLACE VIEW account_summary AS

SELECT

account_number,

account_holder,

balance,

status,

created_at

FROM accounts;

-------------------------------------------------------------
-- Successful Transactions View
-------------------------------------------------------------

CREATE OR REPLACE VIEW successful_transactions AS

SELECT

txn_reference,

from_account,

to_account,

amount,

created_at

FROM transactions

WHERE status='SUCCESS';

-------------------------------------------------------------
-- Total Money in Bank
-------------------------------------------------------------

CREATE OR REPLACE VIEW bank_statistics AS

SELECT

COUNT(*) AS total_accounts,

SUM(balance) AS total_money,

AVG(balance) AS average_balance,

MAX(balance) AS highest_balance,

MIN(balance) AS lowest_balance

FROM accounts;

-------------------------------------------------------------
-- Testing
-------------------------------------------------------------

-- Check Accounts

SELECT * FROM accounts;

-------------------------------------------------------------

-- Check Balance

SELECT get_balance('ACC1001');

-------------------------------------------------------------

-- Money Transfer

SELECT transfer_money(

'ACC1001',

'ACC1002',

1000,

gen_random_uuid(),

'Salary Transfer'

);

-------------------------------------------------------------

SELECT * FROM accounts;

-------------------------------------------------------------

SELECT * FROM transactions;

-------------------------------------------------------------

SELECT *

FROM get_transaction_history('ACC1001');

-------------------------------------------------------------

SELECT *

FROM audit_log;

-------------------------------------------------------------

SELECT *

FROM account_summary;

-------------------------------------------------------------

SELECT *

FROM successful_transactions;

-------------------------------------------------------------

SELECT *

FROM bank_statistics;

-------------------------------------------------------------
-- Performance Test
-------------------------------------------------------------

EXPLAIN ANALYZE

SELECT *

FROM transactions

WHERE txn_reference=

(
SELECT txn_reference

FROM transactions

LIMIT 1
);

-------------------------------------------------------------
-- Deadlock Retry Demo
-------------------------------------------------------------

SELECT transfer_with_retry(

'ACC1002',

'ACC1003',

250,

gen_random_uuid(),

'Retry Test'

);

-------------------------------------------------------------
-- End of Project
-------------------------------------------------------------
