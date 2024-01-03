-- creating the table

CREATE TABLE youtube (
    rank INT,
    youtuber VARCHAR(255),
    subscribers BIGINT,
    video_views BIGINT,
    category VARCHAR(255),
    title VARCHAR(255),
    uploads INT,
    country VARCHAR(255),
    abbreviation VARCHAR(10),
    channel_type VARCHAR(255),
    video_views_rank INT,
    country_rank INT,
    channel_type_rank INT,
    video_views_for_the_last_30_days BIGINT,
    lowest_monthly_earnings DECIMAL(18, 2),
    highest_monthly_earnings DECIMAL(18, 2),
    lowest_yearly_earnings DECIMAL(18, 2),
    highest_yearly_earnings DECIMAL(18, 2),
    subscribers_for_last_30_days BIGINT,
    created_year INT,
    created_month INT,
    created_date DATE,
    gross_tertiary_education_enrollment DECIMAL(5, 2),
    population BIGINT,
    unemployment_rate DECIMAL(5, 2),
    urban_population BIGINT,
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6)
);

-- fixing issues with the data

ALTER TABLE youtube
ALTER COLUMN created_month TYPE VARCHAR(255);

UPDATE youtube
SET created_month = NULL
WHERE NOT created_month ~ '^\d+$';

-- replacing missing numeric characters with null

UPDATE youtube
SET 
    subscribers = NULLIF(subscribers, 0),
    video_views = NULLIF(video_views, 0),
    uploads = NULLIF(uploads, 0),
    video_views_rank = NULLIF(video_views_rank, 0),
    country_rank = NULLIF(country_rank, 0),
    channel_type_rank = NULLIF(channel_type_rank, 0),
    video_views_for_the_last_30_days = NULLIF(video_views_for_the_last_30_days, 0),
    lowest_monthly_earnings = NULLIF(lowest_monthly_earnings, 0),
    highest_monthly_earnings = NULLIF(highest_monthly_earnings, 0),
    lowest_yearly_earnings = NULLIF(lowest_yearly_earnings, 0),
    highest_yearly_earnings = NULLIF(highest_yearly_earnings, 0),
    subscribers_for_last_30_days = NULLIF(subscribers_for_last_30_days, 0),
    Population = NULLIF(Population, 0),
    Unemployment_rate = NULLIF(Unemployment_rate, 0),
    Urban_population = NULLIF(Urban_population, 0)
WHERE 1=1;

-- cleaning the text fields and replacing empty fields with nulls

UPDATE youtube
SET 
    Youtuber = TRIM(Youtuber),
    Country = TRIM(Country),
    Abbreviation = TRIM(Abbreviation),
    channel_type = TRIM(channel_type),
    category = TRIM(category)
WHERE 1=1;

UPDATE youtube
SET 
    Youtuber = COALESCE(Youtuber, 'null'),
    Country = COALESCE(Country, 'null'),
    Abbreviation = COALESCE(Abbreviation, 'null'),
    channel_type = COALESCE(channel_type, 'null'),
	category = COALESCE(category, 'null')

WHERE 1=1;

UPDATE youtube
SET 
    Youtuber = NULLIF(Youtuber, 'null'),
    Country = NULLIF(Country, 'null'),
    Abbreviation = NULLIF(Abbreviation, 'null'),
    channel_type = NULLIF(channel_type, 'null'),
    category = NULLIF(category, 'null');

-- we can begin querying

-- count of youtubers per category

SELECT
	category,
	COUNT(*) AS channels_count
FROM youtube
WHERE category IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC

-- most popular categories by subscribers

SELECT
	category,
	SUM(subscribers) AS total_subs
FROM youtube
WHERE category IS NOT NULL
GROUP BY category 
ORDER BY total_subs DESC

-- most popular category by views per video

SELECT
	category,
	ROUND(SUM(video_views) / SUM(uploads)) AS avg_views_per_video
FROM youtube
WHERE category IS NOT NULL
GROUP BY category
ORDER BY avg_views_per_video DESC

-- average monthly income per category

SELECT 
	category,
	ROUND(AVG(highest_monthly_earnings)) AS average_income
FROM youtube
WHERE category IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC

-- top youtuber earnings from each category

WITH sub AS
	(SELECT
		category,
		youtuber,
		ROUND(highest_monthly_earnings) AS highest_monthly_earnings,
		RANK() OVER(PARTITION BY category ORDER BY highest_yearly_earnings DESC) AS top_earner
	FROM youtube
	WHERE highest_monthly_earnings IS NOT NULL)
	
SELECT
	category,
	youtuber,
	highest_monthly_earnings
FROM sub
WHERE top_earner = 1 AND category IS NOT NULL
ORDER BY highest_monthly_earnings DESC

