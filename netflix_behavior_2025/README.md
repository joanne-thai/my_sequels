# Netflix User Behavior Analysis (MySQL + Python)

## Overview

This project analyses a Netflix User Behavior dataset using two intentionally separate workflows: a MySQL SQL workflow and a Python workflow. Both use the same source CSV files but each cleans and analyses the data independently, so the project shows both skills clearly.

The dataset combines user-level, movie-level, watch-session-level, and review-level information, making it possible to study viewing behaviour from multiple angles. The workflow simulates a real-world analytics process, including raw data inspection, cleaning, type conversion, exploratory analysis, and chart generation.

## Business Problem

The project answers several questions about user viewing behaviour:

- How is total watch time distributed across subscription plans?
- Which genres hold attention longest per session, and which drive the most total watch time?
- How does engagement differ across age groups?
- Which devices receive the highest review ratings?
- How is the user base distributed across countries?

Answering these questions helps inform subscription strategy, content investment, device experience, and regional targeting.

## Data Model

The dataset follows a relational structure where `watch_history` acts as the central fact table, connected to dimension tables `users` and `movies`. The `reviews` table provides a separate fact table linked to both users and movies. This resembles a star schema and supports analytical queries across user, content, and session dimensions.

## Approach

The project follows a structured workflow on each side:

- inspected raw row counts and missing values across all four tables
- trimmed text columns and normalised booleans, categories, and country labels
- replaced unconvertible values with NULL using regex checks
- parsed multiple date and datetime formats with reusable MySQL functions (`parse_date_flexible`, `parse_datetime_flexible`)
- converted cleaned columns to their final MySQL types with `ALTER TABLE`
- ran aggregation queries for subscription, genre, country, device, and age-group analysis
- used CTEs to structure age-group engagement and top-genre analysis
- mirrored the same cleaning and analysis in Python with pandas, saving charts to `python/output/`

## Folder Structure

```text
dataset/
sql/
  netflix_analysis.sql
python/
  netflix_analysis.py
  output/
pyproject.toml
README.md
```

## Data Preparation

### Data Validation

Before any analysis, the workflow inspects the raw data:

- counts rows in `users`, `movies`, `watch_history`, and `reviews`
- previews the first ten rows of each table
- reviews missing values and exact duplicate counts (Python side)

This step matters because all downstream cleaning, joins, and aggregations depend on knowing what is missing and what is malformed. It also exposes duplicate rows early — for example, the raw watch history contains 5,000 exact duplicates that must be removed before session counts and watch-time aggregates are reliable.

### Data Cleaning

Both workflows perform parallel cleaning steps:

- trim and normalise text fields
- collapse country variants (`US`, `USA`, `United States` → `USA`)
- map booleans (`TRUE`/`FALSE`) to `1`/`0`
- replace empty strings and unconvertible values with `NULL`
- parse `subscription_start_date`, `created_at`, `watch_date`, `added_to_platform`, and `review_date` using flexible format helpers
- convert MySQL columns to typed forms (`DATE`, `DATETIME(6)`, `DECIMAL`, `TINYINT(1)`, `INT`)
- in Python: drop duplicates, fill numeric medians, and clip `watch_duration_minutes` to `[0, 720]` and `progress_percentage` to `[0, 100]`

This cleaning ensures joins between watch history, users, and movies produce reliable session counts and watch-time aggregates.

## Key Analyses

### Total Watch Time by Subscription Plan

The query joins `watch_history` with `users` and sums `watch_duration_minutes` per `subscription_plan`. This shows whether higher-tier plans actually generate more viewing per plan group, or whether plan tier and engagement diverge.

### Average Watch Time by Genre

The query joins `watch_history` with `movies` and averages `watch_duration_minutes` by `genre_primary`. This measures session-level attention rather than total volume, which is useful for understanding which genres hold viewers longest per sitting.

### Top Genres by Total Watch Time (CTE)

A CTE first aggregates total watch time by `genre_primary`, then the outer query orders the top 10. Combining this with the per-session view separates "long sessions" from "high-volume" genres.

### User Count by Country

A simple grouped count of `users` by `country` shows the geographic distribution of the user base.

### Average Review Rating by Device

The query averages `rating` from `reviews` by `device_type`, showing whether a particular device experience is associated with a higher or lower review score.

### Age Group Engagement (CTE)

A CTE buckets `users.age` into bands (`10-17`, `18-24`, `25-34`, `35-44`, `45-54`, `55+`), then joins to `watch_history` and reports session count, average watch time, and average progress percentage per band. This shows engagement intensity across age groups, not just user counts.

### Python Charts

The Python script saves the following charts to `python/output/`:

