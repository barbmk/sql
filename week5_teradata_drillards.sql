-- Some time ago I finished a course on Coursera on how to manage Big Data with MySQL. This was the last assignment of the course, done using Teradata and the Dillard's database. I think that the assignment was great to learn so I decided to publish my responses.

-- Exercise 1. How many distinct dates are there in the saledate column of the transaction table for each month/year combination in the database?

SELECT EXTRACT(YEAR from saledate) AS y, EXTRACT(MONTH from saledate) AS m, COUNT(DISTINCT saledate) as num_days
FROM trnsact
GROUP BY y, m
ORDER BY y, m;

-- Exercise 2. Use a CASE statement within an aggregate function to determine which sku had the greatest total sales during the combined summer months of June, July, and August.

SELECT sku, sum(amt) AS sales
FROM trnsact
WHERE stype = 'p' AND EXTRACT(MONTH from saledate) IN (6, 7, 8)
GROUP BY sku
ORDER BY sales DESC;

-- Exercise 3. How many distinct dates are there in the saledate column of the transaction table for each month/year/store combination in the database? Sort your results by the number of days per combination in ascending order.

SELECT EXTRACT(YEAR from saledate) AS y, EXTRACT(MONTH from saledate) AS m, store, COUNT(DISTINCT saledate) as num_days
FROM trnsact
GROUP BY y, m, store
ORDER BY num_days;

-- Exercise 4. What is the average daily revenue for each store/month/year combination in the database? Calculate this by dividing the total revenue for a group by the number of sales days available in the transaction table for that group.

SELECT store, my, num_days, sales, sales/ num_days as avg_daily_sales
FROM
  (SELECT store, EXTRACT(MONTH FROM saledate)|| EXTRACT(YEAR FROM saledate) as my, COUNT(DISTINCT saledate) as num_days, SUM(amt) as sales
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY store, my
  HAVING num_days > 19) AS sales
ORDER BY num_days

-- Exercise 5. What is the average daily revenue brought in by Dillard’s stores in areas of high, medium, or low levels of high school education?

SELECT level_high.level, SUM(sales.sales)/SUM(sales.num_days) as avg_daily_sales
FROM
  (SELECT store, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, SUM(amt) as sales, COUNT(DISTINCT saledate) as num_days
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY store, my
  HAVING num_days > 19) as sales
JOIN
  (SELECT store, (CASE WHEN msa_high >= 50 AND msa_high<= 60 THEN 'Low'
  WHEN msa_high > 60 AND msa_high<= 70 THEN 'Medium'
  WHEN msa_high > 70 THEN 'High'
  ELSE 'error' END) as level
  FROM store_msa
  GROUP BY store, level) as level_high
ON sales.store=level_high.store
GROUP BY level_high.level;

-- Exercise 6. Compare the average daily revenues of the stores with the highest median msa_income and the lowest median msa_income. In what city and state were these stores, and which store had a higher average daily revenue?

SELECT level_high.store, level_high.level, SUM(sales.sales)/SUM(sales.num_days) as rev_per_day, level_high.city, level_high.state
FROM
  (SELECT store, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, SUM(amt) as sales, COUNT(DISTINCT saledate) as num_days
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY store, my
  HAVING num_days > 19) as sales
JOIN
  (SELECT store, (CASE WHEN msa_high >= 50 AND msa_high<= 60 THEN 'Low'
  WHEN msa_high > 60 AND msa_high<= 70 THEN 'Medium'
  WHEN msa_high > 70 THEN 'High'
  ELSE 'error' END) as level, city, state
  FROM store_msa
  GROUP BY store, level, city, state) as level_high
ON sales.store=level_high.store
LEFT JOIN
  (SELECT store, city, state, SUM(inc) as top_inc
  FROM (SELECT TOP 1 store, SUM(msa_income) as inc, SUM(msa_high) as hs, city, state
  FROM store_msa
  GROUP BY store, city, state
  ORDER BY inc DESC) as top_one
  GROUP BY store, city, state) as top_one_store
ON sales.store=top_one_store.store
LEFT JOIN
  (SELECT store, city, state, SUM(inc) as bottom_inc
  FROM (SELECT TOP 1 store, SUM(msa_income) as inc, SUM(msa_high) as hs, city, state
  FROM store_msa
  GROUP BY store, city, state
  ORDER BY inc) as bottom_one
  GROUP BY store, city, state) as bottom_one_store
ON sales.store=bottom_one_store.store
WHERE top_inc IS NOT NULL OR bottom_inc IS NOT NULL
GROUP BY level_high.store, level_high.level, level_high.city, level_high.state;


-- Exercise 7: What is the brand of the sku with the greatest standard deviation in sprice? Only examine skus that have been part of over 100 transactions.

SELECT trn.sku, sku_info.brand, trn.std_price as std_price
FROM
  (SELECT top 1 sku, COUNT(DISTINCT saledate) as tran_num, STDDEV_SAMP(sprice) as std_price
  FROM trnsact
  GROUP BY sku
  HAVING tran_num > 100
  ORDER BY std_price DESC) as trn
JOIN
  (SELECT sku, brand
    FROM skuinfo) as sku_info
ON trn.sku=sku_info.sku
GROUP BY trn.sku, sku_info.brand, std_price;

