"""
generate_data.py
Customer Retention & Churn Analysis — Synthetic Data Generator
Generates 30,000 customers with realistic churn, transaction & support patterns.
Author: Rahul Kumar Malik
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random, os

np.random.seed(7)
random.seed(7)
N = 30_000

def rand_date(start, end):
    return start + timedelta(days=random.randint(0, (end - start).days))

# ── CUSTOMERS ────────────────────────────────────────────────
first = ["Aarav","Priya","Rohan","Sneha","Vikram","Kavya","Arjun","Divya",
         "Rahul","Anjali","Karan","Pooja","Amit","Nisha","Siddharth","Meera",
         "Akash","Shreya","Nikhil","Riya","Aditya","Neha","Varun","Sakshi"]
last  = ["Sharma","Verma","Singh","Gupta","Kumar","Patel","Joshi","Yadav",
         "Mehta","Chauhan","Tiwari","Mishra","Agarwal","Shah","Sinha","Dubey"]
cities = ["Delhi","Mumbai","Bengaluru","Hyderabad","Chennai","Pune",
          "Kolkata","Ahmedabad","Jaipur","Lucknow","Surat","Nagpur","Noida","Gurgaon"]
states = {"Delhi":"Delhi","Mumbai":"Maharashtra","Bengaluru":"Karnataka",
          "Hyderabad":"Telangana","Chennai":"Tamil Nadu","Pune":"Maharashtra",
          "Kolkata":"West Bengal","Ahmedabad":"Gujarat","Jaipur":"Rajasthan",
          "Lucknow":"Uttar Pradesh","Surat":"Gujarat","Nagpur":"Maharashtra",
          "Noida":"Uttar Pradesh","Gurgaon":"Haryana"}

channels  = ["Organic","Paid_Search","Social_Media","Referral","Email_Campaign","Offline"]
ch_wts    = [0.25, 0.20, 0.20, 0.15, 0.12, 0.08]
plans     = ["Basic","Standard","Premium","Enterprise"]
plan_wts  = [0.35, 0.30, 0.25, 0.10]
plan_spend= {"Basic":299, "Standard":599, "Premium":1199, "Enterprise":2999}

churn_reasons = ["Price_Too_High","Switched_Competitor","Poor_Support",
                 "Product_Not_Useful","Better_Alternative","Inactivity","Unknown"]

acq_start = datetime(2021, 1, 1)
acq_end   = datetime(2024, 3, 31)

city_arr    = np.random.choice(cities, N)
plan_arr    = np.random.choice(plans, N, p=plan_wts)
channel_arr = np.random.choice(channels, N, p=ch_wts)
age_arr     = np.random.randint(18, 65, N)
gender_arr  = np.random.choice(["Male","Female","Other"], N, p=[0.52,0.45,0.03])

acq_dates   = [rand_date(acq_start, acq_end) for _ in range(N)]

# Spend with noise
base_spend  = np.array([plan_spend[p] for p in plan_arr], dtype=float)
monthly_spend = np.round(base_spend * np.random.uniform(0.8, 1.3, N), 2)

# Churn probability — correlated with plan, channel, tenure
churn_base  = np.where(plan_arr=="Basic",    0.38,
              np.where(plan_arr=="Standard", 0.22,
              np.where(plan_arr=="Premium",  0.14, 0.07)))
churn_base += np.where(channel_arr=="Paid_Search", 0.06, 0)
churn_base += np.where(channel_arr=="Offline",     0.04, 0)
churn_base  = np.clip(churn_base + np.random.normal(0, 0.03, N), 0.02, 0.70)
is_churned  = np.random.binomial(1, churn_base)

# Churn date = acquisition date + 45 to 720 days
churn_dates = []
churn_rsns  = []
for i in range(N):
    if is_churned[i]:
        cd = acq_dates[i] + timedelta(days=random.randint(45, 720))
        cd = min(cd, datetime(2024, 12, 31))
        churn_dates.append(cd.strftime("%Y-%m-%d"))
        churn_rsns.append(random.choice(churn_reasons))
    else:
        churn_dates.append("")
        churn_rsns.append("")

customers_df = pd.DataFrame({
    "customer_id":         range(1, N+1),
    "full_name":           [f"{random.choice(first)} {random.choice(last)}" for _ in range(N)],
    "email":               [f"user{i}@example.com" for i in range(1, N+1)],
    "city":                city_arr,
    "state":               [states[c] for c in city_arr],
    "age":                 age_arr,
    "gender":              gender_arr,
    "acquisition_channel": channel_arr,
    "acquisition_date":    [d.strftime("%Y-%m-%d") for d in acq_dates],
    "plan_type":           plan_arr,
    "monthly_spend_inr":   monthly_spend,
    "is_churned":          is_churned,
    "churn_date":          churn_dates,
    "churn_reason":        churn_rsns,
})

# ── TRANSACTIONS (avg 8 per customer) ────────────────────────
categories = ["Electronics","Apparel","Home","Beauty","Grocery","Sports","Books"]
cat_wts    = [0.18,0.22,0.15,0.12,0.18,0.08,0.07]
payments   = ["UPI","Credit_Card","Debit_Card","Net_Banking","COD","Wallet"]
pay_wts    = [0.35,0.20,0.18,0.10,0.10,0.07]
statuses   = ["Delivered","Returned","Cancelled","Pending"]
stat_wts   = [0.78,0.10,0.08,0.04]

cat_spend  = {"Electronics":3500,"Apparel":900,"Home":1800,"Beauty":650,
              "Grocery":450,"Sports":1200,"Books":350}

txn_rows = []
tid = 1
for _, cust in customers_df.iterrows():
    n_txns = np.random.poisson(8)
    if is_churned[cust.customer_id - 1]:
        end_d = datetime.strptime(cust.churn_date, "%Y-%m-%d")
    else:
        end_d = datetime(2024, 12, 31)
    start_d = datetime.strptime(cust.acquisition_date, "%Y-%m-%d")
    if start_d >= end_d: continue
    for _ in range(max(1, n_txns)):
        cat  = np.random.choice(categories, p=cat_wts)
        base = cat_spend[cat]
        amt  = round(base * np.random.uniform(0.5, 2.5), 2)
        txn_rows.append({
            "transaction_id":   tid,
            "customer_id":      cust.customer_id,
            "transaction_date": rand_date(start_d, end_d).strftime("%Y-%m-%d"),
            "amount_inr":       amt,
            "product_category": cat,
            "payment_method":   np.random.choice(payments, p=pay_wts),
            "order_status":     np.random.choice(statuses, p=stat_wts),
        })
        tid += 1

txn_df = pd.DataFrame(txn_rows)

# ── SUPPORT TICKETS (correlated with churn) ──────────────────
issue_types = ["Delivery_Delay","Wrong_Product","Refund_Issue","App_Bug","Payment_Failed","Other"]
severities  = ["Low","Medium","High","Critical"]

ticket_rows = []
skid = 1
for _, cust in customers_df.iterrows():
    # Churned customers get more tickets
    n_tickets = np.random.poisson(3 if is_churned[cust.customer_id-1] else 1)
    if is_churned[cust.customer_id - 1] and cust.churn_date:
        end_d = datetime.strptime(cust.churn_date, "%Y-%m-%d")
    else:
        end_d = datetime(2024, 12, 31)
    start_d = datetime.strptime(cust.acquisition_date, "%Y-%m-%d")
    if start_d >= end_d: continue
    for _ in range(n_tickets):
        sev = np.random.choice(severities, p=[0.35,0.35,0.20,0.10])
        res_days = (1 if sev=="Low" else 3 if sev=="Medium" else 7 if sev=="High" else 14)
        res_days = max(1, res_days + random.randint(-1, 5))
        sat = (5 if sev=="Low" else
               random.choice([3,4,5]) if sev=="Medium" else
               random.choice([1,2,3]) if sev=="High" else
               random.choice([1,2]))
        ticket_rows.append({
            "ticket_id":         skid,
            "customer_id":       cust.customer_id,
            "created_date":      rand_date(start_d, end_d).strftime("%Y-%m-%d"),
            "issue_type":        np.random.choice(issue_types),
            "severity":          sev,
            "resolution_days":   res_days,
            "resolved":          1,
            "satisfaction_score":sat,
        })
        skid += 1

tickets_df = pd.DataFrame(ticket_rows)

# ── SAVE ─────────────────────────────────────────────────────
os.makedirs("data", exist_ok=True)
customers_df.to_csv("data/customers.csv",         index=False)
txn_df.to_csv(      "data/transactions.csv",      index=False)
tickets_df.to_csv(  "data/support_tickets.csv",   index=False)

print(f"customers.csv      : {len(customers_df):,} rows")
print(f"transactions.csv   : {len(txn_df):,} rows")
print(f"support_tickets.csv: {len(tickets_df):,} rows")
print(f"\nOverall churn rate : {is_churned.mean()*100:.1f}%")
for p in plans:
    mask = plan_arr == p
    print(f"  {p:12s} churn : {is_churned[mask].mean()*100:.1f}%")
print(f"\nAll CSVs saved to ./data/")
