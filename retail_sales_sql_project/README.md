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

This is a strong business-focused analysis because discounts do not just affect volume, they also affect margin. By combining order count with total profit, the query helps assess whether a higher discount level is actually beneficial or simply eroding profitability.

### Customer Segment Profitability  

The project identifies the **top 2 most profitable product categories** within each customer segment.

This analysis:
- joins `orders`, `customer`, and `product`
- aggregates total sales and total profit by segment and category
- uses `DENSE_RANK()` to rank categories within each segment

This makes it possible to compare how different customer segments respond to different product categories. Instead of assuming all customers behave similarly, the query supports segment-specific commercial decisions.

### Employee Performance  

Employee-level analysis was conducted to understand how profit contribution is distributed across product categories.

This is done in two steps:
- first, profit is aggregated by employee and category
- then, a window function calculates the percentage share of that category within the employee’s total profit

This gives a more useful view than total employee profit alone. It shows whether an employee’s performance is broad-based or heavily dependent on one category.

### User-Defined Function for Profitability Ratio

A reusable SQL function, `get_employee_profit`, is created to return the **profitability ratio** for a selected employee and category.

The function:
- accepts `employee_id` and `category` as inputs
- calculates `SUM(PROFIT) / SUM(SALES)`
- safely returns `0` when total sales are zero

This is a good example of turning business logic into reusable SQL, rather than rewriting the same calculation in multiple queries. It also shows understanding of defensive SQL logic through the zero-sales condition.
After creating the function, the project applies it in a reporting query that combines:

- employee ID
- category
- total sales
- total profit
- profitability ratio

This produces a more complete employee-category performance view and shows how the user-defined function can be integrated into larger reporting logic. 

### Stored Procedure for Date-Range Reporting

The project includes a stored procedure, `CalculateTotalRevenue`, which returns:

- total sales
- total profit

for a selected employee across a chosen date range.

This improves reusability because the same logic can be called with different employees and dates, instead of rewriting ad hoc queries each time. It also demonstrates procedural SQL beyond standard SELECT statements.

## Key Insights

The dataset contains **9,994 transaction rows** across **5,009 distinct orders**, covering sales activity from **2014 to 2017**. Overall, the business generated approximately **$2.30M in sales** and **$286.4K in profit**, across **793 customers**, **1,862 products**, and **9 employees**.

### 1. Sales Performance Varies Over Time

The quarterly sales trend for the **Furnishings** category shows clear variation across the four-year period. Sales are strongest in the later quarters, especially in Q4.

- Highest quarter: **Q4-2017**, with approximately **$12.5K** in Furnishings sales  
- Second highest: **Q4-2016**, with approximately **$12.1K**  
- Lowest quarter: **Q1-2014**, with approximately **$1.6K**  
- Other low-performing quarters include **Q2-2014 (~$2.2K)** and **Q1-2017 (~$2.8K)**  

This suggests that 'Furnishings' sales are not evenly distributed across time, with stronger performance concentrated toward the end of the year.  Q4 appears to be the strongest period, suggesting that inventory planning and promotions for this category should be focused on end-of-year demand.

### 2. Heavy Discounts Often Reduce Profitability

The discount analysis shows that higher discounts do not always improve profit. Several categories perform well with no or low discounts but become unprofitable when discounts increase.

For example, **Binders** generated approximately **$39.3K profit** with no discount and **$29.4K profit** with low discounts, but high discounts resulted in a **$38.5K loss**. A similar pattern appears in **Tables**, where no discount generated around **$13.3K profit**, while medium discounts produced a **$30.7K loss**. **Machines** also declined from **$27.1K profit** with no discount to a **$19.6K loss** under high discounts.

This shows that discounting can increase order activity, but aggressive discounts can significantly reduce margins. Discount strategies should be reviewed carefully and applied selectively, especially in categories such as **Binders, Tables, Machines, and Appliances**, where profit is highly sensitive to discount levels.

### 3. Profitability Differs by Customer Segment

Customer segment analysis shows that the most profitable categories vary by segment, but **Copiers** consistently stand out as a high-profit category.

Across segments, the top profit categories were:

- **Consumer:** Copiers (**$24.1K profit**) and Phones (**$23.8K profit**)
- **Corporate:** Copiers (**$19.0K profit**) and Accessories (**$12.7K profit**)
- **Home Office:** Copiers (**$12.5K profit**) and Phones (**$8.9K profit**)

A key finding is that **Copiers rank 1st by profit across all three segments**, even though they do not always rank highest by sales volume. For example, Copiers rank only **8th by sales** in both the Consumer and Corporate segments, but **1st by profit** in both segments. This indicates that high sales volume does not always equal high profitability, and that segment-level strategy should prioritise high-margin categories rather than only high-revenue categories.

### 4. Employee Profit Contribution Is Category-Dependent

Employee performance is not evenly distributed across product categories. Some employees rely heavily on a small number of categories for profit, which suggests that category mix plays an important role in performance evaluation.

