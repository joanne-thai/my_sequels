# Retail Sales Performance Analysis (MySQL)

## Overview  
This project analyzes retail transactional data using MySQL to identify key drivers of revenue and profitability across products, customers, and discount strategies. The workflow simulates a real-world analytics process, including data validation, cleaning, exploratory analysis, and automated reporting.

---

## Business Problem  
The business lacks clear visibility into how discount strategies and product categories impact profitability. While discounts may increase order volume, their effect on profit margins is unclear, and there is no structured reporting to evaluate performance across segments and employees.

---

## Data Model  
The dataset follows a relational structure where `orders` acts as the central fact table, connected to dimension tables including `product`, `customer`, and `employee`. This structure resembles a star schema, enabling efficient analytical queries across multiple business dimensions.

---

## Data Preparation  
Initial validation and cleaning were performed to ensure data reliability. Record counts and missing values were checked, and inconsistent date formats were standardized using `STR_TO_DATE()`. Table relationships were validated to ensure accurate joins across product, customer, and employee data.

---

## Key Analyses  

### Sales Trend Analysis  
Quarterly sales trends were analyzed to identify seasonality and revenue patterns over time.

### Discount Impact Analysis  
Discount levels were categorized into four groups (No, Low, Medium, High) to evaluate their impact on order volume, total profit, and profitability per transaction.

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