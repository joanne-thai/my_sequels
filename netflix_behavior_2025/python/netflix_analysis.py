from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


# Build project paths from the script location so the script can be run
# from the repository root with: uv run python python/netflix_analysis.py
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "dataset"
OUTPUT_DIR = PROJECT_ROOT / "python" / "output"


def standardize_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """Keep column names simple and consistent."""
    df = df.copy()
    df.columns = (
        df.columns.str.strip().str.lower().str.replace(" ", "_", regex=False)
    )
    return df


def get_age_group(age: float) -> str:
    """Create simple age buckets that match the SQL workflow.

    Missing or out-of-range ages are labelled "Unknown" so they are excluded
    from the age-group analysis rather than being imputed into a real band.
    """
    if pd.isna(age) or age < 10 or age > 100:
        return "Unknown"
    if age <= 17:
        return "10-17"
    if age <= 24:
        return "18-24"
    if age <= 34:
        return "25-34"
    if age <= 44:
        return "35-44"
    if age <= 54:
        return "45-54"
    return "55+"


def print_dataset_snapshot(name: str, df: pd.DataFrame) -> None:
    """Print a small inspection summary for each table."""
    print(f"\n{name.upper()} DATASET")
    print(f"Shape: {df.shape}")
    print("Columns:", list(df.columns))
    print("Missing values:")
    print(df.isna().sum())
    print(f"Exact duplicate rows: {df.duplicated().sum()}")


