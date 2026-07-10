# Fix Guide — Netflix User Behavior Project

Goal: make the Python and SQL workflows produce the **same, statistically honest** numbers, and correct the README to match. Nothing here has been applied — these are the exact edits to make.

## Target cleaning policy (apply identically to both workflows)

1. **De-duplicate** exact duplicate rows in every table (both workflows).
2. **No median imputation.** Missing numeric values stay missing; aggregations skip them.
3. **Age validity ([10, 100] and non-null) is applied only inside the age-group analysis** — not globally — so country/plan counts keep every real user.
4. **Range-clip by invalidation:** durations outside [0, 720] and progress outside [0, 100] become NULL/NaN rather than being imputed.

Under this policy the numbers become consistent across Python and SQL (verified against the data). Use the "New value" column below when updating the README.

| Metric | Old README | New (honest) value |
|---|---|---|
| Cleaned users | 9,826 | **10,000** |
| Cleaned watch sessions | 99,851 | **100,000** (88,080 with a usable duration) |
| Watch time — Standard / Premium / Basic / Premium+ | 2.18M / 2.15M / 1.23M / 0.61M | **2.01M / 1.98M / 1.13M / 0.57M** (Standard+Premium = 70.2%) |
| Avg watch/session — top 3 genres | Romance 65.3 / Horror 64.2 / Thriller 63.6 | **Romance 67.0 / Horror 65.9 / Thriller 65.3** |
| Total watch time — top 3 genres | Adventure 424K / Animation 370K / Comedy 362K | **Adventure 390K / Animation 341K / Comedy 332K** (ranking unchanged) |
| Age 35-44 sessions (share) | 38,017 (~39%) | **26,143 (~30%)** |
| Age 25-34 sessions (share) | ~25,397 | **25,438 (~30%)** — now nearly tied with 35-44 |
| Country — USA / Canada | 6,879 / 2,947 | **6,993 / 3,007** (USA 69.9%) |
| Device ratings | Mobile 3.69 → Tablet 3.64 | unchanged |

---

## Fix 1 — Python: stop imputing age; don't drop users globally

In `python/netflix_analysis.py`, `clean_users()`, **remove** the age median-fill and the global age filter:

```python
# DELETE these lines:
users["age"] = users["age"].fillna(users["age"].median())
users["monthly_spend"] = users["monthly_spend"].fillna(users["monthly_spend"].median())
users["household_size"] = users["household_size"].fillna(users["household_size"].median())
...
users = users[users["age"].between(10, 100)].copy()
```

Keep `age` numeric with NaN preserved, and let `get_age_group` handle validity:

```python
users["age"] = pd.to_numeric(users["age"], errors="coerce")   # keep NaN
# (country / plan / text normalisation stays the same)
users["age_group"] = users["age"].apply(get_age_group)        # NaN / out-of-range -> "Unknown"
```

`monthly_spend` and `household_size` are never used downstream, so dropping their imputation is optional but recommended for honesty.

## Fix 2 — Python: align age buckets with SQL and add an "Unknown" bucket

Replace `get_age_group()` so labels match the SQL CTE (`10-17` … `55+`) and out-of-range/missing ages are excluded from the analysis rather than folded into a real band:

```python
def get_age_group(age: float) -> str:
    if pd.isna(age) or age < 10 or age > 100:
        return "Unknown"
    if age <= 17: return "10-17"
    if age <= 24: return "18-24"
    if age <= 34: return "25-34"
    if age <= 44: return "35-44"
    if age <= 54: return "45-54"
    return "55+"
```

## Fix 3 — Python: invalidate bad values instead of median-filling

In `clean_watch_history()`, **remove** the two median-fill blocks and clip by setting out-of-range values to NaN (so a valid duration is never dropped just because progress is missing):

```python
wh["watch_duration_minutes"] = pd.to_numeric(wh["watch_duration_minutes"], errors="coerce")
wh["progress_percentage"]    = pd.to_numeric(wh["progress_percentage"], errors="coerce")
# NO .fillna(median)
wh.loc[~wh["watch_duration_minutes"].between(0, 720), "watch_duration_minutes"] = pd.NA
wh.loc[~wh["progress_percentage"].between(0, 100),   "progress_percentage"]   = pd.NA
return wh
```

`sum()` and `mean()` skip NaN automatically, so totals and averages come out to the honest values in the table above.

## Fix 4 — Python: actually produce the age-group and genre-total analyses

The script computes `age_group` but never outputs it, and never computes total watch time by genre — yet the README discusses both. Add them in `main()` (exclude `"Unknown"` from the age view):

