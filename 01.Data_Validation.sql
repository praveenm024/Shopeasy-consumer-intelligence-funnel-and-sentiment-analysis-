use shopeasy
go
/*
=====================================================================================================
    File        : 01_validation.sql
    Project     : 
    Description : Data validation checks across all tables
                  Covers: Row counts, NULL checks, Duplicate checks, 
                          Zero value checks 
    Tables      : customer_journey, customer_reviews, engagement_data,
                  customers, geography, products
    Note        : READ ONLY - No data is modified in this file

        
 Validation Summary
    =====================================================================================================
    Table               | Column                | Issue                        | Action
    --------------------|-----------------------|------------------------------|----------------------
    customer_journey    | Duration              | 613 NULLs - all Drop-offs    | Document - intentional
    customer_journey    | JourneyID             | 79 logical duplicates        | Remove - keep rnk = 1
    customer_journey    | Stage                 | Casing inconsistency         | Standardize - UPPER()
    customer_journey    | Action                | Casing inconsistency         | Standardize - UPPER()
    customer_reviews    | ReviewText            | Leading/trailing spaces      | TRIM()
    customer_reviews    | ReviewText            | Double spaces between words  | REPLACE()
    engagement_data     | ContentType           | 3 casing variants per value  | Standardize - UPPER()
    engagement_data     | ViewsClicksCombined   | Two metrics in one column    | Split into Views+Clicks
    All other tables    | All columns           | No issues found              | None
    =====================================================================================================
*/


-- ============================================
-- 1 CUSTOMER JOURNEY TABLE
-- ============================================

 -- NULL Checks
SELECT 
    COUNT(*) AS total_rows,--4011 rows
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
	SUM(CASE WHEN ProductID IS NULL THEN 1 ELSE 0 END) AS null_product_id,
	SUM(CASE WHEN VisitDate IS NULL THEN 1 ELSE 0 END) AS null_visite_date ,
    SUM(CASE WHEN stage IS NULL THEN 1 ELSE 0 END) AS null_stage,
    SUM(CASE WHEN action IS NULL THEN 1 ELSE 0 END) AS null_action,
	SUM(CASE WHEN Duration IS NULL THEN 1 ELSE 0 END) AS null_duration -- 613 nulls 
FROM dbo.customer_journey;


-- Broader NULL duration query 
SELECT 
count(*) as total_rows,
Action, 
stage 
FROM customer_journey 
where  Duration is null
group by action ,stage 
go

-- Duplicate Check 
with duplicates as -- used a CTE's for finding duplicates 
(select 
	JourneyID,
	CustomerID,
	ProductID,
	VisitDate,
	Stage,
	Action,
	Duration,
  row_number() -- Use ROW_NUMBER() to assign a unique row number to each record within the partition defined below
	over(partition by CustomerID,ProductID,VisitDate,Stage,Action order by  JourneyID ) as rnk 
	  
from customer_journey)

select * from duplicates 
where rnk>1

-- Force case sensitive comparison
SELECT DISTINCT Stage COLLATE Latin1_General_CS_AS
FROM dbo.customer_journey

-- Force case sensitive comparison
SELECT DISTINCT action COLLATE Latin1_General_CS_AS
FROM dbo.customer_journey

-- =====================================================================================================
-- 2. CUSTOMER REVIEWS TABLE
-- =====================================================================================================

--  NULL Checks

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN CustomerID  IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN ProductID   IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN ReviewDate  IS NULL THEN 1 ELSE 0 END) AS null_review_date,
    SUM(CASE WHEN Rating      IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN ReviewText  IS NULL THEN 1 ELSE 0 END) AS null_review_text
FROM dbo.customer_reviews;


-- Rating Range Check it Should be between 1 and 5

SELECT COUNT(*) AS invalid_ratings
FROM dbo.customer_reviews
WHERE Rating < 1 OR Rating > 5;


