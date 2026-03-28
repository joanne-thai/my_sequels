-- Netflix User Behavior: post-import cleanup + analysis workflow
-- Prerequisite:
--   The raw tables already exist in the `netflix` database and the CSV data
--   has already been loaded into:
--   users, movies, watch_history, reviews
--
-- This script starts after import and does:
-- 1. Raw data inspection
-- 2. In-place value cleanup on the imported tables
-- 3. Replace unconvertible values with NULL
-- 4. In-place type conversion with ALTER TABLE
-- 5. Analysis queries using the base tables directly

CREATE DATABASE IF NOT EXISTS netflix;
USE netflix;

-- --------------------------------------------------------------------
-- 1. Quick inspection of the imported raw data
-- --------------------------------------------------------------------

SELECT COUNT(*) AS raw_user_rows FROM users;
SELECT COUNT(*) AS raw_movie_rows FROM movies;
SELECT COUNT(*) AS raw_watch_rows FROM watch_history;
SELECT COUNT(*) AS raw_review_rows FROM reviews;

SELECT * FROM users LIMIT 10;
SELECT * FROM movies LIMIT 10;
SELECT * FROM watch_history LIMIT 10;
SELECT * FROM reviews LIMIT 10;

-- --------------------------------------------------------------------
-- 2. Remove the old audit table if it exists
-- --------------------------------------------------------------------

DROP TABLE IF EXISTS data_correction_audit;

DROP FUNCTION IF EXISTS parse_date_flexible;
DROP FUNCTION IF EXISTS parse_datetime_flexible;

DELIMITER //

CREATE FUNCTION parse_date_flexible(input_value VARCHAR(50))
RETURNS DATE
DETERMINISTIC
BEGIN
    RETURN COALESCE(
        STR_TO_DATE(input_value, '%Y-%m-%d'),
        STR_TO_DATE(input_value, '%m/%d/%Y'),
        STR_TO_DATE(input_value, '%d/%m/%Y')
    );
END//

