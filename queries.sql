-- Q1- date range of the data
SELECT MIN(order_purchase_timestamp), MAX(order_purchase_timestamp) FROM orders;


-- Q2- is order_id unique in orders?
SELECT COUNT(*), COUNT(DISTINCT order_id) FROM orders;
-- order_id is unique in orders (99,441 rows = 99,441 distinct)

-- Q3- order statuses
SELECT order_status, COUNT(*) FROM orders GROUP BY order_status ORDER BY 2 DESC;
-- 97% of orders are delivered; revenue analysis will use delivered orders only

-- Q4- how many orders have no delivery date?
SELECT COUNT(*) FROM orders WHERE order_delivered_customer_date IS NULL;
-- 2,965 orders have no delivery date; excluded from delivery-time analysis


-- Q5- Orders Per Month
SELECT TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
       COUNT(order_id) AS orders
       
 FROM orders
 GROUP BY month 
 ORDER BY month;

 

--Q6- monthly revenue (delivered orders only)
SELECT TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
       ROUND(SUM(price), 2) AS revenue
       
 FROM orders 
INNER JOIN order_items
ON orders.order_id = order_items.order_id
WHERE order_status = 'delivered'
GROUP BY month 
ORDER BY month;



--Q7- top 10 categories by revenue (delivered orders)
SELECT product_category_name_english AS category,
       ROUND(SUM(price), 2) AS revenue
       
FROM orders
ON orders.order_id = order_items.order_id
JOIN products
ON order_items.product_id = products.product_id
JOIN category_translation
ON products.product_category_name = category_translation.product_category_name
WHERE order_status = 'delivered'
GROUP BY product_category_name_english
ORDER BY revenue DESC
LIMIT 10;



--Q8- top 10 customers by number of orders.
SELECT customer_unique_id ,COUNT(*) AS total_orders 
FROM orders
JOIN customers
ON orders.customer_id = customers.customer_id
GROUP BY customer_unique_id
ORDER BY total_orders DESC
LIMIT 10;



--Q9- orders with no review.
SELECT COUNT(O.order_id) AS orders_without_review
FROM orders o
LEFT JOIN reviews r
ON o.order_id = r.order_id
WHERE r.review_id IS NULL;




--Q10- labelling late vs on-time
SELECT
    ROUND(AVG(review_score), 2) AS avg_score, 
    CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'On time' 
    END AS delivery_status    
 FROM orders o
 JOIN reviews r
 ON o.order_id = r.order_id
 WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
 GROUP BY delivery_status;



--Q11- slowest states by avg delivery days.
SELECT customer_state,
       ROUND(AVG(order_delivered_customer_date :: DATE - order_purchase_timestamp :: DATE), 1) AS avg_delivery_days 
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
GROUP BY customer_state
ORDER BY avg_delivery_days DESC
LIMIT 10;



--Q12- month-over-month revenue growth
WITH monthly AS (SELECT TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
       ROUND(SUM(price), 2) AS revenue

FROM orders o
JOIN order_items i
ON o.order_id = i.order_id
WHERE order_status = 'delivered'
GROUP BY month      
)

SELECT
    monthly.*,
    LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
    ROUND(((revenue - (LAG(revenue) OVER (ORDER BY month))) / (LAG(revenue) OVER (ORDER BY month)) * 100), 2) AS growth_pct
FROM monthly   
ORDER BY month;

--Using two CTEs
WITH monthly AS (SELECT TO_CHAR(order_purchase_timestamp, 'YYYY-MM') AS month,
       ROUND(SUM(price), 2) AS revenue

FROM orders o
JOIN order_items i
ON o.order_id = i.order_id
WHERE order_status = 'delivered'
GROUP BY month      
), with_prev AS(
    SELECT month,
           revenue,
           LAG(revenue) OVER (ORDER BY month) AS prev_revenue

    FROM monthly       
)

SELECT
    month,
    revenue,
    prev_revenue,
    ROUND(((revenue - prev_revenue) / (prev_revenue) * 100), 2) AS growth_pct
FROM with_prev   
ORDER BY month;



--Q13- order counts per customer_unique_id
SELECT
    COUNT(order_id) AS order_count,
    customer_unique_id

FROM orders o
JOIN customers c   
ON o.customer_id = c.customer_id 
GROUP BY customer_unique_id



--Q14- repeat customer rate
WITH customer_orders AS (
    SELECT customer_unique_id,
       COUNT(o.order_id) AS order_count
    FROM orders o
    JOIN customers c
    ON o.customer_id = c.customer_id       
    GROUP BY customer_unique_id
)

SELECT COUNT(*) AS total_customers,
       COUNT(*) FILTER (WHERE order_count > 1) AS repeat_customers,
       ROUND((COUNT(*) FILTER (WHERE order_count > 1)) * 100.0/COUNT(*), 2) AS repeat_pct
FROM customer_orders



--Q15- top 10 sellers by revenue, with a rank.
SELECT
    s.seller_id,
    ROUND(SUM(price), 2) AS revenue,
    RANK() OVER(ORDER BY ROUND(SUM(price), 2) DESC) AS rnk
FROM orders o
JOIN order_items i
ON o.order_id = i.order_id
JOIN sellers s
ON i.seller_id = s.seller_id
WHERE order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY revenue DESC
LIMIT 10;



--Q16- payment type share
SELECT payment_type,
       COUNT(*) AS payments,
       ROUND(COUNT(*) * 100.0/SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM payments
GROUP BY payment_type
ORDER BY share_pct DESC



--Q17- category share of revenue
SELECT product_category_name_english AS category,
    ROUND(SUM(price) * 100.0/SUM(SUM(price)) OVER (), 2) AS revenue_share_pct
FROM orders o
JOIN order_items i
ON o.order_id = i.order_id
JOIN products p 
ON i.product_id = p.product_id
JOIN category_translation c
ON p.product_category_name = c.product_category_name
WHERE order_status = 'delivered'
GROUP BY product_category_name_english
ORDER BY revenue_share_pct DESC
LIMIT 5;


