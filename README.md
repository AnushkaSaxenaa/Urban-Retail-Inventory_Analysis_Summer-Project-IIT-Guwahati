
# 🛒 Solving Inventory Inefficiencies Using Advanced SQL Analytics

A data-driven inventory analytics pipeline and interactive dashboard for **Urban Retail Co.**, built with **SQL and Power BI**, enabling proactive stock management, reduction of inefficiencies, and enhanced business decision-making.

---

## 📚 Table of Contents

- [Project Overview](#project-overview)  
- [Features](#features)  
- [Key Performance Indicators](#key-performance-indicators)  
- [Data Model](#data-model)  
- [SQL Queries & Analytics](#sql-queries--analytics)  
- [Dashboard Design](#dashboard-design)  
- [Getting Started](#getting-started)  
- [Usage](#usage)  
- [Expected Business Impact](#expected-business-impact)  
- [Contributors](#contributors)  

---

## 📝 Project Overview

**Urban Retail Co.** faces inventory challenges like stockouts, overstock, and fragmented data. This project delivers a complete inventory intelligence solution with:

- Clean, normalized data modeling
- Analytical SQL queries for performance metrics
- Interactive Power BI dashboard

It enables **supply chain analysts, managers, and decision-makers** to operate with foresight instead of hindsight.

---

## ✨ Features

- **Data Normalization**: Converts raw denormalized data into 3rd Normal Form (3NF)
- **Automated KPI Computation**: Calculates all key metrics using SQL logic
- **Analytics Suite**: Detects stockouts, overstock, inventory age, demand patterns, and more
- **Interactive Dashboard**: Built in Power BI with intuitive filters and drilldowns
- **Business Actionability**: Drives decisions for restocking, markdowns, and promotions

---

## 📊 Key Performance Indicators

| KPI                     | Description                                                   |
|------------------------|---------------------------------------------------------------|
| Inventory Turnover     | Efficiency of inventory sold and replenished                  |
| Stockouts              | Products with zero or insufficient stock                      |
| Overstocked Items      | Products above optimal inventory level                        |
| Reorder Alerts         | SKUs needing replenishment based on forecast & sales          |
| Stock-to-Sales Ratio   | Comparison of held inventory to actual sales                  |
| Sell-Through Rate      | % of sold units vs. total ordered                             |
| Inventory Age Ratio    | Duration inventory remains unsold                             |
| Days Sales in Inventory| Avg. days inventory stays before being sold                   |
| Weeks On-Hand          | Inventory ÷ average weekly sales                              |
| Backorder Rate         | % of unfulfilled customer demand                              |

---

## 🗃️ Data Model

The system uses a **relational schema** with the following key tables:

| Table            | Key Fields                                              | Purpose                                           |
|------------------|----------------------------------------------------------|---------------------------------------------------|
| `Store`          | `Store_ID (PK)`, `Region`                                | Store info and region mapping                    |
| `Product`        | `Product_ID (PK)`, `Category`, `Price`                   | Product catalog and pricing                      |
| `Weather`        | `Date`, `Store_ID`, `Weather_Condition`, `Seasonality`  | Weather and seasonal insights                    |
| `Inventory_Fact` | `Date`, `Store_ID`, `Product_ID`, `Inventory_Level`, `Units_Sold`, `Units_Ordered`, `Demand_Forecast` | Core inventory and transaction facts |

---

## 📈 SQL Queries & Analytics

This project includes modular SQL scripts for:

- Inventory turnover & valuation
- Fast/slow mover classification
- Reorder point estimation
- Stock age and movement analysis
- Seasonal and regional trends
- Supplier/store-level performance
- Revenue and sales breakdowns

_All SQL scripts are fully documented and adaptable._

---

## 📊 Dashboard Design

The **Power BI Dashboard** includes:

- **KPI Cards**: Inventory worth, turnover, reorder alerts
- **Bar Charts**: Top/bottom performers, stock health
- **Line Charts**: Trends over time (sales, stock levels)
- **Pie Charts**: Category-wise and region-wise distribution
- **Area Charts**: Demand forecast vs. actual orders

**User Experience Features:**
- Filter by store, product, category, or time
- Conditional formatting (e.g., red for critical alerts)
- Drill-through for operational or strategic deep dives

---


## 💻 Usage

- Use SQL scripts to generate insights and operational alerts
- Visualize KPIs and trends using Power BI, Tableau, or Excel
- Act on inventory inefficiencies, demand trends, and restocking alerts

---

## 📈 Expected Business Impact

- ✅ Reduced stockouts and overstock by enabling data-driven replenishment
- ✅ Lower inventory holding costs
- ✅ Better supplier coordination and demand forecasting
- ✅ Increased customer satisfaction through availability
- ✅ Scalable analytics for strategic growth

---

## 👥Othe Contributors

- **Saurabh Tripathi**
- **Shikha Kumari** 

---

