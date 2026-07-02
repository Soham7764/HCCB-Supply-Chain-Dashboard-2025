# HCCB Supply Chain & Distribution Intelligence Dashboard 2025

## Project Overview
End-to-end supply chain analytics dashboard built for 
Hindustan Coca-Cola Beverages (HCCB) using MySQL, Power BI and Excel.

## Tools Used
- MySQL — Database design & KPI queries
- Power BI — Dashboard & DAX measures  
- Excel — Raw data preparation

## Dataset
Synthetic dataset modeled on HCCB's real distribution 
network covering:
- 20 depots across India
- 20 SKUs (Thums Up, Sprite, Kinley, Maaza etc.)
- 15 suppliers
- 25 distributors
- 5,880+ rows of supply chain data

## Database Schema
8 tables in star schema design:
- dim_products
- dim_depots
- dim_suppliers
- dim_distributors
- fact_inventory
- fact_orders
- fact_shipments
- fact_sales_dispatch

## Dashboard Pages
1. Executive Summary
2. Inventory Management
3. Supplier Performance
4. Logistics & Shipments
5. Sales Dispatch & Distribution

## Key KPIs Tracked
- On Time Delivery %
- Order Fill Rate %
- Inventory Turnover Ratio
- Supplier Delay Rate %
- MoM Revenue Growth %
- Stock Deficit Analysis
- Freight Cost by Region
- ABC Product Classification

## Screenshots
![Executive Summary](screenshots/page1_executive_summary.png)
![Inventory Management](screenshots/page2_inventory.png)
![Supplier Performance](screenshots/page3_supplier.png)
![Logistics](screenshots/page4_logistics.png)
![Sales Dispatch](screenshots/page5_sales.png)

## Project Structure
HCCB-Supply-Chain-Dashboard-2025/
├── HCCB_Supply_Chain_Dataset_2025.xlsx
├── HCCB_Supply_Chain_SQL_Queries.sql
├── screenshots/
│   ├── page1_executive_summary.png
│   ├── page2_inventory.png
│   ├── page3_supplier.png
│   ├── page4_logistics.png
│   └── page5_sales.png
└── README.md

## Author
soham padwal
MCA Fresher | jr.Data Analyst
Mumbai, Maharashtra
