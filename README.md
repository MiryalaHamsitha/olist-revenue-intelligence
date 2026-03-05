# Revenue Quality & Margin Intelligence Model
### Business Analyst Portfolio Project | Olist Brazilian E-Commerce

> Analyzed 96,470 transactions across 2,960 sellers to identify 
> $151,677 in recoverable margin — with a ranked renegotiation list, 
> composite risk scores, and a full executive dashboard.

---

## Business Problem
Is revenue growth creating sustainable profit, or is the platform 
scaling volume while eroding margin?

**Five stakeholder questions this project answers:**
- Which sellers are generating high revenue but destroying margin?
- How much profit is recoverable if underperforming sellers improve?
- Where are delivery delays concentrated and what do they cost?
- How stable and concentrated is platform revenue?
- Which sellers carry the highest combined commercial risk?

---

## Headline Numbers

| Metric | Value | So What? |
|---|---|---|
| Total Revenue | $15.4M | Platform scale confirmed |
| Avg Contribution Margin | 23.7% | Healthy but uneven across sellers |
| Renegotiation Targets | 617 sellers | High revenue, low margin segment |
| Margin Uplift Opportunity | $151,677 | Recoverable profit if Risk sellers match Star margins |
| Delivery Delay Rate | 8.1% | 7,826 orders arriving late |
| Review Score Drop | 40% lower | Delayed orders score 2.57 vs 4.29 on-time |

---

## 8-Phase Approach

| Phase | What I did |
|---|---|
| 1 | Joined 7 datasets into one master table (96,470 orders) |
| 2 | Built financial model — revenue, COGS, profit, contribution margin |
| 3 | Segmented 2,960 sellers into 2x2 matrix (Star / Risk / Growth / Exit) |
| 4 | Delivery delay analysis — regional breakdown and customer impact |
| 5 | Revenue stability index — monthly trend and volatility scoring |
| 6 | Composite risk scoring — margin + delay + concentration weighted model |
| 7 | Excel dashboard — 7 sheets, executive-ready |
| 8 | Strategic recommendations — 4-horizon action plan |

---

## Seller Segmentation Matrix

| Segment | Count | Action |
|---|---|---|
| Star (High Rev, High Margin) | 863 | Protect and grow |
| Risk (High Rev, Low Margin) | 617 | Renegotiate immediately |
| Growth (Low Rev, High Margin) | 617 | Scale up |
| Exit (Low Rev, Low Margin) | 863 | Review or remove |

---

## Key Findings

**1. Margin erosion hidden inside revenue growth**
617 sellers account for significant revenue but operate below median 
margin. Renegotiating to Star-seller margin levels = $151,677 
additional profit.

**2. Delivery delays destroy customer trust**
8.1% of orders arrive late. Delayed orders receive review scores 
40% lower than on-time orders (2.57 vs 4.29). Seven states show 
above-average delay rates.

**3. Revenue is moderately stable**
CV of 0.59 indicates moderate volatility. Top 10 sellers account 
for only 12.9% of revenue — healthy diversification, low 
single-seller dependency risk.

---

## Strategic Recommendations

| Timeline | Action |
|---|---|
| 0–30 days | Contact top 20 Risk sellers — present margin gap data |
| 30–90 days | Renegotiate terms with 617 Risk segment sellers |
| 3–6 months | Implement seller performance scoring and monitoring |
| 6–12 months | Build incentive structure rewarding margin improvement |

---

## Tools Used
SQL | Python (pandas) | Microsoft Excel | Tableau | Data Visualization

---

## Repository Structure
```
olist-revenue-intelligence/
├── README.md
├── case_study.pdf
├── outputs/
│   ├── Revenue_Intelligence_Model_Olist.xlsx
│   ├── chart1_revenue_trend.png
│   ├── chart2_seller_matrix.png
│   └── chart3_delay_impact.png
├── sql/
│   └── Revenue_Intelligence_SQL_Model.sql
└── data/
    ├── seller_financials.csv
    ├── seller_operations.csv
    ├── seller_risk_scores.csv
    ├── monthly_revenue.csv
    └── region_operations.csv


 MiryalaHamsitha
