/*
Northwind Database

The below SQL queries (PostGres SQL) explore the Northwind database to answer specific queries posed by fictional sales, logistics and HR teams.

Skills used: Joins, Window Functions, Aggregate Functions, Case Statements, Converting Data Types, Concatenation, Nested Queries

*/


--Question 1: Return product names and unit prices which are not discontinued and have a unit price between 10 and 50, ordered by product name in alphabetical order.

SELECT 	
	product_name,
	unit_price AS product_unit_price
FROM northwind.products
WHERE unit_price BETWEEN 10 AND 50 
AND discontinued = 0
ORDER BY product_name ASC

/*Question 2: Provide a list of countries with their average days between the order date and the shipping date (2 decimals) and their total number of unique orders.
The year of order date is 1997, the average days between the order date and the shipping date is greater or equal to 3 days but less than 20 days, and total number of orders is greater than 5.
Results to be ordered by the average days between the order date and the shipping date in descending order.*/

SELECT 	
	ship_country AS shipping_country,
	AVG(shipped_date - order_date)::DECIMAL(50,2) AS average_days_between_order_shipping,
	COUNT(DISTINCT order_id) AS total_volume_orders
FROM northwind.orders
WHERE EXTRACT(year FROM order_date) = 1997
GROUP BY shipping_country
HAVING AVG(shipped_date - order_date)::DECIMAL(50,2) >= 3
AND AVG(shipped_date - order_date)::DECIMAL(50,2) < 20
AND COUNT(DISTINCT order_id) > 5
ORDER BY average_days_between_order_shipping DESC

/*Question 3: For each employee, provide their full name (first name and last name combined in a single field), job title, age at the time of hire, tenure in years until current date, 
manager full name (first name and last name combined in a single field), and manager job title, results to be ordered by employee age and employee full name in an ascending order.*/

SELECT
	a.first_name || ' ' || a.last_name AS employee_full_name,
	a.title AS employee_title,
	EXTRACT(year FROM AGE(a.hire_date, a.birth_date)) AS employee_age,
	EXTRACT(year FROM AGE(CURRENT_DATE, a.hire_date)) AS employee_tenure,
	b.first_name || ' ' || b.last_name AS manager_full_name,
	b.title AS manager_title
FROM northwind.employees a
LEFT JOIN northwind.employees b ON a.reports_to = b.employee_id
ORDER BY employee_age ASC, employee_full_name ASC

/*Question 4: Review global global performance over 1996-1997. Provide a list with the year/month as single field in a date format (e.g. “1996-01-01” for January 1996), total number of orders, and total freight (formatted to no decimals).
Filtered by order date between 1996 and 1997, total number of orders is greater than 20, and total freight is greater than 2500, results ordered by total freight (descending order).*/

SELECT
	to_char(date_trunc('month',order_date),'YYYY-MM-01') AS year_month,
	COUNT(order_id) AS total_number_orders,
	SUM(freight)::DECIMAL(100,0) AS total_freight
FROM northwind.orders
WHERE order_date >= '1996-01-01'
AND order_date <= '1997-12-31'
GROUP BY year_month
HAVING COUNT(order_id) > 20
AND SUM(freight)::DECIMAL(100,0) > 2500
ORDER BY total_freight DESC

/*Question 5: Provide a list of products which had a unit price increase and the percentage increase was not between 10% and 30%, as well as their current and initial unit price (formatted to 2 decimals), 
and their percentage increase (formatted to 4 decimals). Oorder the results by percentage increase (ascending order).*/

SELECT 
tb3.product_name,
tb3.current_price,
tb3.previous_unit_price,
((tb3.current_price / tb3.previous_unit_price) -1)::DECIMAL(50,4) AS percentage_increase
FROM(
	SELECT
	tb1.product_name AS product_name,
	tb1.unit_price AS current_price,
	tb2.previous_unit_price,
	((tb1.unit_price / tb2.previous_unit_price) -1)::DECIMAL(50,4) AS percentage_increase
	FROM (
		SELECT 
			a.product_name,
			b.unit_price::DECIMAL(50,2),
			c.order_date,
			ROW_NUMBER() OVER (PARTITION BY a.product_name ORDER BY c.order_date DESC) row_num_last
		FROM northwind.products a
		LEFT JOIN northwind.order_details b ON a.product_id = b.product_id
		LEFT JOIN northwind.orders c ON b.order_id = c.order_id
		) tb1
JOIN(
	SELECT
	z.product_name,
	y.unit_price::DECIMAL(50,2) AS previous_unit_price,
	ROW_NUMBER() OVER (PARTITION BY z.product_name ORDER BY x.order_date ASC) row_num_earliest
	FROM northwind.products z
	LEFT JOIN northwind.order_details y ON z.product_id = y.product_id
	LEFT JOIN northwind.orders x ON y.order_id = x.order_id
	) tb2 
	ON tb1.product_name = tb2.product_name
WHERE row_num_last = 1
AND tb2.row_num_earliest = 1) tb3
WHERE tb3.percentage_increase NOT BETWEEN 0.1 AND 0.3
ORDER BY tb3.percentage_increase ASC

