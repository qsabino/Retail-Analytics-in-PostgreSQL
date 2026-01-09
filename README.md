# Retail Analytics PostgreSQL Project

## Overview

This project demonstrates a comprehensive set of **SQL queries for retail analytics** using a transactional dataset. The dataset includes **customers, products, orders, returns, promotions, shippings, retailers, and warehouses**. The queries cover:

- **Aggregates & joins**: revenue, profit, orders, returns  
- **Window functions & ranking**: RFM scores, rolling revenue, customer ranking  
- **Time-series & cohort analysis**: monthly trends, retention, lifecycle  
- **Promotions & basket analysis**: uplift, frequently purchased items  
- **Delivery & logistics**: SLA violations, weighted shipping costs  
- **Data quality & segmentation**: churn, repeat purchases, discount buckets  

These queries provide insights for **sales, marketing, supply chain, and product management**.

---

## Dataset Tables

| Table | Key Columns | Description |
|-------|------------|-------------|
| `dim_customers` | customer_id, age_group, gender, region, channel | Customer master data |
| `dim_products` | product_sku, name, category, gender, size, color | Product master data |
| `dim_promotions` | promotion_id, product_sku, start_date, end_date, discount, campaign_name | Promotion campaigns |
| `dim_retailers` | retailer_id, name, channel, city, region, country | Retailer master |
| `dim_warehouses` | warehouse_id, location, region, capacity | Warehouse master |
| `dim_date` | date, year, month, quarter, weekday, is_holiday | Calendar / date table |
| `fact_orders` | order_id, order_date, product_sku, customer_id, quantity, price, cost, discount | Sales transactions |
| `fact_returns` | order_id, product_sku, return_quantity, return_date | Returned items |
| `fact_shippings` | order_id, ship_date, delivery_date, duration, shipping_method, carrier, cost, status | Shipping data |

---

## Key Queries & Analyses

### Sales & Revenue
- Top products, categories, and retailers by revenue/profit  
- Customer lifetime value and lifetime profit  
- Revenue split by promotion, month-over-month growth, average order profit  

### Returns & Discounts
- Monthly return rates and top returned products  
- Average discounts per category, discount buckets, promotions without uplift  
- Identify SKUs with more returns than sales  

### Customers & Segmentation
- RFM scoring, repeat purchase rate, single-order customers  
- Customer churn risk, cohort analysis and retention  
- Customer segmentation by age group  

### Products & Promotions
- Most profitable promotions, products, and categories  
- Product lifecycle: first & last sale, lifecycle duration  
- Products frequently purchased together  
- Predict next-month demand with SMA  

### Logistics & Operations
- Average delivery duration per carrier/region  
- Weighted shipping costs  
- Delivery SLA violation rate, deviation from average  
- Orders per warehouse, warehouses serving most orders  

### Advanced & Analytical Techniques
- Ranking and window functions (RFM, monthly trends, rolling revenue)  
- Self-joins
- CTEs and pivoting for promotion uplift analysis  
- Time-series analysis using `DATE_TRUNC` and moving averages  

---

## Insights & Applications

1. **Sales optimization**: Identify top-selling and most profitable SKUs and categories.  
2. **Marketing effectiveness**: Measure promotion impact and frequent product bundles.  
3. **Customer management**: Track RFM, retention, churn risk, and repeat purchase behavior.  
4. **Inventory & supply chain**: Monitor warehouse performance, shipping costs, and delivery SLA compliance.  
5. **Forecasting**: Predict next-month demand using rolling averages for inventory planning.  

---

## Summary

This project demonstrates **end-to-end SQL analytics for retail operations**. It integrates **aggregates, joins, window functions, CTEs, ranking, and time-series** to generate **business-critical insights**. The queries can be used directly for **dashboards, reporting, or further predictive modeling** in tools like Power BI, or Excel.

---