For example, **Employee 3** generated **41.4%** of their profit from Binders, while **Employee 8** generated **42.0%** of their profit from Copiers and **20.4%** from Accessories. **Employee 5** also showed strong dependence on Copiers, which contributed **25.9%** of their total profit.

This indicates that employee performance should not be assessed only by total sales or total profit. Category-level contribution provides a clearer view of strengths, specialisation areas, and potential training opportunities.

Employee contribution analysis shows that employees rely on different categories for profit. Some employees have a more balanced category mix, while others depend heavily on one category.

Examples:

- **Employee 3**
  - Binders contribute **41.4%** of total employee profit  
  - Accessories contribute **14.0%**

- **Employee 8**
  - Copiers contribute **42.0%** of total employee profit  
  - Accessories contribute **20.4%**

- **Employee 5**
  - Copiers contribute **25.9%** of total employee profit  
  - Accessories contribute **15.6%**

- **Employee 6**
  - Binders contribute **27.8%** of total employee profit  
  - Copiers contribute **15.7%**

This indicates that employee performance is strongly affected by category mix. For performance review or training, it would be more useful to look at category-level contribution instead of only total sales or total profit.

### 5. Profitability Ratio Highlights Strong and Weak Category Combinations

The user-defined function calculates the profitability ratio as **Profit / Sales**, helping compare how efficiently sales are converted into profit.

Some employee-category combinations show strong profitability:

- Employee 1 — Labels: **47.9%**
- Employee 3 — Labels: **47.4%**
- Employee 1 — Paper: **45.7%**
- Employee 5 — Copiers: **45.3%**
- Employee 1 — Copiers: **45.0%**

Other combinations show negative profitability:

- Employee 5 — Tables: **-21.3%**
- Employee 7 — Supplies: **-20.1%**
- Employee 3 — Furnishings: **-17.0%**
- Employee 8 — Machines: **-16.5%**
- Employee 8 — Tables: **-16.5%**

This confirms that not all sales contribute positively to profit. Categories such as **Labels, Paper, and Copiers** show strong profitability in some cases, while **Tables, Supplies, Machines, and Furnishings** require closer review.

### Core Issue

The main issue is not sales volume alone. The business generated strong total sales, but profitability varies significantly by **discount level**, **product category**, **customer segment**, and **employee-category combination**.

Some categories generate revenue but become unprofitable under heavier discounts, while others, such as **Copiers, Labels, and Paper** show stronger profit efficiency. A more effective strategy would focus on protecting high-margin categories, controlling discount levels, and using segment-level and employee-level insights to guide sales and performance decisions.

## Key Insights  

### 4. Employee Profit Contribution by Category

Employee contribution analysis shows that employees rely on different categories for profit. Some employees have a more balanced category mix, while others depend heavily on one category.

Examples:

- **Employee 3**
  - Binders contribute **41.4%** of total employee profit  
  - Accessories contribute **14.0%**

- **Employee 8**
  - Copiers contribute **42.0%** of total employee profit  
  - Accessories contribute **20.4%**

- **Employee 5**
  - Copiers contribute **25.9%** of total employee profit  
  - Accessories contribute **15.6%**

- **Employee 6**
  - Binders contribute **27.8%** of total employee profit  
  - Copiers contribute **15.7%**

This indicates that employee performance is strongly affected by category mix. For performance review or training, it would be more useful to look at category-level contribution instead of only total sales or total profit.

### 5. Profitability Ratio by Employee and Category

The user-defined function calculates the profitability ratio as:

`Profitability Ratio = Profit / Sales`

The results show that some employee-category combinations are highly profitable, while others create losses.

Strong profitability examples:

- Employee 1 — Labels: **47.9% profitability ratio**
- Employee 3 — Labels: **47.4%**
- Employee 1 — Paper: **45.7%**
- Employee 5 — Copiers: **45.3%**
- Employee 1 — Copiers: **45.0%**

Weak or negative profitability examples:

- Employee 5 — Tables: **-21.3%**
- Employee 7 — Supplies: **-20.1%**
- Employee 3 — Furnishings: **-17.0%**
- Employee 8 — Machines: **-16.5%**
- Employee 8 — Tables: **-16.5%**

This confirms that not all revenue contributes positively to profit. Categories such as **Labels, Paper, and Copiers** show strong profitability in some employee-category combinations, while **Tables, Supplies, Machines, and Furnishings** show negative profitability in others.

### 6. Reusable Employee Reporting

The stored procedure allows sales and profit to be calculated dynamically by employee and date range. For example, it can return total sales and total profit for **Employee 3** during **December 2016** without rewriting the query.

This makes the project stronger than a set of one-off queries because it supports repeatable reporting. The same logic can be reused for different employees, periods, and performance checks.

### Overall Issue

The analysis shows that the business should not focus only on increasing sales volume. Profitability varies significantly by discount level, category, customer segment, and employee-category combination.

The main issue is that some areas generate revenue but reduce profit, especially when heavy discounts are applied. A stronger strategy would focus on profitable categories such as **Copiers, Labels, Paper, and Phones**, while reviewing high-risk categories such as **Tables, Machines, Supplies, and heavily discounted Binders**.

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
