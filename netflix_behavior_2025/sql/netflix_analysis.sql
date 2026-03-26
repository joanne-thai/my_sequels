-- Netflix User Behavior: beginner-friendly MySQL workflow
-- This script uses four tables from the dataset folder:
--   users.csv
--   movies.csv
--   watch_history.csv
--   reviews.csv
--
-- The workflow is split into:
-- 1. Raw table creation
-- 2. CSV import instructions
-- 3. Simple cleaning views
-- 4. Basic analysis queries
--
-- Notes:
-- - Raw tables store CSV values as text to keep importing simple.
-- - Cleaned views convert data types, handle blanks, and remove exact duplicates.
-- - The Python workflow in this project is intentionally separate and does its own cleaning.

CREATE DATABASE IF NOT EXISTS netflix_user_behavior_portfolio;
USE netflix_user_behavior_portfolio;

DROP VIEW IF EXISTS reviews_clean;
DROP VIEW IF EXISTS watch_history_clean;
DROP VIEW IF EXISTS movies_clean;
DROP VIEW IF EXISTS users_clean;

DROP TABLE IF EXISTS reviews_raw;
DROP TABLE IF EXISTS watch_history_raw;
DROP TABLE IF EXISTS movies_raw;
DROP TABLE IF EXISTS users_raw;

-- --------------------------------------------------------------------
-- 1. Raw tables
-- --------------------------------------------------------------------

CREATE TABLE users_raw (
    user_id VARCHAR(50),
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    age VARCHAR(50),
    gender VARCHAR(50),
    country VARCHAR(50),
    state_province VARCHAR(100),
    city VARCHAR(100),
    subscription_plan VARCHAR(50),
    subscription_start_date VARCHAR(50),
    is_active VARCHAR(20),
    monthly_spend VARCHAR(50),
    primary_device VARCHAR(50),
    household_size VARCHAR(50),
    created_at VARCHAR(50)
);

CREATE TABLE movies_raw (
    movie_id VARCHAR(50),
    title VARCHAR(255),
    content_type VARCHAR(100),
    genre_primary VARCHAR(100),
    genre_secondary VARCHAR(100),
    release_year VARCHAR(50),
    duration_minutes VARCHAR(50),
    rating VARCHAR(20),
    language VARCHAR(50),
    country_of_origin VARCHAR(100),
    imdb_rating VARCHAR(50),
    production_budget VARCHAR(50),
    box_office_revenue VARCHAR(50),
    number_of_seasons VARCHAR(50),
    number_of_episodes VARCHAR(50),
    is_netflix_original VARCHAR(20),
    added_to_platform VARCHAR(50),
    content_warning VARCHAR(20)
);

CREATE TABLE watch_history_raw (
    session_id VARCHAR(50),
    user_id VARCHAR(50),
    movie_id VARCHAR(50),
    watch_date VARCHAR(50),
    device_type VARCHAR(50),
    watch_duration_minutes VARCHAR(50),
    progress_percentage VARCHAR(50),
    action VARCHAR(50),
    quality VARCHAR(50),
    location_country VARCHAR(50),
    is_download VARCHAR(20),
    user_rating VARCHAR(50)
);

CREATE TABLE reviews_raw (
    review_id VARCHAR(50),
    user_id VARCHAR(50),
    movie_id VARCHAR(50),
    rating VARCHAR(50),
    review_date VARCHAR(50),
    device_type VARCHAR(50),
    is_verified_watch VARCHAR(20),
    helpful_votes VARCHAR(50),
    total_votes VARCHAR(50),
    review_text TEXT,
    sentiment VARCHAR(50),
    sentiment_score VARCHAR(50)
);

-- --------------------------------------------------------------------
-- 2. CSV import instructions
-- --------------------------------------------------------------------
-- Option A: MySQL Workbench
-- - Open this schema in MySQL Workbench.
-- - Run the CREATE TABLE statements above.
-- - Use "Table Data Import Wizard" to import each CSV into its matching *_raw table.
--
-- Option B: LOAD DATA LOCAL INFILE
-- - Update the file paths so they match your local machine.
-- - Some MySQL setups require LOCAL INFILE to be enabled.
-- - If secure_file_priv blocks the import, use the Workbench import wizard instead.

-- Example import for users.csv
-- LOAD DATA LOCAL INFILE '~/netflix_behavior_2025/dataset/users.csv'
-- INTO TABLE users_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- Example import for movies.csv
-- LOAD DATA LOCAL INFILE '~/netflix_behavior_2025/dataset/movies.csv'
-- INTO TABLE movies_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- Example import for watch_history.csv
-- LOAD DATA LOCAL INFILE '~/netflix_behavior_2025/dataset/watch_history.csv'
-- INTO TABLE watch_history_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- Example import for reviews.csv
-- LOAD DATA LOCAL INFILE '~/netflix_behavior_2025/dataset/reviews.csv'
-- INTO TABLE reviews_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- --------------------------------------------------------------------
-- 3. Quick inspection of the raw data
-- --------------------------------------------------------------------