- `total_watch_time_by_subscription_type.png`
- `average_watch_time_by_genre.png`
- `watch_time_distribution.png`
- `average_rating_by_device.png`
- `user_count_by_country_top_10.png`

## Key Insights

The raw dataset contains **10,300 user rows**, **1,040 movie rows**, **105,000 watch sessions**, and **15,450 reviews**. After cleaning (duplicate removal, age range filter, watch-time clipping), the analysis runs on **9,826 users**, **1,000 movies**, **99,851 watch sessions**, and **15,000 reviews**, covering watch activity from **2024-01-01 to 2025-12-31** across **2 countries** (USA, Canada).

### Standard and Premium Plans Drive Most Viewing

Total watch time is concentrated in the mid-tier plans. The breakdown by subscription plan is:

- **Standard:** ~2.18M minutes
- **Premium:** ~2.15M minutes
- **Basic:** ~1.23M minutes
- **Premium+:** ~0.61M minutes

Standard and Premium together account for roughly **70% of all watch minutes**, while the highest tier, **Premium+**, contributes the least. This suggests that the bulk of engagement comes from mainstream plans, and that plan upgrades to Premium+ do not translate into proportionally higher viewing. Subscription strategy should focus on retaining Standard and Premium users, while reviewing whether Premium+ delivers enough additional value to justify its price.

### Genres Differ Between "Long Sessions" and "High Volume"

Average watch time per session is similar across genres (roughly 62–65 minutes), but the leaders differ from the genres with the highest total watch time:

- **Highest average watch time per session:** Romance (~65.3 min), Horror (~64.2 min), Thriller (~63.6 min)
- **Highest total watch time:** Adventure (~424K min), Animation (~370K min), Comedy (~362K min)

Romance, Horror, and Thriller hold attention longest per sitting, but Adventure, Animation, and Comedy generate the most watching overall because they are watched more often. Content investment should distinguish between **engagement-per-session genres** (good for premium content positioning) and **volume genres** (good for catalogue breadth and retention).

### Engagement Peaks in the 25–54 Age Range

Session counts vary sharply by age group, while average watch time and progress are nearly flat:

- **35-44:** ~38K sessions, 62.8 avg minutes, 50.0% avg progress
- **25-34:** ~25K sessions
- **45-54:** ~14K sessions
- **18-24:** ~11K sessions
- **Under 18:** ~5K sessions
- **55+:** ~4.7K sessions

The 25–54 bracket drives most viewing volume, with the 35–44 group alone accounting for roughly **39% of all sessions**. Average watch time per session and average progress are essentially flat across age groups, meaning younger and older users behave similarly *per session* — they just watch less often. Marketing and recommendation effort should prioritise the 25–54 core, while the 18–24 and 55+ bands represent growth opportunities if frequency can be lifted.

### Device Choice Has Little Effect on Review Ratings

Average review ratings are nearly identical across devices:

- **Mobile:** 3.69
- **Laptop:** 3.66
- **Smart TV:** 3.65
- **Tablet:** 3.64

The spread between the highest and lowest device is only **0.05 stars**, well within noise. This suggests that the device experience is consistent and is not a meaningful driver of user satisfaction. Engineering effort to improve ratings should focus on **content and recommendation quality** rather than device-specific UX, since no single device is dragging ratings down.

### User Base Is Concentrated in Two Countries

The cleaned user base is split between only two countries:

- **USA:** 6,879 users (~70%)
- **Canada:** 2,947 users (~30%)

Geographic targeting should be built around USA-first defaults, with Canada-specific adjustments where needed. Any "global" assumptions in the analysis should be replaced with **North-America-specific** assumptions, since no other regions are represented in this dataset.

### Core Issue

The headline pattern is that **engagement and revenue tier do not move together**. Standard and Premium plans dominate watch time, but the most expensive plan, Premium+, lags significantly. Genre-level data shows the same pattern in a different form: the genres with the longest sessions are not the genres with the highest total viewing. A better strategy would protect the mid-tier plans (Standard, Premium), invest in volume genres (Adventure, Animation, Comedy) for retention, and use engagement genres (Romance, Horror, Thriller) for premium positioning, while focusing growth effort on the under-represented age bands rather than chasing device-specific UX gains.

## Recommendations

### Protect the Mid-Tier Plans

Standard and Premium together generate the majority of watch minutes (~70%), while Premium+ contributes the least.

- Prioritise retention campaigns on Standard and Premium users
- Review the value proposition of Premium+ — features, exclusive content, or pricing
- Avoid pushing aggressive upgrades from Premium to Premium+ until the engagement gap is understood

**Expected Impact:** Reduce churn on the plans that drive most viewing volume.

### Distinguish Volume Genres from Engagement Genres

