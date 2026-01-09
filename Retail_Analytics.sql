-------------------------------------------------------------------------------
/* Joins, subqueries, window functions, aggregates, ranking, date logic. */
-------------------------------------------------------------------------------

-- 1. Find top 10 products by revenue.
SELECT p.product_name,
	SUM(o.product_price * o.order_quantity) AS revenue
FROM dim_products p
JOIN fact_orders o ON p.product_sku = o.product_sku
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 10;

-- 2. Customer lifetime value (CLV) based on revenue.
SELECT c.customer_id,
	SUM(o.product_price * o.order_quantity) AS revenue
FROM dim_customers c 
JOIN fact_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id

-- 3. Mothly return rate.
SELECT d.year, d.month,
	SUM(r.return_quantity)::float/
	SUM(o.order_quantity) AS return_rate
FROM fact_returns r
JOIN fact_orders o ON r.order_id = o.order_id
JOIN dim_date d ON o.order_date = d.date
GROUP BY d.year, d.month;

-- 4. Percent of orders with promotions.
-- Add column is_promotion_active to fact_orders table
ALTER TABLE fact_orders
ADD COLUMN is_promotion_active BOOLEAN;

UPDATE fact_orders o
SET is_promotion_active = 
	CASE 
    	WHEN dp.product_sku IS NOT NULL THEN TRUE
    	ELSE FALSE
	END
FROM dim_promotions dp
WHERE dp.product_sku = fo.product_sku
  AND fo.order_date BETWEEN dp.start_date AND dp.end_date;

-- Drop the column is_promotion_active, using VIEW
ALTER TABLE fact_orders
DROP COLUMN IF EXISTS is_promotion_active;

-- Create a VIEW with promotion logic
CREATE OR REPLACE VIEW fact_orders_with_promo AS
SELECT o.*,
	EXISTS (
		SELECT 1
		FROM dim_promotions dp
		WHERE dp.product_sku = o.product_sku
			AND o.order_date BETWEEN dp.start_date AND dp.end_date
	) AS is_promotion_active
FROM fact_orders o;

-- 
SELECT 
    100 * SUM(CASE WHEN is_promotion_active THEN 1 ELSE 0 END)::float/
	COUNT(*) AS promo_ratio
FROM fact_orders_with_promo;

-- 5. Average delivery duration per carrier.
SELECT carrier, AVG(delivery_duration) AS average_delivery
FROM fact_shippings
GROUP BY carrier;

-- 6. Rank customers by RFM score.
CREATE OR REPLACE VIEW customer_rfm AS
WITH rfm_raw AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(order_id) AS frequency,
        SUM(order_quantity * product_price - product_discount) AS monetary
    FROM fact_orders
    GROUP BY customer_id
),
rfm_scored AS (
    SELECT
        customer_id,
        (CURRENT_DATE - last_order_date) AS recency,
        frequency,
        monetary,
		-- Lower RFM score indicates better customer value.
        NTILE(5) OVER (ORDER BY (CURRENT_DATE - last_order_date)) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
    FROM rfm_raw
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score * 100 + f_score * 10 + m_score) AS rfm_score
FROM rfm_scored;

--
SELECT customer_id, rfm_score,
	RANK() OVER(ORDER BY rfm_score)
FROM customer_rfm
LIMIT 20;

-- 7. Top 3 most profitable categories.
SELECT p.product_category,
	SUM((o.product_price - o.product_cost) * o.order_quantity) AS profit
FROM dim_products p
JOIN fact_orders o ON p.product_sku = o.product_sku
GROUP BY p.product_category
ORDER BY profit DESC
LIMIT 3;

-- 8. Find products with no sales.
SELECT p.product_name
FROM dim_products p
LEFT JOIN fact_orders o ON p.product_sku = o.product_sku
WHERE o.order_id = NULL;

-- 9. Count orders shipped from each warehouse.
SELECT w.warehouse_id, COUNT(*)
FROM dim_warehouses w
JOIN fact_shippings s ON w.warehouse_id = s.warehouse_id
GROUP BY w.warehouse_id
ORDER BY COUNT(*);