SELECT * FROM users_raw LIMIT 10;
SELECT * FROM movies_raw LIMIT 10;
SELECT * FROM watch_history_raw LIMIT 10;
SELECT * FROM reviews_raw LIMIT 10;

-- Simple duplicate checks before cleaning.
SELECT COUNT(*) AS raw_user_rows FROM users_raw;
SELECT COUNT(*) AS raw_movie_rows FROM movies_raw;
SELECT COUNT(*) AS raw_watch_rows FROM watch_history_raw;
SELECT COUNT(*) AS raw_review_rows FROM reviews_raw;

-- --------------------------------------------------------------------
-- 4. Cleaning views
-- --------------------------------------------------------------------
-- These views:
-- - remove exact duplicates with DISTINCT
-- - trim text values
-- - convert text columns to useful data types
-- - handle blank values and common text standardization
-- - filter obvious invalid rows

CREATE OR REPLACE VIEW users_clean AS
SELECT DISTINCT
    TRIM(user_id) AS user_id,
    TRIM(email) AS email,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    CASE
        WHEN NULLIF(TRIM(age), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(age) AS DECIMAL(5,1))
        ELSE NULL
    END AS age,
    COALESCE(NULLIF(TRIM(gender), ''), 'Unknown') AS gender,
    CASE
        WHEN UPPER(TRIM(country)) IN ('USA', 'US', 'UNITED STATES') THEN 'USA'
        WHEN UPPER(TRIM(country)) = 'CANADA' THEN 'Canada'
        ELSE TRIM(country)
    END AS country,
    TRIM(state_province) AS state_province,
    TRIM(city) AS city,
    CASE
        WHEN TRIM(subscription_plan) IN ('Basic', 'Standard', 'Premium', 'Premium+') THEN TRIM(subscription_plan)
        ELSE 'Unknown'
    END AS subscription_plan,
    STR_TO_DATE(NULLIF(TRIM(subscription_start_date), ''), '%Y-%m-%d') AS subscription_start_date,
    CASE
        WHEN UPPER(TRIM(is_active)) = 'TRUE' THEN 1
        WHEN UPPER(TRIM(is_active)) = 'FALSE' THEN 0
        ELSE NULL
    END AS is_active,
    CASE
        WHEN NULLIF(TRIM(monthly_spend), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(monthly_spend) AS DECIMAL(10,2))
        ELSE NULL
    END AS monthly_spend,
    COALESCE(NULLIF(TRIM(primary_device), ''), 'Unknown') AS primary_device,
    CASE
        WHEN NULLIF(TRIM(household_size), '') REGEXP '^[0-9]+$'
            THEN CAST(TRIM(household_size) AS UNSIGNED)
        ELSE NULL
    END AS household_size,
    STR_TO_DATE(NULLIF(TRIM(created_at), ''), '%Y-%m-%d %H:%i:%s.%f') AS created_at