```python
total_watch_time_by_genre = (
    watch_analysis.groupby("genre_primary")["watch_duration_minutes"]
    .sum().sort_values(ascending=False)
)

age_group_engagement = (
    watch_analysis[watch_analysis["age_group"] != "Unknown"]
    .groupby("age_group")
    .agg(sessions=("session_id", "nunique"),
         avg_watch=("watch_duration_minutes", "mean"),
         avg_progress=("progress_percentage", "mean"))
    .sort_values("sessions", ascending=False)
)
print("\nTOTAL WATCH TIME BY GENRE\n", total_watch_time_by_genre.round(2).head(10))
print("\nAGE GROUP ENGAGEMENT\n", age_group_engagement.round(2))
```

(Optionally add a `save_bar_chart` call for each.)

---

## Fix 5 — SQL: de-duplicate before cleaning

`sql/netflix_analysis.sql` never removes duplicates, so `SUM(watch_duration_minutes)` double-counts the 5,000 duplicate sessions. Because the duplicates are exact full-row copies, `SELECT DISTINCT *` collapses them. Add this **after section 1 (inspection), before section 3 (cleanup)** — while columns are still raw strings:

```sql
-- De-duplicate exact rows right after import
CREATE TABLE users_tmp         AS SELECT DISTINCT * FROM users;
DROP TABLE users;         RENAME TABLE users_tmp         TO users;
CREATE TABLE movies_tmp        AS SELECT DISTINCT * FROM movies;
DROP TABLE movies;        RENAME TABLE movies_tmp        TO movies;
CREATE TABLE watch_history_tmp AS SELECT DISTINCT * FROM watch_history;
DROP TABLE watch_history; RENAME TABLE watch_history_tmp TO watch_history;
CREATE TABLE reviews_tmp       AS SELECT DISTINCT * FROM reviews;
DROP TABLE reviews;       RENAME TABLE reviews_tmp       TO reviews;
```

## Fix 6 — SQL: filter age range in the age-group CTE and clip durations

In the age-group CTE, change the filter so outlier/missing ages are excluded (matching Python):

```sql
    ...
    FROM users AS u
    JOIN watch_history AS w ON u.user_id = w.user_id
    WHERE u.age IS NOT NULL AND u.age BETWEEN 10 AND 100   -- was: WHERE u.age IS NOT NULL
```

And add two clip statements right **after section 5 (type conversion)**, so SQL and Python treat binge/anomalous durations the same way:

```sql
UPDATE watch_history SET watch_duration_minutes = NULL WHERE watch_duration_minutes NOT BETWEEN 0 AND 720;
UPDATE watch_history SET progress_percentage    = NULL WHERE progress_percentage    NOT BETWEEN 0 AND 100;
```

With dedup + these filters, the SQL plan totals, genre totals, and age-group counts match the honest Python numbers.

## Fix 7 — SQL: minor type/regex cleanups (optional)

- `helpful_votes` / `total_votes` are vote counts — use `INT` instead of `DECIMAL(10,1)` (cast via the same `REGEXP '^[0-9]+(\.0+)?$'` pattern already used for `household_size`).
- The step-4 `age` regex `^[-]?[0-9]+(\.[0-9]+)?$` allows negatives; drop the `[-]?` so negative ages become NULL.

---

## Fix 8 — README: correct attribution, labels, and numbers

1. **Attribution:** the "Top Genres by Total Watch Time" and "Age Group Engagement" sections read as SQL-only outputs. After the fixes both workflows agree, so state the numbers come from the unified pipeline (or show them once and note both sides reproduce them).
2. **Age labels:** replace `Under 18` with `10-17` throughout, and note that missing/out-of-range ages are excluded from the age view (not imputed).
3. **Numbers:** update every figure using the "New value" column in the table at the top.
4. **Rewrite the age insight.** The old headline ("35-44 drives ~39% of sessions") was an artifact of assigning the median age (35) to the 11.9% of users with missing age. The honest finding: engagement is concentrated in the **25-44 core, with 35-44 (~30%) and 25-34 (~30%) nearly tied**; 18-24 and 55+ remain the growth bands.
5. **Data-cleaning section:** update the bullets to say *both* workflows de-duplicate and *neither* imputes numeric values before analysis (previously it said dedup/median-fill were Python-only).

## Verify after editing

```bash
uv run python python/netflix_analysis.py     # should print the New values above
```

Then re-run the SQL and confirm the plan totals, genre ranking, and age-group counts match the Python output.