-- 10. Customer repeat purchase rate.
SELECT
	COUNT(DISTINCT customer_id) FILTER (WHERE order_count > 1)::float/
	COUNT(DISTINCT customer_id) AS repeat_rate
FROM (
	SELECT customer_id, COUNT(*) AS order_count
	FROM fact_orders
	GROUP BY customer_id
	) x;

-- 11. Revenue split by promotion status.
SELECT is_promotion_active,
	SUM(product_price * order_quantity) AS revenue
FROM fact_orders_with_promo
GROUP BY is_promotion_active;

-- 12. Identify the most seasonal product (largest month variance).
CREATE OR REPLACE VIEW product_monthly_quantity AS
SELECT 
	product_sku,
	DATE_TRUNC('month', order_date) AS month,
	SUM(order_quantity) AS monthly_quantity
FROM fact_orders
GROUP BY product_sku, DATE_TRUNC('month', order_date);

SELECT 
	product_sku,
	VAR_SAMP(monthly_quantity) AS variance
FROM product_monthly_quantity
GROUP BY product_sku
ORDER BY variance DESC
LIMIT 1;

-- 13. Show average discount per category.
SELECT
	p.product_category,
	-- NULL discounts to count as 0
	AVG(COALESCE(o.product_discount, 0) avg_discount
FROM dim_products p
LEFT JOIN fact_orders o ON p.product_sku = o.product_sku
GROUP BY product_category

-- 14. Orders vs returns per product.
SELECT 
	o.product_sku, 
	SUM(o.order_quantity) AS ordered, 
	SUM(COALESCE(r.return_quantity, 0)) AS returned
FROM fact_orders o
LEFT JOIN fact_returns r ON o.order_id = r.order_id
GROUP BY o.product_sku;

-- 15. Delivery on-time rate.
SELECT
	SUM(
		CASE 
			WHEN delivery_status = 'on-time' THEN 1
			ELSE 0
		END)::float /
	COUNT (*) AS on_time_rate
FROM fact_shippings;

-- 16. Monthly profit trend.
SELECT
	DATE_TRUNC('month', order_date) AS month,
	SUM((product_price - product_cost) * order_quantity) AS profit
FROM fact_orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;

-- 17. Best 5 retailers by revenue.
SELECT 
	r.retailer_id,
	r.retailer_name,
	COALESCE(SUM(o.product_price * o.order_quantity), 0) AS revenue
FROM dim_retailers r
LEFT JOIN fact_orders o ON r.retailer_id = o.retailer_id
GROUP BY r.retailer_id, r.retailer_name
ORDER BY revenue DESC
LIMIT 5;

-- 18. Top 10 most returned products 
SELECT 
	product_sku, 
	SUM(return_quantity) AS total_returns
FROM fact_returns
GROUP BY product_sku
ORDER BY total_returns DESC
LIMIT 10;

-- 19. Identify customer churn risk (no orders in last 90 days).
SELECT 
	c.customer_id,
	MAX(o.order_date) AS last_order_date
FROM dim_customers c
LEFT JOIN fact_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id
HAVING MAX(o.order_date) < CURRENT_DATE - INTERVAL '90 days'
OR MAX(o.order_date) IS NULL;

-- 20. Retailer performance by region.
SELECT  
	dr.region,
	COALESCE(SUM(o.order_quantity), 0) AS total_quantity
FROM dim_retailers dr
LEFT JOIN fact_orders o ON dr.retailer_id = o.retailer_id
GROUP BY dr.region
ORDER BY total_quantity DESC;

-- 21. Percent of orders by channel
SELECT 
	dr.retailer_channel,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_orders
FROM dim_retailers dr
JOIN fact_orders o ON dr.retailer_id = o.retailer_id
GROUP BY dr.retailer_channel
ORDER BY pct_orders DESC;

-- 22. Top 3 customers by lifetime profit.
SELECT
	c.customer_id,
	COALESCE(SUM((o.product_price - o.product_cost) * o.order_quantity), 0) AS lifetime_profit
FROM dim_customers c
LEFT JOIN fact_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id
ORDER BY lifetime_profit DESC
LIMIT 3;

-- 23. Find average delivery duration per region.
SELECT
	dr.region,
	ROUND(AVG(s.delivery_duration), 2) AS avg_delivery
FROM dim_retailers dr
JOIN fact_orders o ON dr.retailer_id = o.retailer_id
JOIN fact_shippings s ON o.order_id = s.order_id
GROUP BY dr.region
ORDER BY avg_delivery DESC;

-- 24. Products that had promotions but no uplift (sales unchanged).
WITH sales AS (
    SELECT
        product_sku,
        is_promotion_active,
        COUNT(DISTINCT order_date) AS active_days,
        SUM(order_quantity) AS total_qty
    FROM fact_orders_with_promo
    GROUP BY product_sku, is_promotion_active
),
pivoted AS (
    SELECT
        product_sku,
        SUM(CASE WHEN is_promotion_active THEN total_qty / NULLIF(active_days,0) END) AS promo_daily_qty,
        SUM(CASE WHEN NOT is_promotion_active THEN total_qty / NULLIF(active_days,0) END) AS nonpromo_daily_qty
    FROM sales
    GROUP BY product_sku
)
SELECT 
	product_sku,
	promo_daily_qty,
	nonpromo_daily_qty
FROM pivoted
WHERE promo_daily_qty <= nonpromo_daily_qty;

-- 25. Most profitable product in each category.
WITH product_profit AS (
    SELECT 
        p.product_category,
        p.product_sku,
        SUM((o.product_price - o.product_cost) * o.order_quantity) AS profit
    FROM fact_orders o
    JOIN dim_products p 
        ON o.product_sku = p.product_sku
    GROUP BY 
        p.product_category, 
        p.product_sku
),
ranked_products AS (
    SELECT 
        product_category,
        product_sku,
        profit,
        RANK() OVER (
            PARTITION BY product_category 
            ORDER BY profit DESC
        ) AS rk
    FROM product_profit
)
SELECT 
    product_category,
    product_sku,
    profit
FROM ranked_products
WHERE rk = 1
ORDER BY product_category;

-- 26. Customer segmentation by age group.
SELECT
	age_group,
	COUNT(*)
FROM dim_customers
GROUP BY age_group;

-- 27. Promotion count per campaign.
SELECT
	campaign_name,
	COUNT(*)
FROM dim_promotions
GROUP BY campaign_name;

-- 28. Average profit per order.
WITH order_profit AS (
    SELECT 
        order_id,
        SUM((product_price - product_cost) * order_quantity) AS profit
    FROM fact_orders
    GROUP BY order_id
)
SELECT ROUND(AVG(profit), 2) AS avg_profit_per_order
FROM order_profit;

-- 29. Count shipments per shipping method by month.
SELECT 
	DATE_TRUNC('month', ship_date) AS shipping_month,
	shipping_method,
	COUNT(*)
FROM fact_shippings
GROUP BY shipping_month, shipping_method
ORDER BY shipping_month, shipping_method;

-- 30. Which products performed worst (by revenue) in each month.
WITH product_revenue AS (
	SELECT
		DATE_TRUNC('month', order_date) AS order_month,
		product_sku,
		SUM(product_price * order_quantity) AS revenue
	FROM fact_orders
	GROUP BY order_month, product_sku
),
ranked_productS AS(
	SELECT
		order_month,
		product_sku,
		revenue,
		RANK () OVER(
			PARTITION BY order_month
			ORDER BY revenue ASC
		) AS rk
	FROM product_revenue
)
SELECT *
FROM ranked_products
WHERE rk = 1
ORDER BY order_month;

-- 31. Delivery speed deviation from average.
SELECT order_id, 
       delivery_duration,
       ROUND(delivery_duration - AVG(delivery_duration) OVER (), 2) AS deviation
FROM fact_shippings;

-- 32. Revenue rate by region
SELECT
	dr.region,
	SUM(product_price * order_quantity) AS revenue,
	SUM(product_price * order_quantity) / SUM(SUM(product_price * order_quantity)) OVER() AS revenue_rate
FROM fact_orders o
JOIN dim_retailers dr ON o.retailer_id = dr.retailer_id
GROUP BY dr.region
ORDER BY revenue_rate DESC;

-- 33. Customers with the highest return rate.
-- Avoid double-counting o.order_quantity due to join when an order has multiple return rows
WITH returns_by_order AS (
    SELECT
        order_id,
        SUM(return_quantity) AS return_qty
    FROM fact_returns
    GROUP BY order_id
)
SELECT
    o.customer_id,
    SUM(o.order_quantity) AS total_order_qty,
    COALESCE(SUM(r.return_qty), 0) AS total_return_qty,
    COALESCE(SUM(r.return_qty), 0)::float 
        / NULLIF(SUM(o.order_quantity), 0) AS return_rate
FROM fact_orders o
LEFT JOIN returns_by_order r ON o.order_id = r.order_id
GROUP BY o.customer_id
ORDER BY return_rate DESC NULLS LAST;

-- 34. Count active promotions per month.
SELECT 
	DATE_TRUNC('month', start_date) AS month, 
	COUNT(*)
FROM dim_promotions
GROUP BY month;

-- 35. Which warehouse serves the most orders?
SELECT w.warehouse_location, COUNT(*) AS orders
FROM fact_shippings s
JOIN dim_warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_location
ORDER BY orders DESC;
--LIMIT 1;

-- 36. Find SKUs with more returns than sales.
WITH sku_sales_returns AS (
    SELECT 
        p.product_sku,
        SUM(o.order_quantity) AS ordered,
        SUM(r.return_quantity) AS returned
    FROM dim_products p
    LEFT JOIN fact_orders o ON p.product_sku = o.product_sku
    LEFT JOIN fact_returns r ON p.product_sku = r.product_sku
    GROUP BY p.product_sku
)
SELECT product_sku, ordered, returned
FROM sku_sales_returns
WHERE returned > ordered;

-- 37. Month-over-month revenue growth.
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', order_date) AS month,
        SUM(product_price * order_quantity) AS revenue
    FROM fact_orders
    GROUP BY DATE_TRUNC('month', order_date)
    ORDER BY month
)
SELECT
    month,
    revenue,
    revenue - LAG(revenue) OVER (ORDER BY month) AS mom_growth
