-- 1. What is the average number of orders per customer? Are there high-value repeat customers?

SELECT 
    AVG(OrderCount) AS Avg_Orders_Per_Customer
FROM (
    SELECT 
        CustomerID,
        COUNT(OrderID) AS OrderCount
    FROM Orders
    GROUP BY CustomerID
) AS CustomerOrders;



-- 2. How do customer order patterns vary by city or country?

SELECT
    ShipCountry,
    ShipCity,
    COUNT(OrderID) AS Total_Orders,
    COUNT(DISTINCT CustomerID) AS Unique_Customers,
    ROUND(AVG(Freight), 2) AS Avg_Freight,
    ROUND(
        COUNT(OrderID) * 1.0 /
        COUNT(DISTINCT CustomerID),
        2
    ) AS Avg_Orders_Per_Customer
FROM Orders
GROUP BY ShipCountry, ShipCity
ORDER BY Total_Orders DESC;


-- 3.Can we cluster customers based on total spend, order count, and preferred categories?

WITH customer_spending AS (

    SELECT
        o.customerid,
        COUNT(DISTINCT o.orderid) AS order_count,

        ROUND(
            SUM(
                od.unitprice *
                od.quantity *
                (1 - od.discount)
            ),
            2
        ) AS total_spend

    FROM orders o

    JOIN order_details od
        ON o.orderid = od.orderid

    GROUP BY o.customerid
),

customer_category AS (

    SELECT
        o.customerid,
        c.categoryname,

        COUNT(*) AS purchase_count,

        ROW_NUMBER() OVER (
            PARTITION BY o.customerid
            ORDER BY COUNT(*) DESC
        ) AS rn

    FROM orders o

    JOIN order_details od
        ON o.orderid = od.orderid

    JOIN products p
        ON od.productid = p.productid

    JOIN categories c
        ON p.categoryid = c.categoryid

    GROUP BY
        o.customerid,
        c.categoryname
)

SELECT
    cs.customerid,
    cs.total_spend,
    cs.order_count,
    cc.categoryname AS preferred_category

FROM customer_spending cs

LEFT JOIN customer_category cc
ON cs.customerid = cc.customerid

WHERE cc.rn = 1

ORDER BY cs.total_spend DESC;


-- 4. Which product categories or products contribute most to order revenue? 5 .Are there any correlations between orders and customer location or product category?

SELECT
    o.shipcountry,
    o.shipcity,

    c.categoryname,

    COUNT(DISTINCT o.orderid) AS total_orders,

    SUM(od.quantity) AS total_quantity,

    ROUND(
        SUM(
            od.unitprice *
            od.quantity *
            (1 - od.discount)
        ),
        2
    ) AS total_revenue,

    ROUND(
        AVG(
            od.unitprice *
            od.quantity *
            (1 - od.discount)
        ),
        2
    ) AS avg_order_value

FROM orders o

JOIN order_details od
    ON o.orderid = od.orderid

JOIN products p
    ON od.productid = p.productid

JOIN categories c
    ON p.categoryid = c.categoryid

GROUP BY
    o.shipcountry,
    o.shipcity,
    c.categoryname

ORDER BY
    total_revenue DESC;


-- 5. How frequently do different customer segments place orders?

WITH customer_orders AS (

    SELECT
        customerid,
        COUNT(orderid) AS total_orders

    FROM orders

    GROUP BY customerid
),

customer_segments AS (

    SELECT
        customerid,
        total_orders,

        CASE
            WHEN total_orders >= 10
                THEN 'High Frequency'

            WHEN total_orders >= 5
                THEN 'Medium Frequency'

            ELSE 'Low Frequency'
        END AS customer_segment

    FROM customer_orders
)

SELECT
    customer_segment,

    COUNT(customerid) AS total_customers,

    ROUND(
        AVG(total_orders),
        2
    ) AS avg_orders_per_customer,

    SUM(total_orders) AS total_orders

FROM customer_segments

GROUP BY customer_segment

ORDER BY avg_orders_per_customer DESC;


-- 6. What is the geographic and title-wise distribution of employees?


SELECT
    country,
    city,
    title,

    COUNT(employeeid) AS total_employees

FROM employees

GROUP BY
    country,
    city,
    title

ORDER BY
    total_employees DESC,
    country,
    city;

-- 7. What trends can we observe in hire dates across employee titles?

SELECT
    title,

    MIN(hiredate) AS first_hire_date,

    MAX(hiredate) AS latest_hire_date,

    COUNT(employeeid) AS total_employees,

    ROUND(
        AVG(
            EXTRACT(YEAR FROM hiredate)
        ),
        0
    ) AS avg_hire_year

FROM employees

GROUP BY title

ORDER BY first_hire_date;



-- 8. What patterns exist in employee title and courtesy title distributions?

SELECT
    title,
    titleofcourtesy,

    COUNT(employeeid) AS total_employees,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_distribution

FROM employees

GROUP BY
    title,
    titleofcourtesy

ORDER BY
    total_employees DESC;


-- 9. Are there correlations between product pricing, stock levels, and sales performance?

SELECT
    p.productid,
    p.productname,
    c.categoryname,

    p.unitprice AS product_price,
    p.unitsinstock AS stock_level,

    COUNT(DISTINCT od.orderid) AS total_orders,

    SUM(od.quantity) AS total_quantity_sold,

    ROUND(
        SUM(
            od.unitprice *
            od.quantity *
            (1 - od.discount)
        ),
        2
    ) AS total_revenue,

    ROUND(
        AVG(od.quantity),
        2
    ) AS avg_quantity_per_order

