-- ============================================================
-- PROJECT: Customer Retention, Revenue Leakage & Churn Analysis
-- Author : Rahul Kumar Malik
-- Tool   : MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS churn_analysis_db;
USE churn_analysis_db;

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

-- -------------------------------------------------------
-- TABLE 1: customers
-- Core customer profile and lifecycle data
-- -------------------------------------------------------
CREATE TABLE customers (
    customer_id         INT PRIMARY KEY AUTO_INCREMENT,
    full_name           VARCHAR(100),
    email               VARCHAR(120),
    city                VARCHAR(60),
    state               VARCHAR(40),
    age                 INT,
    gender              ENUM('Male','Female','Other'),
    acquisition_channel ENUM('Organic','Paid_Search','Social_Media','Referral','Email_Campaign','Offline'),
    acquisition_date    DATE,
    plan_type           ENUM('Basic','Standard','Premium','Enterprise'),
    monthly_spend_inr   DECIMAL(10,2),
    is_churned          TINYINT(1) DEFAULT 0,   -- 1 = churned
    churn_date          DATE,
    churn_reason        VARCHAR(100),
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------
-- TABLE 2: transactions
-- Monthly purchase / usage transactions per customer
-- -------------------------------------------------------
CREATE TABLE transactions (
    transaction_id      INT PRIMARY KEY AUTO_INCREMENT,
    customer_id         INT NOT NULL,
    transaction_date    DATE,
    amount_inr          DECIMAL(10,2),
    product_category    ENUM('Electronics','Apparel','Home','Beauty','Grocery','Sports','Books'),
    payment_method      ENUM('UPI','Credit_Card','Debit_Card','Net_Banking','COD','Wallet'),
    order_status        ENUM('Delivered','Returned','Cancelled','Pending'),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- -------------------------------------------------------
-- TABLE 3: support_tickets
-- Customer complaints and resolution data
-- -------------------------------------------------------
CREATE TABLE support_tickets (
    ticket_id           INT PRIMARY KEY AUTO_INCREMENT,
    customer_id         INT NOT NULL,
    created_date        DATE,
    issue_type          ENUM('Delivery_Delay','Wrong_Product','Refund_Issue','App_Bug','Payment_Failed','Other'),
    severity            ENUM('Low','Medium','High','Critical'),
    resolution_days     INT,
    resolved            TINYINT(1) DEFAULT 1,
    satisfaction_score  INT,   -- 1 to 5
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- -------------------------------------------------------
-- INDEXES
-- -------------------------------------------------------
CREATE INDEX idx_cust_churn       ON customers(is_churned);
CREATE INDEX idx_cust_plan        ON customers(plan_type);
CREATE INDEX idx_cust_channel     ON customers(acquisition_channel);
CREATE INDEX idx_txn_customer     ON transactions(customer_id);
CREATE INDEX idx_txn_date         ON transactions(transaction_date);
CREATE INDEX idx_txn_category     ON transactions(product_category);
CREATE INDEX idx_ticket_customer  ON support_tickets(customer_id);
CREATE INDEX idx_ticket_severity  ON support_tickets(severity);

-- ============================================================
-- HOW TO LOAD DATA
-- After running generate_data.py, import CSVs via:
-- MySQL Workbench → Table Data Import Wizard → select CSV
-- OR use LOAD DATA INFILE (adjust path as needed):
--
-- LOAD DATA INFILE '/path/to/data/customers.csv'
-- INTO TABLE customers FIELDS TERMINATED BY ','
-- ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- ============================================================