def load_data() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Load the CSV files used in this project."""
    users = pd.read_csv(DATA_DIR / "users.csv")
    movies = pd.read_csv(DATA_DIR / "movies.csv")
    watch_history = pd.read_csv(DATA_DIR / "watch_history.csv")
    reviews = pd.read_csv(DATA_DIR / "reviews.csv")

    users = standardize_column_names(users)
    movies = standardize_column_names(movies)
    watch_history = standardize_column_names(watch_history)
    reviews = standardize_column_names(reviews)

    print_dataset_snapshot("users", users)
    print_dataset_snapshot("movies", movies)
    print_dataset_snapshot("watch_history", watch_history)
    print_dataset_snapshot("reviews", reviews)

    return users, movies, watch_history, reviews


def clean_users(users: pd.DataFrame) -> pd.DataFrame:
    """Clean the users table without relying on the SQL workflow."""
    users = users.copy()

    users = users.drop_duplicates()

    users["age"] = pd.to_numeric(users["age"], errors="coerce")
    users["monthly_spend"] = pd.to_numeric(users["monthly_spend"], errors="coerce")
    users["household_size"] = pd.to_numeric(users["household_size"], errors="coerce")

    users["country"] = users["country"].astype("string").str.strip().str.upper()
    users["country"] = users["country"].replace(
        {"US": "USA", "UNITED STATES": "USA", "CANADA": "Canada"}
    )

    users["subscription_plan"] = users["subscription_plan"].astype("string").str.strip()
    users["gender"] = users["gender"].fillna("Unknown").astype("string").str.strip()
    users["primary_device"] = (
        users["primary_device"].fillna("Unknown").astype("string").str.strip()
    )

    # Do not impute missing numeric values. Missing ages stay missing and are
    # labelled "Unknown" by get_age_group so they are excluded from the
    # age-group analysis instead of being pushed into the median band. Real
    # users with a missing age are still kept for country/plan analysis.
    users["age_group"] = users["age"].apply(get_age_group)

    return users


def clean_movies(movies: pd.DataFrame) -> pd.DataFrame:
    """Clean the movies table."""
    movies = movies.copy()

    movies = movies.drop_duplicates()

    movies["genre_primary"] = movies["genre_primary"].fillna("Unknown").astype("string").str.strip()
    movies["title"] = movies["title"].astype("string").str.strip()
    movies["content_type"] = movies["content_type"].fillna("Unknown").astype("string").str.strip()

    return movies


def clean_watch_history(watch_history: pd.DataFrame) -> pd.DataFrame:
    """Clean the watch history table."""
    watch_history = watch_history.copy()

    watch_history = watch_history.drop_duplicates()

    watch_history["watch_duration_minutes"] = pd.to_numeric(
        watch_history["watch_duration_minutes"], errors="coerce"
    )
    watch_history["progress_percentage"] = pd.to_numeric(
        watch_history["progress_percentage"], errors="coerce"
    )
    watch_history["user_rating"] = pd.to_numeric(
        watch_history["user_rating"], errors="coerce"
    )

    watch_history["device_type"] = (
        watch_history["device_type"].fillna("Unknown").astype("string").str.strip()
    )
    watch_history["location_country"] = (
        watch_history["location_country"].fillna("Unknown").astype("string").str.strip().str.upper()
    )
    watch_history["location_country"] = watch_history["location_country"].replace(
        {"US": "USA", "UNITED STATES": "USA", "CANADA": "Canada"}
    )

    # Do not impute missing session metrics. Instead, invalidate out-of-range
    # values (set them to NaN) so a valid duration is never dropped just
    # because progress is missing. sum()/mean() skip NaN automatically.
    watch_history.loc[
        ~watch_history["watch_duration_minutes"].between(0, 720),
        "watch_duration_minutes",
    ] = pd.NA
    watch_history.loc[
        ~watch_history["progress_percentage"].between(0, 100),
        "progress_percentage",
    ] = pd.NA

    return watch_history


def clean_reviews(reviews: pd.DataFrame) -> pd.DataFrame:
    """Clean the reviews table."""
    reviews = reviews.copy()

    reviews = reviews.drop_duplicates()

    reviews["rating"] = pd.to_numeric(reviews["rating"], errors="coerce")
    reviews["device_type"] = reviews["device_type"].fillna("Unknown").astype("string").str.strip()

    reviews = reviews[reviews["rating"].between(1, 5)].copy()

    return reviews


def save_bar_chart(series: pd.Series, title: str, x_label: str, y_label: str, file_name: str) -> None:
    """Save a basic bar chart using matplotlib defaults."""
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.bar(series.index.astype(str), series.values)
    ax.set_title(title)
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    ax.tick_params(axis="x", rotation=45)
    plt.tight_layout()
    fig.savefig(OUTPUT_DIR / file_name, dpi=150, bbox_inches="tight")
    plt.close(fig)


def save_histogram(series: pd.Series, title: str, x_label: str, y_label: str, file_name: str) -> None:
    """Save a basic histogram."""
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.hist(series, bins=30)
    ax.set_title(title)
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    plt.tight_layout()
    fig.savefig(OUTPUT_DIR / file_name, dpi=150, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    users, movies, watch_history, reviews = load_data()

    users_clean = clean_users(users)
    movies_clean = clean_movies(movies)
    watch_history_clean = clean_watch_history(watch_history)
    reviews_clean = clean_reviews(reviews)

    # Join tables only for the analysis step.
    watch_analysis = watch_history_clean.merge(
        users_clean[["user_id", "subscription_plan", "country", "age_group"]],
        on="user_id",
        how="inner",
    ).merge(
        movies_clean[["movie_id", "title", "genre_primary"]],
        on="movie_id",
        how="inner",
    )

    print("\nCLEANED DATASET SHAPES")
    print("Users:", users_clean.shape)
    print("Movies:", movies_clean.shape)
    print("Watch history:", watch_history_clean.shape)
    print("Reviews:", reviews_clean.shape)
    print("Analysis table:", watch_analysis.shape)

    total_watch_time_by_subscription = (
        watch_analysis.groupby("subscription_plan")["watch_duration_minutes"]
        .sum()
        .sort_values(ascending=False)
    )

    average_watch_time_by_genre = (
        watch_analysis.groupby("genre_primary")["watch_duration_minutes"]
        .mean()
        .sort_values(ascending=False)
    )

    total_watch_time_by_genre = (
        watch_analysis.groupby("genre_primary")["watch_duration_minutes"]
        .sum()
        .sort_values(ascending=False)
    )

    # Age-group engagement, excluding users whose age is missing/out of range.
    age_group_engagement = (
        watch_analysis[watch_analysis["age_group"] != "Unknown"]
        .groupby("age_group")
        .agg(
            total_sessions=("session_id", "nunique"),
            average_watch_time_minutes=("watch_duration_minutes", "mean"),
            average_progress_percentage=("progress_percentage", "mean"),
        )
        .sort_values("total_sessions", ascending=False)
    )

    average_rating_by_device = (
        reviews_clean.groupby("device_type")["rating"]
        .mean()
        .sort_values(ascending=False)
    )

    user_count_by_country = (
        users_clean.groupby("country")["user_id"]
        .count()
        .sort_values(ascending=False)
        .head(10)
    )

    print("\nTOTAL WATCH TIME BY SUBSCRIPTION TYPE")
    print(total_watch_time_by_subscription.round(2))

    print("\nAVERAGE WATCH TIME BY GENRE")
    print(average_watch_time_by_genre.round(2).head(10))

    print("\nTOTAL WATCH TIME BY GENRE")
    print(total_watch_time_by_genre.round(2).head(10))

    print("\nAGE GROUP ENGAGEMENT")
    print(age_group_engagement.round(2))

    print("\nAVERAGE RATING BY DEVICE")
    print(average_rating_by_device.round(2))

    print("\nUSER COUNT BY COUNTRY")
    print(user_count_by_country)

    save_bar_chart(
        total_watch_time_by_subscription,
        "Total Watch Time by Subscription Type",
        "Subscription Type",
        "Total Watch Time (Minutes)",
        "total_watch_time_by_subscription_type.png",
    )

    save_bar_chart(
        average_watch_time_by_genre,
        "Average Watch Time by Genre",
        "Genre",
        "Average Watch Time (Minutes)",
        "average_watch_time_by_genre.png",
    )

    save_histogram(
        watch_analysis["watch_duration_minutes"],
        "Watch Time Distribution",
        "Watch Time (Minutes)",
        "Number of Sessions",
        "watch_time_distribution.png",
    )

    save_bar_chart(
        average_rating_by_device,
        "Average Rating by Device",
        "Device Type",
        "Average Rating",
        "average_rating_by_device.png",
    )

    save_bar_chart(
        user_count_by_country,
        "User Count by Country (Top 10)",
        "Country",
        "Number of Users",
        "user_count_by_country_top_10.png",
    )

    save_bar_chart(
        total_watch_time_by_genre.head(10),
        "Total Watch Time by Genre (Top 10)",
        "Genre",
        "Total Watch Time (Minutes)",
        "total_watch_time_by_genre_top_10.png",
    )

    save_bar_chart(
        age_group_engagement["total_sessions"],
        "Sessions by Age Group",
        "Age Group",
        "Number of Sessions",
        "sessions_by_age_group.png",
    )

    print(f"\nCharts saved to: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