FROM products p

LEFT JOIN order_details od
    ON p.productid = od.productid

LEFT JOIN categories c
    ON p.categoryid = c.categoryid

GROUP BY
    p.productid,
    p.productname,
    c.categoryname,
    p.unitprice,
    p.unitsinstock

ORDER BY total_revenue DESC;




-- 10. How does product demand change over months or seasons?


SELECT
    EXTRACT(YEAR FROM o.orderdate) AS order_year,

    TO_CHAR(o.orderdate, 'Month') AS month_name,

    CASE
        WHEN EXTRACT(MONTH FROM o.orderdate) IN (12, 1, 2)
            THEN 'Winter'

        WHEN EXTRACT(MONTH FROM o.orderdate) IN (3, 4, 5)
            THEN 'Spring'

        WHEN EXTRACT(MONTH FROM o.orderdate) IN (6, 7, 8)
            THEN 'Summer'

        ELSE 'Autumn'
    END AS season,

    COUNT(DISTINCT o.orderid) AS total_orders,

    SUM(od.quantity) AS total_quantity_sold,

    ROUND(
        SUM(
            od.unitprice *
            od.quantity *
            (1 - od.discount)
        ),
        2
    ) AS total_revenue

FROM orders o

JOIN order_details od
    ON o.orderid = od.orderid

GROUP BY
    EXTRACT(YEAR FROM o.orderdate),
    EXTRACT(MONTH FROM o.orderdate),
    TO_CHAR(o.orderdate, 'Month')

ORDER BY
    order_year,
    EXTRACT(MONTH FROM o.orderdate);



-- 11. Can we identify anomalies in product sales or revenue performance?

WITH product_sales AS (

    SELECT
        p.productid,
        p.productname,

        SUM(
            od.unitprice *
            od.quantity *
            (1 - od.discount)
        ) AS total_revenue,

        SUM(od.quantity) AS total_quantity

    FROM products p

    LEFT JOIN order_details od
        ON p.productid = od.productid

    GROUP BY
        p.productid,
        p.productname
),

stats AS (

    SELECT
        AVG(total_revenue) AS avg_revenue,
        STDDEV(total_revenue) AS std_revenue

    FROM product_sales
)

SELECT
    ps.productid,
    ps.productname,

    ROUND(ps.total_revenue, 2) AS total_revenue,

    ps.total_quantity,

    CASE
        WHEN ps.total_revenue >
             s.avg_revenue + (2 * s.std_revenue)
            THEN 'High Revenue Anomaly'

        WHEN ps.total_revenue <
             s.avg_revenue - (2 * s.std_revenue)
            THEN 'Low Revenue Anomaly'

        ELSE 'Normal'
    END AS revenue_status

FROM product_sales ps
CROSS JOIN stats s

ORDER BY
    ps.total_revenue DESC;



-- 12. Are there any regional trends in supplier distribution and pricing?

SELECT
    s.country,
    s.city,

    COUNT(DISTINCT s.supplierid) AS total_suppliers,

    COUNT(p.productid) AS total_products,

    ROUND(
        AVG(p.unitprice),
        2
    ) AS avg_product_price,

    ROUND(
        MIN(p.unitprice),
        2
    ) AS min_price,

    ROUND(
        MAX(p.unitprice),
        2
    ) AS max_price,

    ROUND(
        SUM(p.unitprice),
        2
    ) AS total_price_value

FROM suppliers s

LEFT JOIN products p
    ON s.supplierid = p.supplierid

GROUP BY
    s.country,
    s.city

ORDER BY
    avg_product_price DESC,
    total_products DESC;



-- 13. How are suppliers distributed across different product categories?

SELECT
    c.categoryid,
    c.categoryname,

    COUNT(DISTINCT s.supplierid) AS total_suppliers,

    COUNT(p.productid) AS total_products,

    ROUND(
        COUNT(p.productid)::NUMERIC
        /
        COUNT(DISTINCT s.supplierid),
        2
    ) AS avg_products_per_supplier

FROM categories c

LEFT JOIN products p
    ON c.categoryid = p.categoryid

LEFT JOIN suppliers s
    ON p.supplierid = s.supplierid

GROUP BY
    c.categoryid,
    c.categoryname

ORDER BY
    total_suppliers DESC,
    total_products DESC;




-- 14. How do supplier pricing and categories relate across different regions?


SELECT
    s.country,
    s.city,

    c.categoryname,

    COUNT(DISTINCT s.supplierid) AS total_suppliers,

    COUNT(p.productid) AS total_products,

    ROUND(
        AVG(p.unitprice),
        2
    ) AS avg_product_price,

    ROUND(
        MIN(p.unitprice),
        2
    ) AS min_price,

    ROUND(
        MAX(p.unitprice),
        2
    ) AS max_price,

    ROUND(
        SUM(p.unitprice),
        2
    ) AS total_price_value

FROM suppliers s

JOIN products p
    ON s.supplierid = p.supplierid

JOIN categories c
    ON p.categoryid = c.categoryid

GROUP BY
    s.country,
    s.city,
    c.categoryname

ORDER BY
    avg_product_price DESC,
    total_products DESC;



















