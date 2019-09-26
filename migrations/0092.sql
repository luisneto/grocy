ALTER TABLE products
ADD cumulate_min_stock_amount_of_subproducts TINYINT DEFAULT 0;

CREATE VIEW products_view
AS
SELECT *, CASE WHEN (SELECT 1 FROM products WHERE parent_product_id = p.id) NOTNULL THEN 1 ELSE 0 END AS has_sub_products
FROM products p;

DROP VIEW stock_missing_products;
CREATE VIEW stock_missing_products
AS

-- Products which are not sub products and not with "cumulate_min_stock_amount_of_subproducts"
SELECT
	p.id,
	MAX(p.name) AS name,
	p.min_stock_amount - IFNULL(SUM(s.amount), 0) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
LEFT JOIN stock_current s
	ON p.id = s.product_id
WHERE p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 0
	AND p.parent_product_id IS NULL
GROUP BY p.id
HAVING IFNULL(SUM(s.amount), 0) < p.min_stock_amount

UNION

-- Products which have sub products and with "cumulate_min_stock_amount_of_subproducts"
SELECT
	p.id,
	MAX(p.name) AS name,
	SUM(sub_p.min_stock_amount) - IFNULL(SUM(s.amount), 0) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
JOIN products_resolved pr
	ON p.id = pr.parent_product_id
JOIN products sub_p
	ON pr.sub_product_id = sub_p.id
LEFT JOIN stock_current s
	ON pr.sub_product_id = s.product_id
WHERE sub_p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 1
	AND p.has_sub_products IS NOT NULL
GROUP BY p.id
HAVING IFNULL(SUM(s.amount), 0) < SUM(sub_p.min_stock_amount)

UNION

-- Sub products where the parent product has not "cumulate_min_stock_amount_of_subproducts"
SELECT
	sub_p.id,
	MAX(sub_p.name) AS name,
	SUM(sub_p.min_stock_amount) - IFNULL(SUM(s.amount), 0) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
JOIN products_resolved pr
	ON p.id = pr.parent_product_id
JOIN products sub_p
	ON pr.sub_product_id = sub_p.id
LEFT JOIN stock_current s
	ON pr.sub_product_id = s.product_id
WHERE sub_p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 0
	AND sub_p.parent_product_id IS NOT NULL
GROUP BY sub_p.id
HAVING IFNULL(SUM(s.amount), 0) < sub_p.min_stock_amount;

DROP VIEW stock_missing_products_including_opened;
CREATE VIEW stock_missing_products_including_opened
AS

/* This is basically the same view as stock_missing_products, but the column amount_missing includes opened amounts */

-- Products which are not sub products and not with "cumulate_min_stock_amount_of_subproducts"
SELECT
	p.id,
	MAX(p.name) AS name,
	p.min_stock_amount - (IFNULL(SUM(s.amount), 0) - IFNULL(SUM(s.amount_opened), 0)) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
LEFT JOIN stock_current s
	ON p.id = s.product_id
WHERE p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 0
	AND p.parent_product_id IS NULL
GROUP BY p.id
HAVING IFNULL(SUM(s.amount), 0) < p.min_stock_amount

UNION

-- Products which have sub products and with "cumulate_min_stock_amount_of_subproducts"
SELECT
	p.id,
	MAX(p.name) AS name,
	SUM(sub_p.min_stock_amount) - (IFNULL(SUM(s.amount), 0) - IFNULL(SUM(s.amount_opened), 0)) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
JOIN products_resolved pr
	ON p.id = pr.parent_product_id
JOIN products sub_p
	ON pr.sub_product_id = sub_p.id
LEFT JOIN stock_current s
	ON pr.sub_product_id = s.product_id
WHERE sub_p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 1
	AND p.has_sub_products IS NOT NULL
GROUP BY p.id
HAVING IFNULL(SUM(s.amount), 0) < SUM(sub_p.min_stock_amount)

UNION

-- Sub products where the parent product has not "cumulate_min_stock_amount_of_subproducts"
SELECT
	sub_p.id,
	MAX(sub_p.name) AS name,
	SUM(sub_p.min_stock_amount) - (IFNULL(SUM(s.amount), 0) - IFNULL(SUM(s.amount_opened), 0)) AS amount_missing,
	CASE WHEN IFNULL(SUM(s.amount), 0) > 0 THEN 1 ELSE 0 END AS is_partly_in_stock
FROM products_view p
JOIN products_resolved pr
	ON p.id = pr.parent_product_id
JOIN products sub_p
	ON pr.sub_product_id = sub_p.id
LEFT JOIN stock_current s
	ON pr.sub_product_id = s.product_id
WHERE sub_p.min_stock_amount != 0
	AND p.cumulate_min_stock_amount_of_subproducts = 0
	AND sub_p.parent_product_id IS NOT NULL
GROUP BY sub_p.id
HAVING IFNULL(SUM(s.amount), 0) < sub_p.min_stock_amount;