--exploring the top countries by total number of channels and subscribers

SELECT
	COUNTRY,
	COUNT(*) AS channels_count,
	SUM(subscribers) AS total_subscribers
FROM youtube
WHERE country IS NOT NULL
GROUP BY 1
ORDER BY channels_count DESC

-- exploring the correlation between channels count per country and population

WITH top_countries AS
	(SELECT
	COUNTRY,
	COUNT(*) AS channels_count,
	SUM(subscribers)
FROM youtube
WHERE country IS NOT NULL
GROUP BY 1
ORDER BY channels_count DESC)


SELECT
  CORR(channels_count, Population) AS correlation_population
FROM
  youtube AS y
JOIN top_countries AS t
ON y.COUNTRY = t.COUNTRY -- lower positive correlation result

-- top youtuber by avg views per video

SELECT
	youtuber,
	uploads,
	ROUND(video_views / uploads) AS avg_views_per_video
FROM youtube
WHERE video_views IS NOT NULL AND uploads IS NOT NULL AND youtuber IS NOT NULL AND
		uploads > 5
ORDER BY avg_views_per_video DESC

-- exploring top youtubers by views as opposed to rank by subsrcibers

SELECT corr(rank, video_views)
FROM youtube -- somewhat negative correlation

-- most views in the last 30 days

SELECT 
	youtuber,
	video_views_for_the_last_30_days
FROM youtube
WHERE video_views_for_the_last_30_days IS NOT NULL
		AND youtuber IS NOT NULL
ORDER BY video_views_for_the_last_30_days DESC

-- correlation between uploads and avg views per video

WITH channel_stats AS (
    SELECT
        Youtuber,
        uploads,
        ROUND(SUM(video_views) / NULLIF(uploads, 0), 2) AS avg_views_per_video
    FROM
        youtube
    WHERE
        Youtuber IS NOT NULL
    GROUP BY
        Youtuber, uploads
    ORDER BY
        uploads
    LIMIT 1000
)
SELECT
    uploads,
    ROUND(AVG(avg_views_per_video)) AS average_views_per_video
FROM
    channel_stats
GROUP BY
    uploads
ORDER BY
    uploads;
	
-- The difference between subs ranking and total views ranking

WITH sub AS
	(SELECT
		youtuber,
		subscribers,
		video_views,
	 	uploads,
		rank AS subs_ranking,
		RANK() OVER(ORDER BY video_views DESC) AS views_rank
	FROM youtube
	WHERE video_views IS NOT NULL AND youtuber IS NOT NULL)

SELECT 
	youtuber,
	uploads,
	subscribers,
	video_views,
	subs_ranking,
	views_rank,
	ROUND(((subs_ranking - views_rank) / 977.0) * 100, 2) || '%' AS percentage_difference
FROM sub
ORDER BY subscribers DESC;

-- Top 10 fastest growing youtube channels

SELECT
	youtuber,
	subscribers_for_last_30_days / 1000000 || 'mil' AS monthly_subs_growth_in_mil
FROM youtube
WHERE subscribers_for_last_30_days IS NOT NULL
ORDER BY subscribers_for_last_30_days DESC
LIMIT 10;

-- top 10 fastest growing youtube channels relative to subscribers count

SELECT
	youtuber,
	CAST(subscribers_for_last_30_days AS FLOAT) / subscribers AS subs_growth_rate
FROM youtube
WHERE subscribers_for_last_30_days IS NOT NULL
ORDER BY subs_growth_rate DESC
LIMIT 10;

-- Answering the question- how long until Mr beast surpasses T-series in subscribers count?

WITH RECURSIVE subscriber_growth AS (
    SELECT
        'Mr Beast' AS youtuber,
        166000000 AS current_subscribers_mrbeast,
        8000000 AS monthly_growth_mrbeast,
        'T-Series' AS competitor,
        245000000 AS current_subscribers_tseries,
        2000000 AS monthly_growth_tseries,
        0 AS months_passed
    UNION ALL
    SELECT
        youtuber,
        current_subscribers_mrbeast + monthly_growth_mrbeast,
        monthly_growth_mrbeast,
        competitor,
        current_subscribers_tseries + monthly_growth_tseries,
        monthly_growth_tseries,
        months_passed + 1
    FROM
        subscriber_growth
    WHERE
        current_subscribers_mrbeast + monthly_growth_mrbeast < current_subscribers_tseries
)
SELECT
    youtuber,
    
    monthly_growth_mrbeast,
    competitor,
    
    monthly_growth_tseries,
    months_passed
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY youtuber ORDER BY months_passed DESC) as rn
    FROM
        subscriber_growth
) ranked
WHERE
    rn = 1;