/*Question 6: Provide a list of categories with their price range grouped as "1. Below $10”, “2. $10 - $20”, “3. $20 - $50”, “4. Over $50”. Also proced the total amount (formatted to 2 decimals) taking into account the offered discount,
and volume of orders per category. Results to be ordered by category name then price range (both ascending order).*/

SELECT
a.category_name AS category_name,
CASE
	WHEN c.unit_price < 10 THEN '1. Below $10'
	WHEN c.unit_price >= 10 AND c.unit_price <= 20 THEN '2. $10 - $20'
	WHEN c.unit_price > 20 AND c.unit_price <= 50 THEN '3. $20 - $50'
	WHEN c.unit_price > 50 THEN '4. Over $50'
	ELSE 'Other'
END price_range,
SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity)::DECIMAL(50,2) AS total_amount,
COUNT(DISTINCT(c.order_id)) AS total_number_orders
FROM northwind.categories a
LEFT JOIN northwind.products b ON a.category_id = b.category_id
LEFT JOIN northwind.order_details c ON b.product_id = c.product_id
GROUP BY category_name, price_range
ORDER BY category_name ASC, price_range ASC

/*Question 7: In order to review regional suppliers, provide a list of categories with the supplier region as “America”, “Europe”, “Asia”, “Oceania”, their total units in stock, total units on order and total reorder level.
Order the results by supplier region, then category name and reorder level (each in ascending order).*/

SELECT
a.category_name AS category_name,
CASE
	WHEN c.country in ('Canada', 'USA', 'Brazil') THEN 'America' 
	WHEN c.country in ('UK', 'Spain', 'Germany', 'Norway', 'France', 'Sweden', 'Finland', 'Netherlands', 'Italy', 'Denmark') THEN 'Europe'
	WHEN c.country in ('Japan', 'Singapore') THEN 'Asia'
	WHEN c.country in ('Australia') THEN 'Oceania'
	ELSE c.country
END supplier_region,
SUM(b.unit_in_stock) AS units_in_stock,
SUM(b.unit_on_order) AS units_on_order,
SUM(b.reorder_level) AS reorder_level 
FROM northwind.categories a
LEFT JOIN northwind.products b ON a.category_id = b.category_id
LEFT JOIN northwind.suppliers c ON b.supplier_id = c.supplier_id
GROUP BY category_name, supplier_region
ORDER BY supplier_region ASC, category_name ASC, reorder_level ASC

/*Question 8: For each currently offered product, compare their unit price against their categories average and median unit price. Provide them a list of products with:
product category name, product name, unit price, category average unit price (formatted to 2 decimals), category median unit price (2 decimals), their position against the category average unit price as “Below Average”, “Average”, “Over Average”,
and their position against the category median unit price as “Below Median”, “Median”, “Over Median”. Order the results by category name then product name (both ascending).*/

SELECT
a.category_name AS category_name,
b.product_name AS product_name,
b.unit_price AS unit_price,
AVG(b.unit_price) OVER(PARTITION BY a.category_name)::DECIMAL(50,2) AS average_unit_price,
median.median_unit_price,
CASE 
	WHEN b.unit_price < AVG(b.unit_price) OVER(PARTITION BY a.category_name) THEN 'Below Average'
	WHEN b.unit_price = AVG(b.unit_price) OVER(PARTITION BY a.category_name) THEN 'Average'
	WHEN b.unit_price > AVG(b.unit_price) OVER(PARTITION BY a.category_name) THEN 'Over Average'
END average_unit_price_position,
CASE 
	WHEN b.unit_price < median.median_unit_price THEN 'Below Median'
	WHEN b.unit_price = median.median_unit_price THEN 'Median'
	WHEN b.unit_price > median.median_unit_price THEN 'Over Median'
