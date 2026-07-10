# Validation Report — Netflix User Behavior Project

_Validated on 2026-06-23. Python script executed end-to-end against the dataset; SQL reviewed statically and its query logic reproduced in pandas; every numeric claim in `README.md` cross-checked against the data._

## Verdict

The **Python script is correct and runs cleanly**, and most README numbers are accurate. The main problems are in the **README narrative and the SQL workflow's relationship to it**: two headline insights are attributed to the SQL queries but the reported numbers actually come from the Python pipeline, and the SQL queries — if run — return materially different answers. There is also a statistically misleading imputation step that drives one of the headline insights.

## What is correct

- `python/netflix_analysis.py` runs with no errors (pandas 2.3.3, matplotlib 3.10.9) and regenerates all five charts in `python/output/`.
- Raw row counts match: users 10,300 · movies 1,040 · watch_history 105,000 · reviews 15,450.
- Cleaned shapes match the README: users 9,826 · movies 1,000 · watch_history 99,851 · reviews 15,000 · analysis table 98,076.
- These README figures reproduce exactly: total watch time by plan (Standard ~2.18M, Premium ~2.15M, Basic ~1.23M, Premium+ ~0.61M; Standard+Premium = 70.2%), average watch time by genre (Romance 65.25, Horror 64.24, Thriller 63.61), average rating by device (Mobile 3.69 → Tablet 3.64, spread 0.05), country split (USA 6,879 / Canada 2,947 = 70.0%), and watch-activity date range (2024-01-01 to 2025-12-31).
- The SQL file is syntactically sound and well-structured: flexible date-parsing UDFs, NULL-replacement via regex, `ALTER TABLE` type conversion, and CTEs.

## Issues found

### 1. README attributes Python results to the SQL queries (high)
The "Top Genres by Total Watch Time" and "Age Group Engagement" sections are described as SQL CTE outputs, but the reported numbers match the **Python analysis-table pipeline**, not the SQL. Running the actual SQL CTEs gives different results:

| Insight | README / Python pipeline | Actual SQL CTE output |
|---|---|---|
| Top genres by total watch time | Adventure ~424K, **Animation** ~370K, **Comedy** ~362K | Adventure ~443K, **War** ~375K, **Animation** ~373K (Comedy is 6th) |
| Age 35-44 sessions | **38,017** (~39% of sessions) | **26,143** |
| Total sessions in age analysis | ~98,076 | 88,074 |
| Age buckets present | "Under 18" … "55+" | "10-17" … "55+" **plus an "Unknown" bucket (1,686)** |

The numbers come from Python because the Python pipeline dedups, median-imputes, applies an age filter, and inner-joins to cleaned users+movies — none of which the SQL does.

### 2. Python and SQL are not "parallel" cleaning workflows (high)
The README claims both workflows clean in parallel, but they diverge in four ways that change the results:

- **Duplicates:** SQL never runs a dedup step. Python calls `drop_duplicates()`. The README itself says the 5,000 duplicate watch sessions "must be removed before watch-time aggregates are reliable" — yet SQL's `SUM(watch_duration_minutes)` (total watch time by plan / by genre) double-counts those duplicate rows. Session counts using `COUNT(DISTINCT session_id)` are safe, but the SUM-based totals are inflated.
- **Median imputation:** Python fills missing `age`, `monthly_spend`, `household_size`, `watch_duration_minutes`, and `progress_percentage` with medians. SQL leaves them NULL and excludes them via `WHERE ... IS NOT NULL`. This is the largest source of the number gaps.
- **Age range filter:** Python keeps only ages in [10, 100]; SQL applies no such filter (179 out-of-range ages survive).
- **Net effect on user counts:** Python (dedup + age filter) → USA 6,879 / Canada 2,947; raw SQL → USA 7,204 / Canada 3,096.

### 3. Median age imputation distorts the headline age-group insight (medium)
11.9% of users (1,229) have missing age. The median age is 35.0, which sits inside the 35-44 bucket, so every age-missing user is dumped into 35-44. That is what produces the "35-44 = ~39% of all sessions" headline (38,017 sessions in Python). Excluding null ages, as the SQL does, gives 35-44 ≈ 26,143 — nearly tied with 25-34 (25,438). The "engagement peaks sharply at 35-44" conclusion is largely an imputation artifact and should be softened or re-derived without imputing age before bucketing.

### 4. Age-bucket labels/boundaries differ between Python and SQL (low)
Python labels the youngest band "Under 18" (and drops ages <10 via the [10,100] filter); SQL labels it "10-17" and routes <10 / out-of-band / null ages to an "Unknown" bucket. The README uses the Python labels while describing the SQL query.

### 5. The Python script never produces the age-group analysis (low)
`age_group` is computed and merged into `watch_analysis` but is never aggregated or printed. The script does not output the age-group engagement table the README discusses, nor total-watch-time-by-genre — only average-by-genre. Either add those aggregations to the script or stop attributing those insights to it.

### 6. Minor SQL type choices (informational)
`helpful_votes` and `total_votes` are converted to `DECIMAL(10,1)` though they are vote counts (the source stores them as `3.0`/`5.0`); `INT` would be more natural. The step-4 `age` regex `^[-]?[0-9]+...` permits negative ages, which would then survive into `DECIMAL` and bucket as "Unknown." Neither breaks execution.

## Recommended fixes

1. In the README, relabel the genre-total and age-group sections as Python results, **or** replace the reported numbers with the actual SQL CTE outputs — don't mix the two.
2. Make the workflows truly parallel: add `SELECT DISTINCT` / a dedup step to SQL (or document that SQL totals include duplicates), and decide on one consistent policy for null handling and the age filter across both sides.
3. Re-derive the age-group insight without median-imputing age before bucketing (impute-then-bucket concentrates mass at the median); present 35-44 and 25-34 as roughly comparable.
4. Align age-bucket labels and the youngest/oldest boundaries between Python and SQL.
5. Either add the age-group and genre-total aggregations to `netflix_analysis.py`, or remove the unused `age_group` merge.
