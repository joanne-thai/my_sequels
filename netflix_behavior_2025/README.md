# Netflix User Behavior Data Analyst Project

This project is a simple, portfolio-friendly data analyst example built with the Netflix User Behavior dataset from Kaggle. It contains two intentionally separate workflows:

- A MySQL SQL workflow in one file
- A Python workflow in one file

Both parts use the same dataset, but each workflow cleans and analyzes the data independently.

## Folder structure

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

## Dataset

The CSV files used by this project are stored in `dataset/`. They were copied from the downloaded Kaggle folder so the project is easy to run locally from one place.

## SQL part

File:

- `sql/netflix_analysis.sql`

How to run:

1. Open MySQL Workbench or another MySQL client.
2. Run the script in `sql/netflix_analysis.sql`.
3. Import the CSV files into the `*_raw` tables.
4. If `LOAD DATA LOCAL INFILE` works in your MySQL setup, you can uncomment and update the sample import commands in the SQL file.
5. If local file loading is blocked, use MySQL Workbench's Table Data Import Wizard instead.

What the SQL file includes:

- Raw table creation
- CSV import guidance
- Simple cleaning views
- Basic inspection queries
- Basic aggregation queries
- CTE-based analysis queries

## Python part

File:

- `python/netflix_analysis.py`

How to run with `uv`:

```bash
uv sync
uv run python python/netflix_analysis.py
```

The Python script:

- Loads CSV files from `dataset/`
- Inspects the raw data
- Cleans missing values
- Drops duplicates
- Standardizes simple text fields
- Creates an `age_group` column
- Saves charts into `python/output/`

## Output charts

The Python workflow saves these charts:

- Total watch time by subscription type
- Average watch time by genre
- Watch time distribution
- Average rating by device
- User count by country (top 10)

## Why the workflows are separate

The SQL and Python analyses are intentionally separated so the project shows both skills clearly. The SQL file handles its own cleaning and analysis inside MySQL, while the Python script performs its own cleaning and analysis directly from the CSV files.