Adventure, Animation, and Comedy lead in total watch time, while Romance, Horror, and Thriller lead in average watch time per session.

- Treat volume genres as catalogue anchors — invest in breadth and freshness
- Treat engagement genres as premium positioning — invest in marquee titles and series formats
- Use both views together when planning content acquisition rather than relying on one metric

**Expected Impact:** More efficient content investment, with genres serving the role they actually fill.

### Focus Growth on Under-Represented Age Bands

The 25–54 core drives most sessions, while 18–24 and 55+ lag despite similar per-session engagement.

- Target acquisition and re-engagement campaigns at 18–24 and 55+ users
- Test content rows and recommendations tuned to those bands
- Avoid investing further in 35–44 acquisition where the user base is already saturated

**Expected Impact:** Lift session frequency in the bands that already engage well per session.

### Stop Optimising Device-Specific Review Quality

Average ratings differ by only 0.05 stars across Mobile, Laptop, Smart TV, and Tablet.

- Redirect rating-improvement effort from device UX to content and recommendation quality
- Keep monitoring device ratings for regressions, but do not treat the gap as a real signal today

**Expected Impact:** Free up engineering effort for changes that move user satisfaction.

### Treat the Project as North America–Specific

The cleaned user base is 100% USA + Canada, with USA at ~70%.

- Apply USA-first defaults for regional analysis
- Replace any "global" framing with North-America-specific framing
- Treat any single-country findings as not generalisable until a wider dataset is available

**Expected Impact:** More accurate framing of the dataset's scope and avoid overgeneralising results.

### Extend Reusable SQL Components

The SQL workflow already includes reusable date-parsing functions (`parse_date_flexible`, `parse_datetime_flexible`) and CTE-based analysis blocks.

- Wrap age bucketing in a stored function so the same logic powers multiple reports
- Add a stored procedure for date-range engagement reports (e.g. by month, plan, or device)
- Standardise common joins (`watch_history` × `users` × `movies`) into a view to reduce repeated SQL

**Expected Impact:** Faster reporting, less repeated logic, and easier onboarding for future questions.

## Technical Skills Demonstrated

- **Relational database analysis:** Joined `users`, `movies`, `watch_history`, and `reviews` to analyse subscription, genre, device, country, and age-group behaviour.
- **Data validation:** Inspected raw row counts, missing values, and duplicates before analysis (e.g. 5,000 duplicate watch sessions in raw data).
- **Data cleaning:** Trimmed text, normalised booleans, collapsed country variants, replaced unconvertible values with NULL, and parsed multiple date and datetime formats.
- **User-defined functions (UDF):** Built `parse_date_flexible` and `parse_datetime_flexible` to handle multiple raw date formats safely with `STR_TO_DATE` and `COALESCE`.
- **Type management:** Used `ALTER TABLE ... MODIFY` to convert cleaned columns to `DATE`, `DATETIME(6)`, `DECIMAL`, `TINYINT(1)`, and `INT`.
- **Common Table Expressions (CTEs):** Used CTEs to structure age-group engagement and top-genre analysis.
- **Conditional classification:** Used `CASE` expressions to bucket ages into bands and to map raw booleans and country variants.
- **Aggregation analysis:** Calculated total and average watch time, distinct session counts, average review ratings, and user counts.
- **Python pandas workflow:** Replicated cleaning and analysis in Python, including duplicate removal, type coercion, median imputation, range filtering, and groupby aggregation.
- **Visualisation:** Generated bar charts and a histogram with matplotlib for subscription, genre, device, country, and watch-time distribution.

## How to Run

### SQL part

1. Open MySQL Workbench or another MySQL client.
2. Run the script in `sql/netflix_analysis.sql`.
3. Import the CSV files into the raw tables (`users`, `movies`, `watch_history`, `reviews`).
4. If `LOAD DATA LOCAL INFILE` works in your MySQL setup, you can uncomment and update the sample import commands in the SQL file. Otherwise use MySQL Workbench's Table Data Import Wizard.

### Python part

```bash
uv sync
uv run python python/netflix_analysis.py
```

The script loads CSVs from `dataset/`, cleans each table, joins for analysis, prints summary tables, and writes charts into `python/output/`.

## Business Value

This project demonstrates how raw streaming-behaviour data can be transformed into actionable insights. The analysis identifies which subscription plans drive engagement, which genres serve volume vs. attention, where the user base concentrates by age and country, and where device differences are too small to act on.

## Future Improvements

Future enhancements include extending the dataset beyond North America, adding cohort and retention analysis, building reusable stored procedures for date-range engagement reports, optimising query performance through indexing on `watch_date` and join keys, and integrating recommendation-log and search-log tables for a fuller behaviour picture.