END median_unit_price_position
FROM northwind.categories a
LEFT JOIN northwind.products b ON a.category_id = b.category_id
JOIN (SELECT 
		a.category_name AS category_name,
		percentile_cont(0.50) within group (order by b.unit_price)::DECIMAL(50,2) AS median_unit_price
		FROM northwind.categories a
		LEFT JOIN northwind.products b ON a.category_id = b.category_id
		WHERE b.discontinued = 0
		GROUP BY category_name
		) median
	ON a.category_name = median.category_name
WHERE b.discontinued = 0
ORDER BY category_name ASC, product_name ASC

/*Question 9: To measure employees KPIS, provide a list of employees with their full name (first name and last name combined), job title, total sales amount excluding discount (2 decimals), total number of unique orders, total number of orders,
average product amount excluding discount (2 decimals), average order amount excluding discount (2 decimals), total discount amount (2 decimals), total sales amount including discount (2 decimals), and total discount percentage (2 decimals).
Results to be ordered by total sales amount including discount (descending).*/

SELECT
	a.first_name || ' ' || a.last_name AS employee_full_name,
	a.title AS employee_title,
	SUM(c.unit_price * c.quantity)::DECIMAL(50,2) AS total_sale_amount_excluding_discount,
	COUNT(DISTINCT(b.order_id)) AS number_unique_orders,
	COUNT(b.order_id) AS number_orders,
	AVG(c.unit_price * c.quantity)::DECIMAL(50,2) AS average_product_amount,
	(SUM(c.unit_price * c.quantity)::DECIMAL(50,2) / COUNT(DISTINCT(c.order_id)))::DECIMAL(50,2) AS average_order_amount,
	SUM((c.unit_price * c.quantity) - ((c.unit_price - (c.unit_price * c.discount)) * c.quantity))::DECIMAL(50,2) AS total_discount_amount,
	SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity)::DECIMAL(50,2) AS total_sale_amount_including_discount,
	((SUM((c.unit_price * c.quantity) - ((c.unit_price - (c.unit_price * c.discount)) * c.quantity)) / 
		SUM(c.unit_price * c.quantity)) * 100)::DECIMAL(50,2) AS total_discount_percentage
FROM northwind.employees a
LEFT JOIN northwind.orders b ON a.employee_id = b.employee_id
LEFT JOIN northwind.order_details c ON b.order_id = c.order_id
GROUP BY employee_full_name, employee_title
ORDER BY total_sale_amount_including_discount DESC

/*Question 10: In order to build another list of KPIs to measure employees' performances across each category, provide a list of category names, employee full name, their total sales amount including discount (2 decimals),
their percentage of total sales amount including discount against his/her total sales amount across all categories (formatted to have only 5 decimals and maximum value up to 1) and 
their percentage of total sales amount including discount against the total sales amount across all employees (formatted to have only 5 decimals and maximum value up to 1). Results ordered by category name (ascending) then total sales amount (descending).
*/

SELECT 
category_name,
employee_full_name,
total_sale_amount,
percent_of_employee_sales,
Percent_of_category_sales
	FROM (
		SELECT
			row_number() OVER (PARTITION BY e.category_name, a.first_name || ' ' || a.last_name) row_num,
			e.category_name AS category_name,
			a.first_name || ' ' || a.last_name AS employee_full_name,
			SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity) OVER(PARTITION BY e.category_name, a.first_name || ' ' || a.last_name)::DECIMAL(50,2) AS total_sale_amount,
			(SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity) OVER(PARTITION BY e.category_name, a.first_name || ' ' || a.last_name) / 
				SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity) OVER(PARTITION BY a.first_name || ' ' || a.last_name))::DECIMAL(50,5) AS percent_of_employee_sales,
			(SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity) OVER(PARTITION BY e.category_name, a.first_name || ' ' || a.last_name) / 
				SUM((c.unit_price - (c.unit_price * c.discount)) * c.quantity) OVER(PARTITION BY e.category_name))::DECIMAL(50,5) AS percent_of_category_sales 		
		FROM northwind.employees a
		LEFT JOIN northwind.orders b ON a.employee_id = b.employee_id
		LEFT JOIN northwind.order_details c ON b.order_id = c.order_id
		LEFT JOIN northwind.products d ON d.product_id = c.product_id
		LEFT JOIN northwind.categories e ON e.category_id = d.category_id
		) z
	WHERE row_num = 1 
	ORDER BY category_name ASC, total_sale_amount DESC