--  Duplicate Check - Same customer reviewing same product on same date
WITH duplicates AS (
    SELECT
        ReviewID, CustomerID, ProductID, ReviewDate, Rating, ReviewText,
        ROW_NUMBER() OVER (
            PARTITION BY CustomerID, ProductID, ReviewDate
            ORDER BY ReviewID
        ) AS rnk
    FROM dbo.customer_reviews
)
SELECT * FROM duplicates WHERE rnk > 1;


-- =====================================================================================================
-- 3. CUSTOMER ENGAGEMENT TABLE
-- =====================================================================================================


--  NULL Checks
SELECT
    COUNT(*)                                                        AS total_rows,
  
    SUM(CASE WHEN ContentType    IS NULL THEN 1 ELSE 0 END)        AS null_content_type,
     SUM(CASE WHEN Likes          IS NULL THEN 1 ELSE 0 END)        AS null_likes,
     SUM(CASE WHEN EngagementDate IS NULL THEN 1 ELSE 0 END)        AS null_engagement_date,
 SUM(CASE WHEN ViewsClicksCombined IS NULL THEN 1 ELSE 0 END)   AS null_views_clicks
    
FROM dbo.engagement_data;

--  Duplicate Check
WITH duplicates AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY  ContentID,ProductID,EngagementDate,CampaignID,ContentType
            ORDER BY EngagementID
        ) AS rnk
    FROM dbo.engagement_data
)
SELECT * FROM duplicates WHERE rnk > 1;

-- Force case sensitive comparison
SELECT   distinct ContentType COLLATE Latin1_General_CS_AS
FROM [dbo].[engagement_data]

/*  ViewsClicksCombined → needs to be split into:
    - Views  (passive engagement)
    - Clicks (active engagement) */


-- =====================================================================================================
-- 4. CUSTOMERS TABLE (Dimension)
-- =====================================================================================================



-- NULL Checks 
SELECT
    COUNT(*)                                                        AS total_rows,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END)            AS null_customer_id,
    SUM(CASE WHEN CustomerName IS NULL THEN 1 ELSE 0 END)            AS null_customer_name,
    SUM(CASE WHEN Age        IS NULL THEN 1 ELSE 0 END)            AS null_age,
    SUM(CASE WHEN Gender     IS NULL THEN 1 ELSE 0 END)            AS null_gender
    
FROM dbo.customers;

-- Age Sanity Check - Realistic age range
SELECT COUNT(*) AS invalid_age
FROM dbo.customers
WHERE Age < 18 OR Age > 100;


-- =====================================================================================================
-- 5. GEOGRAPHY TABLE (Dimension)
-- =====================================================================================================


-- NULL Checks 
SELECT
    COUNT(*)                                                        AS total_rows,
    SUM(CASE WHEN GeographyID IS NULL THEN 1 ELSE 0 END)           AS null_geography_id,
    SUM(CASE WHEN Country     IS NULL THEN 1 ELSE 0 END)           AS null_country,
    SUM(CASE WHEN City        IS NULL THEN 1 ELSE 0 END)           AS null_city
FROM dbo.geography;



-- =====================================================================================================
-- 6. PRODUCTS TABLE (Dimension)
-- =====================================================================================================


-- NULL Checks
SELECT
    COUNT(*)                                                        AS total_rows,
    SUM(CASE WHEN ProductID       IS NULL THEN 1 ELSE 0 END)       AS null_product_id,
    SUM(CASE WHEN ProductName     IS NULL THEN 1 ELSE 0 END)       AS null_product_name,
    SUM(CASE WHEN Category        IS NULL THEN 1 ELSE 0 END)       AS null_category,
    SUM(CASE WHEN Price           IS NULL THEN 1 ELSE 0 END)       AS null_price
FROM dbo.products;

--  Zero Value Checks - Price should never be zero
SELECT COUNT(*) AS zero_price FROM dbo.products WHERE Price = 0;