FROM users_raw
WHERE NULLIF(TRIM(user_id), '') IS NOT NULL
  AND (
      NULLIF(TRIM(age), '') IS NULL
      OR (
          NULLIF(TRIM(age), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
          AND CAST(TRIM(age) AS DECIMAL(5,1)) BETWEEN 10 AND 100
      )
  );

CREATE OR REPLACE VIEW movies_clean AS
SELECT DISTINCT
    TRIM(movie_id) AS movie_id,
    TRIM(title) AS title,
    COALESCE(NULLIF(TRIM(content_type), ''), 'Unknown') AS content_type,
    COALESCE(NULLIF(TRIM(genre_primary), ''), 'Unknown') AS genre_primary,
    COALESCE(NULLIF(TRIM(genre_secondary), ''), 'Unknown') AS genre_secondary,
    CASE
        WHEN NULLIF(TRIM(release_year), '') REGEXP '^[0-9]+$'
            THEN CAST(TRIM(release_year) AS UNSIGNED)
        ELSE NULL
    END AS release_year,
    CASE
        WHEN NULLIF(TRIM(duration_minutes), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(duration_minutes) AS DECIMAL(8,1))
        ELSE NULL
    END AS duration_minutes,
    COALESCE(NULLIF(TRIM(rating), ''), 'Unknown') AS rating,
    COALESCE(NULLIF(TRIM(language), ''), 'Unknown') AS language,
    COALESCE(NULLIF(TRIM(country_of_origin), ''), 'Unknown') AS country_of_origin,
    CASE
        WHEN NULLIF(TRIM(imdb_rating), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(imdb_rating) AS DECIMAL(3,1))
        ELSE NULL
    END AS imdb_rating,
    CASE
        WHEN NULLIF(TRIM(production_budget), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(production_budget) AS DECIMAL(15,2))
        ELSE NULL
    END AS production_budget,
    CASE
        WHEN NULLIF(TRIM(box_office_revenue), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(box_office_revenue) AS DECIMAL(15,2))
        ELSE NULL
    END AS box_office_revenue,
    CASE
        WHEN NULLIF(TRIM(number_of_seasons), '') REGEXP '^[0-9]+$'
            THEN CAST(TRIM(number_of_seasons) AS UNSIGNED)
        ELSE NULL
    END AS number_of_seasons,
    CASE
        WHEN NULLIF(TRIM(number_of_episodes), '') REGEXP '^[0-9]+$'
            THEN CAST(TRIM(number_of_episodes) AS UNSIGNED)
        ELSE NULL
    END AS number_of_episodes,
    CASE
        WHEN UPPER(TRIM(is_netflix_original)) = 'TRUE' THEN 1
        WHEN UPPER(TRIM(is_netflix_original)) = 'FALSE' THEN 0
        ELSE NULL
    END AS is_netflix_original,
    STR_TO_DATE(NULLIF(TRIM(added_to_platform), ''), '%Y-%m-%d') AS added_to_platform,
    CASE
        WHEN UPPER(TRIM(content_warning)) = 'TRUE' THEN 1
        WHEN UPPER(TRIM(content_warning)) = 'FALSE' THEN 0
        ELSE NULL
    END AS content_warning
FROM movies_raw
WHERE NULLIF(TRIM(movie_id), '') IS NOT NULL;

CREATE OR REPLACE VIEW watch_history_clean AS
SELECT DISTINCT
    TRIM(session_id) AS session_id,
    TRIM(user_id) AS user_id,
    TRIM(movie_id) AS movie_id,
    STR_TO_DATE(NULLIF(TRIM(watch_date), ''), '%Y-%m-%d') AS watch_date,
    COALESCE(NULLIF(TRIM(device_type), ''), 'Unknown') AS device_type,
    CASE
        WHEN NULLIF(TRIM(watch_duration_minutes), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(watch_duration_minutes) AS DECIMAL(8,1))
        ELSE NULL
    END AS watch_duration_minutes,
    CASE
        WHEN NULLIF(TRIM(progress_percentage), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(progress_percentage) AS DECIMAL(5,1))
        ELSE NULL
    END AS progress_percentage,
    COALESCE(NULLIF(TRIM(action), ''), 'Unknown') AS action,
    COALESCE(NULLIF(TRIM(quality), ''), 'Unknown') AS quality,
    CASE
        WHEN UPPER(TRIM(location_country)) IN ('USA', 'US', 'UNITED STATES') THEN 'USA'
        WHEN UPPER(TRIM(location_country)) = 'CANADA' THEN 'Canada'
        ELSE TRIM(location_country)
    END AS location_country,
    CASE
        WHEN UPPER(TRIM(is_download)) = 'TRUE' THEN 1
        WHEN UPPER(TRIM(is_download)) = 'FALSE' THEN 0
        ELSE NULL
    END AS is_download,
    CASE
        WHEN NULLIF(TRIM(user_rating), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(user_rating) AS DECIMAL(3,1))
        ELSE NULL
    END AS user_rating
FROM watch_history_raw
WHERE NULLIF(TRIM(session_id), '') IS NOT NULL
  AND (
      NULLIF(TRIM(watch_duration_minutes), '') IS NULL
      OR (
          NULLIF(TRIM(watch_duration_minutes), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
          AND CAST(TRIM(watch_duration_minutes) AS DECIMAL(8,1)) BETWEEN 0 AND 720
      )
  )
  AND (
      NULLIF(TRIM(progress_percentage), '') IS NULL
      OR (
          NULLIF(TRIM(progress_percentage), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
          AND CAST(TRIM(progress_percentage) AS DECIMAL(5,1)) BETWEEN 0 AND 100
      )
  );

CREATE OR REPLACE VIEW reviews_clean AS
SELECT DISTINCT
    TRIM(review_id) AS review_id,
    TRIM(user_id) AS user_id,
    TRIM(movie_id) AS movie_id,
    CASE
        WHEN NULLIF(TRIM(rating), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(rating) AS DECIMAL(3,1))
        ELSE NULL
    END AS rating,
    STR_TO_DATE(NULLIF(TRIM(review_date), ''), '%Y-%m-%d') AS review_date,
    COALESCE(NULLIF(TRIM(device_type), ''), 'Unknown') AS device_type,
    CASE
        WHEN UPPER(TRIM(is_verified_watch)) = 'TRUE' THEN 1
        WHEN UPPER(TRIM(is_verified_watch)) = 'FALSE' THEN 0
        ELSE NULL
    END AS is_verified_watch,
    CASE
        WHEN NULLIF(TRIM(helpful_votes), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(helpful_votes) AS DECIMAL(10,1))
        ELSE NULL
    END AS helpful_votes,
    CASE
        WHEN NULLIF(TRIM(total_votes), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(total_votes) AS DECIMAL(10,1))
        ELSE NULL
    END AS total_votes,
    review_text,
    COALESCE(NULLIF(TRIM(sentiment), ''), 'Unknown') AS sentiment,
    CASE
        WHEN NULLIF(TRIM(sentiment_score), '') REGEXP '^[-]?[0-9]+(\\.[0-9]+)?$'
            THEN CAST(TRIM(sentiment_score) AS DECIMAL(5,3))
        ELSE NULL
    END AS sentiment_score
FROM reviews_raw
WHERE NULLIF(TRIM(review_id), '') IS NOT NULL
  AND (
      NULLIF(TRIM(rating), '') IS NULL
      OR (
          NULLIF(TRIM(rating), '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
          AND CAST(TRIM(rating) AS DECIMAL(3,1)) BETWEEN 1 AND 5
      )
  );

-- Check the cleaned data after duplicate removal and type conversion.
SELECT COUNT(*) AS cleaned_user_rows FROM users_clean;
SELECT COUNT(*) AS cleaned_movie_rows FROM movies_clean;
SELECT COUNT(*) AS cleaned_watch_rows FROM watch_history_clean;
SELECT COUNT(*) AS cleaned_review_rows FROM reviews_clean;

-- --------------------------------------------------------------------
-- 5. Basic analysis queries
-- --------------------------------------------------------------------

-- Total watch time by subscription type
SELECT
    u.subscription_plan,
    ROUND(SUM(w.watch_duration_minutes), 2) AS total_watch_time_minutes
FROM watch_history_clean AS w
JOIN users_clean AS u
    ON w.user_id = u.user_id
WHERE w.watch_duration_minutes IS NOT NULL
GROUP BY u.subscription_plan
ORDER BY total_watch_time_minutes DESC;

-- Average watch time by genre
SELECT
    m.genre_primary,
    ROUND(AVG(w.watch_duration_minutes), 2) AS average_watch_time_minutes
FROM watch_history_clean AS w
JOIN movies_clean AS m
    ON w.movie_id = m.movie_id
WHERE w.watch_duration_minutes IS NOT NULL
GROUP BY m.genre_primary
ORDER BY average_watch_time_minutes DESC;

-- User count by country
SELECT
    country,
    COUNT(*) AS user_count
FROM users_clean
GROUP BY country
ORDER BY user_count DESC;

-- Average review rating by device
SELECT
    device_type,
    ROUND(AVG(rating), 2) AS average_rating
FROM reviews_clean
WHERE rating IS NOT NULL
GROUP BY device_type
ORDER BY average_rating DESC;

-- Engagement summary by age group using a CTE
WITH age_group_summary AS (
    SELECT
        CASE
            WHEN u.age BETWEEN 10 AND 17 THEN '10-17'
            WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
            WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
            WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
            WHEN u.age >= 55 THEN '55+'
            ELSE 'Unknown'
        END AS age_group,
        w.session_id,
        w.watch_duration_minutes,
        w.progress_percentage
    FROM users_clean AS u
    JOIN watch_history_clean AS w
        ON u.user_id = w.user_id
    WHERE u.age IS NOT NULL
)
SELECT
    age_group,
    COUNT(DISTINCT session_id) AS total_sessions,
    ROUND(AVG(watch_duration_minutes), 2) AS average_watch_time_minutes,
    ROUND(AVG(progress_percentage), 2) AS average_progress_percentage
FROM age_group_summary
GROUP BY age_group
ORDER BY total_sessions DESC;

-- Top genres by total watch time using a CTE
WITH genre_watch_time AS (
    SELECT
        m.genre_primary,
        SUM(w.watch_duration_minutes) AS total_watch_time_minutes
    FROM watch_history_clean AS w
    JOIN movies_clean AS m
        ON w.movie_id = m.movie_id
    WHERE w.watch_duration_minutes IS NOT NULL
    GROUP BY m.genre_primary
)
SELECT
    genre_primary,
    ROUND(total_watch_time_minutes, 2) AS total_watch_time_minutes
FROM genre_watch_time
ORDER BY total_watch_time_minutes DESC
LIMIT 10;
