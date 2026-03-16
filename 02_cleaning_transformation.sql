/*
=====================================================================================================
    File        : 02_cleaning_transformation.sql
    Project     : 
    Description : Data cleaning and transformation operations
                  Covers: Duplicate removal, casing standardization,
                          text cleaning, column transformation
    Tables      : customer_journey, customer_reviews, engagement_data
    Note        : Creates new cleaned tables - original tables unchanged

    Validation Summary (from 01_validation.sql)
    ─────────────────────────────────────────────────────────────────────
    Table               | Issue                        | Action
    --------------------|------------------------------|------------------
    customer_journey    | 79 logical duplicates        | Removed
    customer_journey    | 613 NULL duration            | Documented
    customer_journey    | Stage casing inconsistency   | Standardized
    customer_reviews    | Leading/trailing spaces      | TRIM()
    customer_reviews    | Double spaces in text        | REPLACE()
    engagement_data     | ContentType casing           | Standardized
    engagement_data     | ViewsClicksCombined          | Split to INT
    All other tables    | No issues found              | None
    ─────────────────────────────────────────────────────────────────────
=====================================================================================================
*/



-- ============================================
-- 1. REMOVE DUPLICATES - customer_journey
-- ============================================

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

select 
JourneyID,
CustomerID,
ProductID,
VisitDate,
Stage,
Action,
Duration
into dbo.customer_journey_cleaned
from duplicates
where rnk = 1  
-- Result: 3932 rows inserted into customer_journey_cleaned
-- 79 duplicate rows removed from original 4011 rows

-- ============================================
-- 2. STANDARDIZE CASING - customer_journey_cleaned
-- ============================================

update [dbo].[customer_journey_cleaned]
set Stage =
case 
	when upper(Stage) = 'CHECKOUT' THEN 'Checkout'
	when upper(Stage)=  'HOMEPAGE' THEN 'Homepage'
	when upper(Stage) = 'PRODUCTPAGE' THEN 'ProductPage'
	else Stage 
	end 
from [dbo].[customer_journey_cleaned]

-- Result: Stage standardized to 3 consistent values
-- Checkout, Homepage, ProductPage

-- ============================================
-- 3. SPLIT ViewsClicksCombined + CASING - engagement_data
-- ============================================


select 
 EngagementID,
 ContentID,
 case 
	when upper(ContentType)='BLOG' then 'Blog'
	when upper(ContentType)='SOCIALMEDIA' then 'Socialmedia'
	when upper(ContentType)='VIDEO' then 'Video'
	when upper(ContentType)='NEWSLETTER' then 'Newsletter'
	else ContentType
	end as ContentType,
likes,
convert(date,EngagementDate) as  EngagementDate,
CampaignID,
ProductID,
convert(int ,LEFT(ViewsClicksCombined, CHARINDEX('-', ViewsClicksCombined) - 1)) AS Views,
convert(int,right(ViewsClicksCombined,len(ViewsClicksCombined)- CHARINDEX('-', ViewsClicksCombined))) as clicks
INTO dbo.engagement_data_cleaned
from [dbo].[engagement_data]

-- Result: 4623 rows inserted into engagement_data_cleaned
-- ViewsClicksCombined split into Views and Clicks (INT)
-- ContentType standardized to consistent casing

-- ============================================
-- 4. CLEAN REVIEWTEXT - customer_reviews
-- ============================================


select
ReviewID,
CustomerID,
ProductID,
ReviewDate,
Rating,
trim(replace(ReviewText,'  ',' ')) as ReviewText
into  dbo.customer_reviews_cleaned
from [dbo].[customer_reviews]

-- Result: 1363 rows inserted into customer_reviews_cleaned
-- TRIM() removed leading/trailing spaces
-- REPLACE() fixed double spaces between words
-- Note: Further text normalization handled in Python using regex