FROM monthly_revenue;

-- 38. Find customer order frequency.
SELECT customer_id, COUNT(*) AS order_count
FROM fact_orders
GROUP BY customer_id;

-- 39. Find the average discount by discount bucket.
WITH orders_with_discount_bucket AS (
    SELECT 
        product_discount,
        CASE
            WHEN product_discount = 0 THEN '0%'
            WHEN product_discount > 0 AND product_discount <= 10 THEN '1-10%'
            WHEN product_discount > 10 AND product_discount <= 20 THEN '11-20%'
            WHEN product_discount > 20 AND product_discount <= 30 THEN '21-30%'
            WHEN product_discount > 30 AND product_discount <= 50 THEN '31-50%'
            ELSE '50%+'
        END AS discount_bucket
    FROM fact_orders
)
SELECT 
    discount_bucket,
    ROUND(AVG(product_discount), 2) AS avg_discount
FROM orders_with_discount_bucket
GROUP BY discount_bucket
ORDER BY discount_bucket;

-- 40. Identify customers with only 1 order.
SELECT customer_id
FROM fact_orders
GROUP BY customer_id
HAVING COUNT(*) = 1;

---------------------------------------------------------------------
/* Window analytics, cohort analysis, predictive SQL, advanced joins, 
segmentation, time-series, data-quality checks. */
---------------------------------------------------------------------

