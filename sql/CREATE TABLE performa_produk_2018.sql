--CREATE TABLE performa_produk_2018 AS
WITH product_summary AS (
    SELECT 
        COALESCE(pt.product_category_name_english, 'Unknown') AS product_category_english,
        -- Mempertahankan kolom awal rincian bulanan
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 1 THEN 1 ELSE 0 END) AS total_sold_jan_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 2 THEN 1 ELSE 0 END) AS total_sold_feb_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 3 THEN 1 ELSE 0 END) AS total_sold_mar_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 4 THEN 1 ELSE 0 END) AS total_sold_apr_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 5 THEN 1 ELSE 0 END) AS total_sold_may_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 6 THEN 1 ELSE 0 END) AS total_sold_jun_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 7 THEN 1 ELSE 0 END) AS total_sold_jul_2018,
        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 8 THEN 1 ELSE 0 END) AS total_sold_aug_2018,

        SUM(CASE WHEN EXTRACT(MONTH FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) BETWEEN 1 AND 8 THEN 1 ELSE 0 END) AS total_sold,
        
        SUM(oi.price) AS total_revenue,
        SUM(oi.freight_value) AS total_freight_cost,
        SUM(oi.price - oi.freight_value) AS net_profit,
        
        ROUND(
            (SUM(oi.price - oi.freight_value) * 100.0 / NULLIF(SUM(oi.price), 0))::NUMERIC, 
            2
        ) AS profit_margin,

        -- Integrasi rata-rata skor ulasan
        ROUND(AVG(r.avg_order_review)::NUMERIC, 2) AS avg_review_score
    FROM 
        olist_orders o
    JOIN 
        olist_order_items oi ON o.order_id = oi.order_id
    JOIN 
        olist_products p ON oi.product_id = p.product_id
    LEFT JOIN 
        olist_product_category_name_translation pt ON p.product_category_name = pt.product_category_name
    -- Subquery untuk mengamankan data agar tidak terjadi duplikasi akibat relasi review
    LEFT JOIN (
        SELECT order_id, AVG(review_score) AS avg_order_review
        FROM olist_order_reviews
        GROUP BY order_id
    ) r ON o.order_id = r.order_id
    WHERE 
        EXTRACT(YEAR FROM CAST(o.order_purchase_timestamp AS TIMESTAMP)) = 2018
        AND o.order_status = 'delivered'
    GROUP BY 
        1
),
metrics_calculated AS (
    SELECT *,
        (
            COALESCE((total_sold_feb_2018 - total_sold_jan_2018)::NUMERIC / NULLIF(total_sold_jan_2018, 0), 0) +
            COALESCE((total_sold_mar_2018 - total_sold_feb_2018)::NUMERIC / NULLIF(total_sold_feb_2018, 0), 0) +
            COALESCE((total_sold_apr_2018 - total_sold_mar_2018)::NUMERIC / NULLIF(total_sold_mar_2018, 0), 0) +
            COALESCE((total_sold_may_2018 - total_sold_apr_2018)::NUMERIC / NULLIF(total_sold_apr_2018, 0), 0) +
            COALESCE((total_sold_jun_2018 - total_sold_may_2018)::NUMERIC / NULLIF(total_sold_may_2018, 0), 0) +
            COALESCE((total_sold_jul_2018 - total_sold_jun_2018)::NUMERIC / NULLIF(total_sold_jun_2018, 0), 0) +
            COALESCE((total_sold_aug_2018 - total_sold_jul_2018)::NUMERIC / NULLIF(total_sold_jul_2018, 0), 0)
        ) / 7.0 AS avg_growth_rate
    FROM product_summary
),
quartiles_calculated AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY total_sold) AS q_volume,
        NTILE(4) OVER (ORDER BY profit_margin) AS q_margin,
        NTILE(4) OVER (ORDER BY avg_growth_rate) AS q_growth,
        -- Tambahan pembagian kuartil ulasan secara objektif
        NTILE(4) OVER (ORDER BY avg_review_score) AS q_review
    FROM metrics_calculated
)
SELECT 
    product_category_english,
    total_sold_jan_2018, total_sold_feb_2018, total_sold_mar_2018, total_sold_apr_2018,
    total_sold_may_2018, total_sold_jun_2018, total_sold_jul_2018, total_sold_aug_2018,
    total_sold, total_revenue, total_freight_cost, net_profit, profit_margin, avg_growth_rate,
    avg_review_score, 
    q_volume, q_margin, q_growth, q_review,
    CASE 
        -- Logika klasifikasi berimbang melibatkan performa finansial + kepuasan pelanggan
        WHEN q_volume >= 3 AND q_margin >= 3 AND q_growth >= 3 AND q_review >= 3 THEN 'Best Performance'
        WHEN q_volume <= 2 AND q_margin = 4 AND q_growth >= 3 AND q_review = 4 THEN 'Hidden Gem'
        WHEN q_volume >= 3 AND q_margin >= 3 AND q_growth <= 2 THEN 'Sleeper'
        WHEN q_volume = 1 AND q_growth = 1 THEN 'Low Performance'
        ELSE 'Regular Performance'
    END AS performance_label
FROM quartiles_calculated
ORDER BY performance_label, total_sold DESC;