CREATE FUNCTION parse_datetime_flexible(input_value VARCHAR(50))
RETURNS DATETIME(6)
DETERMINISTIC
BEGIN
    RETURN COALESCE(
        STR_TO_DATE(input_value, '%Y-%m-%d %H:%i:%s.%f'),
        STR_TO_DATE(input_value, '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(input_value, '%Y-%m-%dT%H:%i:%s.%f'),
        STR_TO_DATE(input_value, '%Y-%m-%dT%H:%i:%s'),
        STR_TO_DATE(input_value, '%m/%d/%Y %H:%i:%s'),
        STR_TO_DATE(input_value, '%d/%m/%Y %H:%i:%s')
    );
END//

DELIMITER ;

-- --------------------------------------------------------------------
-- 3. In-place cleanup of imported values
-- --------------------------------------------------------------------
-- Trim text columns first, then normalize booleans, categories, dates, and
-- integer-like decimal strings so the later ALTER TABLE statements are safe.

UPDATE users
SET
    user_id = NULLIF(TRIM(user_id), ''),
    email = NULLIF(TRIM(email), ''),
    first_name = NULLIF(TRIM(first_name), ''),
    last_name = NULLIF(TRIM(last_name), ''),
    age = NULLIF(TRIM(age), ''),
    gender = COALESCE(NULLIF(TRIM(gender), ''), 'Unknown'),
    country = CASE
        WHEN NULLIF(TRIM(country), '') IS NULL THEN NULL
        WHEN UPPER(TRIM(country)) IN ('USA', 'US', 'UNITED STATES') THEN 'USA'
        WHEN UPPER(TRIM(country)) = 'CANADA' THEN 'Canada'
        ELSE TRIM(country)
    END,
    state_province = NULLIF(TRIM(state_province), ''),
    city = NULLIF(TRIM(city), ''),
    subscription_plan = CASE
        WHEN TRIM(subscription_plan) IN ('Basic', 'Standard', 'Premium', 'Premium+') THEN TRIM(subscription_plan)
        ELSE 'Unknown'
    END,
    subscription_start_date = NULLIF(TRIM(subscription_start_date), ''),
    is_active = CASE
        WHEN UPPER(TRIM(is_active)) = 'TRUE' THEN '1'
        WHEN UPPER(TRIM(is_active)) = 'FALSE' THEN '0'
        ELSE NULLIF(TRIM(is_active), '')
    END,
    monthly_spend = NULLIF(TRIM(monthly_spend), ''),
    primary_device = COALESCE(NULLIF(TRIM(primary_device), ''), 'Unknown'),
    household_size = CASE
        WHEN NULLIF(TRIM(household_size), '') REGEXP '^[0-9]+(\\.0+)?$'
            THEN CAST(CAST(TRIM(household_size) AS DECIMAL(10,0)) AS CHAR)
        ELSE NULLIF(TRIM(household_size), '')
    END,
    created_at = NULLIF(TRIM(created_at), '');

UPDATE movies
SET
    movie_id = NULLIF(TRIM(movie_id), ''),
    title = NULLIF(TRIM(title), ''),
    content_type = COALESCE(NULLIF(TRIM(content_type), ''), 'Unknown'),
    genre_primary = COALESCE(NULLIF(TRIM(genre_primary), ''), 'Unknown'),
    genre_secondary = COALESCE(NULLIF(TRIM(genre_secondary), ''), 'Unknown'),
    release_year = NULLIF(TRIM(release_year), ''),
    duration_minutes = NULLIF(TRIM(duration_minutes), ''),
    rating = COALESCE(NULLIF(TRIM(rating), ''), 'Unknown'),
    language = COALESCE(NULLIF(TRIM(language), ''), 'Unknown'),
    country_of_origin = COALESCE(NULLIF(TRIM(country_of_origin), ''), 'Unknown'),
    imdb_rating = NULLIF(TRIM(imdb_rating), ''),
    production_budget = NULLIF(TRIM(production_budget), ''),
    box_office_revenue = NULLIF(TRIM(box_office_revenue), ''),
    number_of_seasons = CASE
        WHEN NULLIF(TRIM(number_of_seasons), '') REGEXP '^[0-9]+(\\.0+)?$'
            THEN CAST(CAST(TRIM(number_of_seasons) AS DECIMAL(10,0)) AS CHAR)
        ELSE NULLIF(TRIM(number_of_seasons), '')
    END,
    number_of_episodes = CASE
        WHEN NULLIF(TRIM(number_of_episodes), '') REGEXP '^[0-9]+(\\.0+)?$'
            THEN CAST(CAST(TRIM(number_of_episodes) AS DECIMAL(10,0)) AS CHAR)
        ELSE NULLIF(TRIM(number_of_episodes), '')
    END,
    is_netflix_original = CASE
        WHEN UPPER(TRIM(is_netflix_original)) = 'TRUE' THEN '1'
        WHEN UPPER(TRIM(is_netflix_original)) = 'FALSE' THEN '0'
        ELSE NULLIF(TRIM(is_netflix_original), '')
    END,
    added_to_platform = NULLIF(TRIM(added_to_platform), ''),
    content_warning = CASE
        WHEN UPPER(TRIM(content_warning)) = 'TRUE' THEN '1'
        WHEN UPPER(TRIM(content_warning)) = 'FALSE' THEN '0'
        ELSE NULLIF(TRIM(content_warning), '')
    END;

UPDATE watch_history
SET
    session_id = NULLIF(TRIM(session_id), ''),
    user_id = NULLIF(TRIM(user_id), ''),
    movie_id = NULLIF(TRIM(movie_id), ''),
    watch_date = NULLIF(TRIM(watch_date), ''),
    device_type = COALESCE(NULLIF(TRIM(device_type), ''), 'Unknown'),
    watch_duration_minutes = NULLIF(TRIM(watch_duration_minutes), ''),
    progress_percentage = NULLIF(TRIM(progress_percentage), ''),
    action = COALESCE(NULLIF(TRIM(action), ''), 'Unknown'),
    quality = COALESCE(NULLIF(TRIM(quality), ''), 'Unknown'),
    location_country = CASE
        WHEN NULLIF(TRIM(location_country), '') IS NULL THEN NULL
        WHEN UPPER(TRIM(location_country)) IN ('USA', 'US', 'UNITED STATES') THEN 'USA'
        WHEN UPPER(TRIM(location_country)) = 'CANADA' THEN 'Canada'
        ELSE TRIM(location_country)
    END,
    is_download = CASE
        WHEN UPPER(TRIM(is_download)) = 'TRUE' THEN '1'
        WHEN UPPER(TRIM(is_download)) = 'FALSE' THEN '0'
        ELSE NULLIF(TRIM(is_download), '')
    END,
    user_rating = NULLIF(TRIM(user_rating), '');

UPDATE reviews
SET
    review_id = NULLIF(TRIM(review_id), ''),
    user_id = NULLIF(TRIM(user_id), ''),
    movie_id = NULLIF(TRIM(movie_id), ''),
    rating = NULLIF(TRIM(rating), ''),
    review_date = NULLIF(TRIM(review_date), ''),
    device_type = COALESCE(NULLIF(TRIM(device_type), ''), 'Unknown'),
    is_verified_watch = CASE
        WHEN UPPER(TRIM(is_verified_watch)) = 'TRUE' THEN '1'
        WHEN UPPER(TRIM(is_verified_watch)) = 'FALSE' THEN '0'
        ELSE NULLIF(TRIM(is_verified_watch), '')
    END,
    helpful_votes = NULLIF(TRIM(helpful_votes), ''),
    total_votes = NULLIF(TRIM(total_votes), ''),
    review_text = NULLIF(TRIM(review_text), ''),
    sentiment = COALESCE(NULLIF(TRIM(sentiment), ''), 'Unknown'),
    sentiment_score = NULLIF(TRIM(sentiment_score), '');

-- --------------------------------------------------------------------
-- 4. Replace unconvertible values with NULL
-- --------------------------------------------------------------------

UPDATE users
SET
    age = CASE WHEN age IS NOT NULL AND age NOT REGEXP '^[-]?[0-9]+(\\.[0-9]+)?$' THEN NULL ELSE age END,
    subscription_start_date = DATE_FORMAT(parse_date_flexible(subscription_start_date), '%Y-%m-%d'),
    is_active = CASE WHEN is_active IS NOT NULL AND is_active NOT IN ('0', '1') THEN NULL ELSE is_active END,
    monthly_spend = CASE
        WHEN monthly_spend IS NOT NULL
         AND monthly_spend NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE monthly_spend
    END,
    household_size = CASE
        WHEN household_size IS NOT NULL
         AND household_size NOT REGEXP '^[0-9]+$' THEN NULL
        ELSE household_size
    END,
    created_at = DATE_FORMAT(parse_datetime_flexible(created_at), '%Y-%m-%d %H:%i:%s.%f');

UPDATE movies
SET
    release_year = CASE WHEN release_year IS NOT NULL AND release_year NOT REGEXP '^[0-9]+$' THEN NULL ELSE release_year END,
    duration_minutes = CASE
        WHEN duration_minutes IS NOT NULL
         AND duration_minutes NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE duration_minutes
    END,
    imdb_rating = CASE
        WHEN imdb_rating IS NOT NULL
         AND imdb_rating NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE imdb_rating
    END,
    production_budget = CASE
        WHEN production_budget IS NOT NULL
         AND production_budget NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE production_budget
    END,
    box_office_revenue = CASE
        WHEN box_office_revenue IS NOT NULL
         AND box_office_revenue NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE box_office_revenue
    END,
    number_of_seasons = CASE
        WHEN number_of_seasons IS NOT NULL
         AND number_of_seasons NOT REGEXP '^[0-9]+$' THEN NULL
        ELSE number_of_seasons
    END,
    number_of_episodes = CASE
        WHEN number_of_episodes IS NOT NULL
         AND number_of_episodes NOT REGEXP '^[0-9]+$' THEN NULL
        ELSE number_of_episodes
    END,
    is_netflix_original = CASE
        WHEN is_netflix_original IS NOT NULL
         AND is_netflix_original NOT IN ('0', '1') THEN NULL
        ELSE is_netflix_original
    END,
    added_to_platform = DATE_FORMAT(parse_date_flexible(added_to_platform), '%Y-%m-%d'),
    content_warning = CASE
        WHEN content_warning IS NOT NULL
         AND content_warning NOT IN ('0', '1') THEN NULL
        ELSE content_warning
    END;

UPDATE watch_history
SET
    watch_date = DATE_FORMAT(parse_date_flexible(watch_date), '%Y-%m-%d'),
    watch_duration_minutes = CASE
        WHEN watch_duration_minutes IS NOT NULL
         AND watch_duration_minutes NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE watch_duration_minutes
    END,
    progress_percentage = CASE
        WHEN progress_percentage IS NOT NULL
         AND progress_percentage NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE progress_percentage
    END,
    is_download = CASE
        WHEN is_download IS NOT NULL
         AND is_download NOT IN ('0', '1') THEN NULL
        ELSE is_download
    END,
    user_rating = CASE
        WHEN user_rating IS NOT NULL
         AND user_rating NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE user_rating
    END;

UPDATE reviews
SET
    rating = CASE WHEN rating IS NOT NULL AND rating NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL ELSE rating END,
    review_date = DATE_FORMAT(parse_date_flexible(review_date), '%Y-%m-%d'),
    is_verified_watch = CASE
        WHEN is_verified_watch IS NOT NULL
         AND is_verified_watch NOT IN ('0', '1') THEN NULL
        ELSE is_verified_watch
    END,
    helpful_votes = CASE
        WHEN helpful_votes IS NOT NULL
         AND helpful_votes NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE helpful_votes
    END,
    total_votes = CASE
        WHEN total_votes IS NOT NULL
         AND total_votes NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE total_votes
    END,
    sentiment_score = CASE
        WHEN sentiment_score IS NOT NULL
         AND sentiment_score NOT REGEXP '^[-]?[0-9]+(\\.[0-9]+)?$' THEN NULL
        ELSE sentiment_score
    END;

-- --------------------------------------------------------------------
-- 5. Convert cleaned columns to their final MySQL data types
-- --------------------------------------------------------------------

ALTER TABLE users
    MODIFY user_id VARCHAR(50),
    MODIFY email VARCHAR(255),
    MODIFY first_name VARCHAR(100),
    MODIFY last_name VARCHAR(100),
    MODIFY age DECIMAL(5,1),
    MODIFY gender VARCHAR(50),
    MODIFY country VARCHAR(50),
    MODIFY state_province VARCHAR(100),
    MODIFY city VARCHAR(100),
    MODIFY subscription_plan VARCHAR(50),
    MODIFY subscription_start_date DATE,
    MODIFY is_active TINYINT(1),
    MODIFY monthly_spend DECIMAL(10,2),
    MODIFY primary_device VARCHAR(50),
    MODIFY household_size INT,
    MODIFY created_at DATETIME(6);

ALTER TABLE movies
    MODIFY movie_id VARCHAR(50),
    MODIFY title VARCHAR(255),
    MODIFY content_type VARCHAR(100),
    MODIFY genre_primary VARCHAR(100),
    MODIFY genre_secondary VARCHAR(100),
    MODIFY release_year INT,
    MODIFY duration_minutes DECIMAL(8,1),
    MODIFY rating VARCHAR(20),
    MODIFY language VARCHAR(50),
    MODIFY country_of_origin VARCHAR(100),
    MODIFY imdb_rating DECIMAL(3,1),
    MODIFY production_budget DECIMAL(15,2),
    MODIFY box_office_revenue DECIMAL(15,2),
    MODIFY number_of_seasons INT,
    MODIFY number_of_episodes INT,
    MODIFY is_netflix_original TINYINT(1),
    MODIFY added_to_platform DATE,
    MODIFY content_warning TINYINT(1);

ALTER TABLE watch_history
    MODIFY session_id VARCHAR(50),
    MODIFY user_id VARCHAR(50),
    MODIFY movie_id VARCHAR(50),
    MODIFY watch_date DATE,
    MODIFY device_type VARCHAR(50),
    MODIFY watch_duration_minutes DECIMAL(8,1),
    MODIFY progress_percentage DECIMAL(5,1),
    MODIFY action VARCHAR(50),
    MODIFY quality VARCHAR(50),
    MODIFY location_country VARCHAR(50),
    MODIFY is_download TINYINT(1),
    MODIFY user_rating DECIMAL(3,1);

ALTER TABLE reviews
    MODIFY review_id VARCHAR(50),
    MODIFY user_id VARCHAR(50),
    MODIFY movie_id VARCHAR(50),
    MODIFY rating DECIMAL(3,1),
    MODIFY review_date DATE,
    MODIFY device_type VARCHAR(50),
    MODIFY is_verified_watch TINYINT(1),
    MODIFY helpful_votes DECIMAL(10,1),
    MODIFY total_votes DECIMAL(10,1),
    MODIFY review_text TEXT,
    MODIFY sentiment VARCHAR(50),
    MODIFY sentiment_score DECIMAL(5,3);

DESCRIBE users;
DESCRIBE movies;
DESCRIBE watch_history;
DESCRIBE reviews;

-- --------------------------------------------------------------------
-- 6. Analytics queries on the typed base tables
-- --------------------------------------------------------------------

-- Total watch time by subscription type
SELECT
    u.subscription_plan,
    ROUND(SUM(w.watch_duration_minutes), 2) AS total_watch_time_minutes
FROM watch_history AS w
JOIN users AS u
    ON w.user_id = u.user_id
WHERE w.watch_duration_minutes IS NOT NULL
GROUP BY u.subscription_plan
ORDER BY total_watch_time_minutes DESC;

-- Average watch time by genre
SELECT
    m.genre_primary,
    ROUND(AVG(w.watch_duration_minutes), 2) AS average_watch_time_minutes
FROM watch_history AS w
JOIN movies AS m
    ON w.movie_id = m.movie_id
WHERE w.watch_duration_minutes IS NOT NULL
GROUP BY m.genre_primary
ORDER BY average_watch_time_minutes DESC;

-- User count by country
SELECT
    country,
    COUNT(*) AS user_count
FROM users
GROUP BY country
ORDER BY user_count DESC;

-- Average review rating by device
SELECT
    device_type,
    ROUND(AVG(rating), 2) AS average_rating
FROM reviews
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
    FROM users AS u
    JOIN watch_history AS w
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
    FROM watch_history AS w
    JOIN movies AS m
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