-- 81. 12-month rolling revenue.
WITH daily_revenue AS (
    SELECT
        DATE_TRUNC('day', order_date) AS order_day,
        SUM(product_price * order_quantity) AS revenue
    FROM fact_orders
    GROUP BY DATE_TRUNC('day', order_date)
)
SELECT
    order_day,
    SUM(revenue) OVER (
        ORDER BY order_day
        RANGE BETWEEN INTERVAL '365 days' PRECEDING AND CURRENT ROW
    ) AS rolling_12m_revenue
FROM daily_revenue
ORDER BY order_day;

-- Or
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS order_month,
        SUM(product_price * order_quantity) AS revenue
    FROM fact_orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    order_month,
    SUM(revenue) OVER (
        ORDER BY order_month
        RANGE BETWEEN INTERVAL '12 months' PRECEDING AND CURRENT ROW
    ) AS rolling_12m_revenue
FROM monthly_revenue
ORDER BY order_month;

-- 42. Cohort analysis: customer first purchase month.
SELECT 
		customer_id,
       	MIN(DATE_TRUNC('month', order_date)) AS cohort_month
FROM fact_orders
GROUP BY customer_id
ORDER BY cohort_month;

-- 43. Cohort retention (monthly repeat customers).
WITH customer_cohort AS (
    SELECT customer_id,
           MIN(DATE_TRUNC('month', order_date)) AS cohort_month
    FROM fact_orders
    GROUP BY customer_id
),
customer_orders AS (
    SELECT customer_id,
           DATE_TRUNC('month', order_date) AS order_month
    FROM fact_orders
)
SELECT 
	cohort_month, 
	order_month, 
	COUNT(DISTINCT customer_orders.customer_id) AS customers
