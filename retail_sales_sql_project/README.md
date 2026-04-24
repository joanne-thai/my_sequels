# Retail Sales Performance Analysis (MySQL)

## Overview  

This project analyses retail sales data in MySQL to understand sales trends, discount impact, customer segment profitability, and employee performance.

The dataset combines transaction-level, product-level, customer-level, and employee-level information, making it possible to analyse performance from multiple business perspectives. The workflow simulates a real-world analytics process, including data validation, cleaning, exploratory analysis, and automated reporting.

## Business Problem  

The business needs to answer several key questions:

- How are sales changing over time?
- How do different discount levels affect order volume and profit?
- Which product categories perform best for different customer segments?
- How much does each product category contribute to employee profit?
- How can reporting be made more reusable for employee-level performance checks?

Answering these questions helps improve pricing decisions, segment targeting, category focus, and internal performance reporting.

## Data Model  
The dataset follows a relational structure where `orders` acts as the central fact table, connected to dimension tables including `product`, `customer`, and `employee`. This structure resembles a star schema, enabling efficient analytical queries across multiple business dimensions.

## Approach
The project follows a structured SQL workflow:

- validated raw data quality before analysis
- standardised date fields in the orders table
- analysed quarterly sales trends for a selected category
- evaluated discount impact using discount banding
- ranked product category profitability within customer segments
- calculated category contribution to each employee’s total profit
- created a reusable **user-defined function** for employee-category profitability
- created a **stored procedure** for date-range employee reporting

This workflow combines one-off analysis with reusable SQL components for reporting. 

## Data Preparation  

### 1. Data Validation
The project begins with basic validation checks on the raw data before any analysis is performed.

This includes:
- counting total order rows
- checking for missing `ORDER_DATE` values
- reviewing category distribution in the product table

This step is important because the rest of the analysis depends on reliable dates and usable category labels. It also shows awareness that analysis should start with data quality checks, not just reporting queries. 

### 2. Data Cleaning
The SQL script standardises both `ORDER_DATE` and `SHIP_DATE` using `STR_TO_DATE()` and conditional logic.

Two date formats are handled:
- `%m/%d/%Y`
- `%Y/%d/%m`

This ensures the order and shipping fields can be used consistently in time-based analysis, such as quarter grouping and date-range filtering. Without this step, quarterly trend analysis and stored procedure filtering would be unreliable.

## Key Analyses  

### Sales Trend Analysis  

The project analyses quarterly sales performance for the **Furnishings** category.

The query:
- joins `orders` with `product`
- filters to `CATEGORY = 'Furnishings'`
- groups by year and quarter
- calculates total sales for each quarter

This helps identify how one product category performs over time rather than looking only at total business performance. It is useful for spotting seasonal strength, slower periods, or category-specific trend shifts. 

### Discount Impact Analysis  

Discount impact is analysed by grouping discounts into four levels:

- **No Discount**
- **Low Discount**
- **Medium Discount**
- **High Discount**

The query then compares:
- number of distinct orders
- total profit
- across product categories and discount levels

This is a strong business-focused analysis because discounts do not just affect volume — they also affect margin. By combining order count with total profit, the query helps assess whether a higher discount level is actually beneficial or simply eroding profitability.

### Category Performance  

Product categories were evaluated based on both revenue and profit to distinguish high-performing and underperforming segments.

### Customer Segment Analysis  
Category performance was analyzed across customer segments to identify consistent profit drivers.

### Employee Performance  
Employee-level analysis was conducted to understand how profit contribution is distributed across product categories.

### Advanced SQL Components  
Reusable SQL logic was implemented to support scalable analysis, including a user-defined function for profitability ratio and a stored procedure for dynamic reporting.

---

## Key Insights  

High discount levels (>20%) significantly erode profitability, with medium and high discounts generating losses of approximately $58K and $76K respectively, while no-discount sales contribute over $320K in profit.  

Discounted transactions collectively result in a net loss (~$34K), indicating that current discount strategies are financially unsustainable.  

While Phones and Chairs generate the highest revenue (~$330K each), Copiers deliver the highest profit (~$55K), suggesting stronger margins.  

Certain categories such as Tables and Bookcases operate at a loss, highlighting potential pricing or cost inefficiencies.  

---

## Technical Skills Demonstrated  

Data validation and cleaning in SQL, complex joins across relational tables, Common Table Expressions (CTEs), window functions, conditional logic (`CASE WHEN`), user-defined functions (UDF), and stored procedures for automation.

---

## How to Run  

1. Import the dataset into MySQL under the schema `retail_project`  
2. Execute the SQL script in sequence: data validation, data cleaning, analytical queries, and object creation  
3. Run the stored procedure to generate dynamic reports  

---

## Business Value  

This project demonstrates how raw transactional data can be transformed into actionable insights. The analysis identifies inefficiencies in discount strategies, highlights high-margin product categories, and provides a foundation for improving pricing and sales performance.

---

## Future Improvements  

Future enhancements include building an interactive dashboard for visualization, optimizing query performance through indexing, extending the analysis with forecasting techniques, and integrating Python for deeper statistical insights.