-- Exercise 8: Examine all the transactions for the sku with the greatest standard deviation in sprice, but only consider skus that are part of more than 100 transactions.

SELECT sku, saledate, SUM(sprice)/SUM(quantity) as sale_p, SUM(orgprice)/SUM(quantity) as orig_p, orig_p-sale_p
FROM trnsact
WHERE sku = 3733090
GROUP BY sku, saledate
ORDER BY saledate;

-- Exercise 10: Which department, in which city and state of what store, had the greatest % increase in average daily sales revenue from November to December?

SELECT TOP 1 store, dept, city, state, SUM(nov_sales)/SUM(nov_numdays) as avg_daily_sales_nov, SUM(dec_sales)/SUM(dec_numdays) as avg_daily_sales_dec, ((avg_daily_sales_dec- avg_daily_sales_nov)/ avg_daily_sales_nov)*100 as perc_change
FROM
  (SELECT nov.store, nov.sku, s.dept, str.city, str.state, SUM(nov.num_days) as nov_numdays, SUM(dece.num_days) as dec_numdays, SUM(nov.sales) as nov_sales, SUM(dece.sales) as dec_sales
  FROM
    (SELECT store, sku, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, EXTRACT(YEAR from saledate) as y, EXTRACT(MONTH from saledate) as m
    FROM trnsact
    WHERE stype = 'p'
    GROUP BY store, my, y, m, sku
    HAVING num_days > 19 AND m IN 11) as nov
  JOIN
    (SELECT store, sku, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, EXTRACT(YEAR from saledate) as y, EXTRACT(MONTH from saledate) as m
    FROM trnsact
    WHERE stype = 'p'
    GROUP BY store, my, y, m, sku
    HAVING num_days > 19 AND m IN 12) as dece
  ON nov.store=dece.store AND nov.sku=dece.sku
  JOIN
    skuinfo s ON nov.sku=s.sku
  JOIN
    strinfo str ON nov.store=str.store
    GROUP BY nov.store, dece.store, nov.sku, dece.sku, s.dept, str.city, str.state) as nov_dec
GROUP BY store, dept, city, state
ORDER BY perc_change DESC;

-- Exercise 11: What is the city and state of the store that had the greatest decrease in average daily revenue from August to September?

SELECT TOP 1 store, city, state, SUM(aug_sales)/SUM(aug_numdays) as avg_daily_sales_aug, SUM(sept_sales)/SUM(sept_numdays) as avg_daily_sales_sept,
avg_daily_sales_sept- avg_daily_sales_aug as rev_change
FROM
  (SELECT aug.store, str.city, str.state, SUM(aug.num_days) as aug_numdays, SUM(sept.num_days) as sept_numdays, SUM(aug.sales) as aug_sales, SUM(sept.sales) as sept_sales
  FROM
    (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, EXTRACT(YEAR from saledate) as y, EXTRACT(MONTH from saledate) as m
    FROM trnsact
    WHERE stype = 'p'
    GROUP BY store, my, y, m
    HAVING num_days > 19 AND m IN 8 AND y IN 2004) as aug
  JOIN
    (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, EXTRACT(YEAR from saledate) as y, EXTRACT(MONTH from saledate) as m
    FROM trnsact
    WHERE stype = 'p'
    GROUP BY store, my, y, m
    HAVING num_days > 19 AND m IN 9) as sept
  ON aug.store=sept.store
  JOIN
    strinfo str ON aug.store=str.store
    GROUP BY aug.store, sept.store, str.city, str.state) as aug_sept
GROUP BY store, city, state
ORDER BY rev_change;

-- Exercise 12: Determine the month of maximum total revenue for each store. Count the number of stores whose month of maximum total revenue was in each of the twelve months. Then determine the month of maximum average daily revenue. Count the number of stores whose month of maximum average daily revenue was in each of the twelve months. How do they compare?

SELECT store, my, ranking
FROM
  (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, RANK() OVER (PARTITION BY store ORDER BY sales DESC ) AS ranking
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY my, store
  HAVING num_days > 19) as rankings
WHERE ranking IN (1)
GROUP BY store, my, ranking;

SELECT my, COUNT(my) as num_mon
FROM
  (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, RANK() OVER (PARTITION BY store ORDER BY sales DESC ) AS ranking
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY store, my
  HAVING num_days > 19) as rankings
WHERE ranking IN (1)
GROUP BY my;

SELECT store, my, ranking, SUM(avg_sales) AS avg_sales
FROM
  (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, sales/num_days as avg_sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, RANK() OVER (PARTITION BY store ORDER BY avg_sales DESC ) AS ranking
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY my, store
  HAVING num_days > 19) as rankings
WHERE ranking IN (1)
GROUP BY store, my, ranking;

SELECT my, COUNT(my)
FROM
  (SELECT store, COUNT(DISTINCT saledate) as num_days, SUM(sprice) as sales, sales/num_days as avg_sales, EXTRACT(MONTH from saledate)||EXTRACT(YEAR from saledate) as my, RANK() OVER (PARTITION BY store ORDER BY avg_sales DESC ) AS ranking
  FROM trnsact
  WHERE stype = 'p' AND saledate < '2005-08-01'
  GROUP BY my, store
  HAVING num_days > 19) as rankings
WHERE ranking IN (1)
GROUP BY my, ranking;
