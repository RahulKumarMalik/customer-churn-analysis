# Customer Retention, Revenue Leakage & Churn Analysis
### Tools: MySQL · Advanced Excel · Python (data generation) · GitHub Pages

> **Project by Rahul Kumar Malik** — Part of a broader analyst portfolio targeting credit, risk, operations, and business analysis roles.

## 🌐 [Live Dashboard → View on GitHub Pages](https://rahulkumarmalik.github.io/customer-churn-analysis/)

---

## Project Overview

This project replicates a real-world **customer retention and churn intelligence workflow** used by e-commerce, SaaS, and subscription businesses to identify at-risk customers, quantify revenue leakage, and design targeted retention interventions.

- **30,000 synthetic customer records** with realistic churn, spend, and support patterns
- **240,000+ transactions** across 7 product categories
- **RFM segmentation** (6 segments) with revenue and churn breakdown
- **Churn risk scoring model** with weighted behavioural signals
- **Revenue recovery model**: 12% win-back → ₹15,00,000 annualised MRR recovery
- **GitHub Pages dashboard** with 6 interactive charts

---

## Repository Structure

```
customer-churn-analysis/
│
├── index.html                    # GitHub Pages interactive dashboard
├── generate_data.py              # Generates 30,000 customers + transactions
├── schema.sql                    # MySQL schema (3 tables, indexes)
├── analysis_queries.sql          # 7 SQL sections (RFM, cohort, CLV, churn score)
├── customer_churn_workbook.xlsx  # Excel workbook (4 sheets)
├── data/
│   ├── customers.csv
│   ├── transactions.csv
│   └── support_tickets.csv
└── README.md
```

---

## Database Schema

```
customers        → profile, plan, acquisition channel, churn status & date
transactions     → 240K+ purchase records by category, payment, status
support_tickets  → complaint history, severity, resolution, CSAT scores
```

**Relationships:**
`customers` ←→ `transactions` (1:many)
`customers` ←→ `support_tickets` (1:many)

---

## SQL Analysis Sections

| Section | What it does |
|---|---|
| Section 1 | Portfolio overview — churn by plan, by acquisition channel |
| Section 2 | **RFM Segmentation** — NTILE scoring, segment classification via CASE-WHEN |
| Section 3 | **Pareto Analysis** — PERCENT_RANK to identify top 20% revenue drivers |
| Section 4 | **Churn early warning** — inactivity band distribution for churned vs active |
| Section 5 | **Cohort retention** — monthly acquisition cohorts tracked over 12 months |
| Section 6 | Support ticket impact — churn rate by ticket count and issue type |
| Section 7 | CLV analysis + revenue leakage by month + **weighted churn risk scoring** |

---

## RFM Segmentation Model

Customers scored on Recency, Frequency, Monetary using `NTILE(5)` window functions:

| Segment | Churn Rate | Revenue Share | Priority |
|---|---|---|---|
| Champions | 6.6% | 23.4% | ⭐ Reward & Upsell |
| Loyal Customers | 8.4% | 27.3% | 💛 Nurture |
| At Risk | **59.9%** | **24.3%** | 🚨 Intervene Now |
| Recent Customers | 7.7% | 8.0% | 🌱 Onboard Well |
| Needs Attention | 24.0% | 10.8% | 📋 Re-engage |
| Lost Customers | 41.1% | 6.2% | 😔 Win-back |

---

## Key Findings

| Finding | Detail |
|---|---|
| Pareto Revenue | Top 20% of customers → 37% of revenue; top 50% → 71% |
| 45-Day Signal | Churned customers show 45+ day inactivity before churn date — measurable early-warning window |
| Plan Predictor | Basic plan churn: 39.1% vs Enterprise: 8.1% — 4.8× difference |
| At Risk Exposure | ₹938L revenue held by At Risk segment (59.9% churn rate) |
| Channel Quality | Paid Search: 30.1% churn vs Social Media: 23.2% — CAC reallocation recommended |
| Recovery Projection | 12% churn reduction in Critical + High cohorts → ₹15,00,000 ARR recovery at 8-10× ROI |

---

## Excel Workbook — 4 Sheets

| Sheet | Description |
|---|---|
| `Churn_Risk_Scorer` | Live churn scorer — enter 5 customer signals, get instant risk verdict + retention action |
| `RFM_Analysis` | Segment performance summary with findings panel |
| `Customer_Data` | 1,000 sample records, colour-coded by churn and RFM segment, auto-filter enabled |
| `Retention_Planner` | Interactive campaign ROI model — adjust win-back rates and cost assumptions, see revenue recovery |

---

## How to Enable GitHub Pages

1. Push all files to your GitHub repository
2. Go to **Settings → Pages**
3. Set **Source** to `main` branch, root folder `/`
4. Your dashboard will be live at `https://[username].github.io/[repo-name]/`

---

## How to Run Locally

**Step 1 — Generate data**
```bash
pip install pandas numpy
python generate_data.py
```

**Step 2 — MySQL setup**
```sql
source schema.sql;
-- Import CSVs from data/ using MySQL Workbench Table Data Import Wizard
```

**Step 3 — Run SQL analysis**
```sql
source analysis_queries.sql;
```

**Step 4 — Open Excel**
Open `customer_churn_workbook.xlsx` — all formulas live. Go to `Churn_Risk_Scorer` and enter any customer's values.

**Step 5 — View dashboard**
Open `index.html` in any browser, or enable GitHub Pages for the live hosted version.

---

## Skills Demonstrated

`MySQL` · `Window Functions (NTILE, PERCENT_RANK, RANK)` · `CTEs` · `Cohort Analysis` · `RFM Segmentation` · `Advanced Excel` · `Churn Risk Scoring` · `Revenue Recovery Modelling` · `MIS Reporting` · `GitHub Pages` · `Data Visualisation` · `Retention Strateg