FROM customer_orders
JOIN customer_cohort USING (customer_id)
GROUP BY cohort_month, order_month
ORDER BY cohort_month, order_month;

-- 44. Most profitable promotion campaign.
-- 45. Abnormally large order quantities
WITH stats AS (
    SELECT AVG(order_quantity) AS avg_quant,
           STDDEV(order_quantity) AS sd_quant
    FROM fact_orders
)
SELECT o.order_id, o.order_quantity
FROM fact_orders o, stats s
WHERE o.order_quantity > s.avg_quant + 2*s.sd_quant;

-- 46. Weighted average shipping cost by carrier. (Weighted by delivery duration)
SELECT 
	carrier,
    SUM(shipping_cost * delivery_duration) / SUM(delivery_duration) AS weighted_cost
FROM fact_shippings
GROUP BY carrier;

-- 47. Products frequently purchased together. (Requires self-join)
SELECT 
	a.product_sku AS item1, 
	b.product_sku AS item2, 
	COUNT(*) AS freq -- Number of orders where both item1 and item2 appear
FROM fact_orders a
JOIN fact_orders b ON a.order_id = b.order_id AND a.product_sku < b.product_sku
GROUP BY item1, item2
HAVING COUNT(*) >= 10
ORDER BY freq DESC
LIMIT 20;

-- 48. Predict next-month demand using simple moving average (sma).
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           SUM(order_quantity) AS qty
    FROM fact_orders
    GROUP BY month
)
SELECT 
	month,
	qty,	
    AVG(qty) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS sma_3_month
FROM monthly;

-- 49. Delivery SLA violation rate.
-- “What proportion of deliveries did not meet the service level agreement (SLA)?”
SELECT 
    SUM(CASE WHEN delivery_status <> 'On Time' THEN 1 ELSE 0 END)::float /
    COUNT(*) AS violation_rate
FROM fact_shippings;

-- 50. Product lifecycle: first and last sale date.
SELECT
    product_sku,
	COUNT(*) AS total_orders,
    SUM(order_quantity) AS total_units,
    MIN(order_date) AS first_sale,
    MAX(order_date) AS last_sale,
	MAX(order_date) - MIN(order_date) AS lifecycle_days
FROM fact_orders
GROUP BY product_sku
HAVING COUNT(*) > 1;


