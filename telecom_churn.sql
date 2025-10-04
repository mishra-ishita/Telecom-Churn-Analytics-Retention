create database churn;
use churn;
select * from telecom_churn;

UPDATE telecom_churn
SET Value_Deal = NULL
WHERE TRIM(Value_Deal) = '';

UPDATE telecom_churn
SET Monthly_Charge = NULL
WHERE Monthly_Charge < 0;

UPDATE telecom_churn
SET Phone_Service = 'No'
WHERE Phone_Service IS NULL;

select * from telecom_churn;
SET SQL_SAFE_UPDATES = 0;

-- 1.Churn Rate by State with Ranking 
WITH state_churn AS (
    SELECT 
        State,
        COUNT(*) AS Total_Customers,
        SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS Churned_Customers,
        ROUND(100.0 * SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Churn_Rate
    FROM telecom_churn
    GROUP BY State
)
SELECT 
    State,
    Total_Customers,
    Churned_Customers,
    Churn_Rate,
    RANK() OVER (ORDER BY Churn_Rate DESC) AS Churn_Rank
FROM state_churn
ORDER BY Churn_Rank;

-- 2.Top Revenue Generating Customers 
SELECT 
    Customer_ID,
    State,
    Total_Revenue,
    RANK() OVER (ORDER BY Total_Revenue DESC) AS Revenue_Rank
FROM telecom_churn
LIMIT 10;

-- 3.Service Feature Adoption Rate 
SELECT 
    ROUND(100.0 * SUM(CASE WHEN Online_Security = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Online_Security,
    ROUND(100.0 * SUM(CASE WHEN Online_Backup = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Online_Backup,
    ROUND(100.0 * SUM(CASE WHEN Device_Protection_Plan = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Device_Protection,
    ROUND(100.0 * SUM(CASE WHEN Premium_Support = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Premium_Support,
    ROUND(100.0 * SUM(CASE WHEN Streaming_TV = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Streaming_TV,
    ROUND(100.0 * SUM(CASE WHEN Streaming_Movies = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Pct_Streaming_Movies
FROM telecom_churn;

-- 4.Churn Rate by Contract Type and Tenure Bucket 
WITH tenure_buckets AS (
    SELECT 
        Customer_ID,
        Contract,
        CASE 
            WHEN Tenure_in_Months < 6 THEN '0-6 Months'
            WHEN Tenure_in_Months BETWEEN 6 AND 12 THEN '6-12 Months'
            WHEN Tenure_in_Months BETWEEN 13 AND 24 THEN '13-24 Months'
            ELSE '25+ Months'
        END AS Tenure_Bucket,
        Customer_Status
    FROM telecom_churn
)
SELECT 
    Contract,
    Tenure_Bucket,
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS Churned_Customers,
    ROUND(100.0 * SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Churn_Rate
FROM tenure_buckets
GROUP BY Contract, Tenure_Bucket
ORDER BY Contract, Tenure_Bucket;
  
  
-- 5.Top Churn Reasons per State 
WITH reason_rank AS (
    SELECT 
        State,
        Churn_Reason,
        COUNT(*) AS Reason_Count,
        ROW_NUMBER() OVER (PARTITION BY State ORDER BY COUNT(*) DESC) AS rn
    FROM telecom_churn
    WHERE Customer_Status = 'Churned'
    GROUP BY State, Churn_Reason
)
SELECT State, Churn_Reason, Reason_Count
FROM reason_rank
WHERE rn = 1
ORDER BY Reason_Count DESC;


-- 6.Churn Rate by Age Decile 
WITH age_deciles AS (
    SELECT 
        Customer_ID,
        Customer_Status,
        NTILE(10) OVER (ORDER BY Age) AS Age_Decile
    FROM telecom_churn
)
SELECT 
    Age_Decile,
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS Churned_Customers,
    ROUND(100.0 * SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS Churn_Rate
FROM age_deciles
GROUP BY Age_Decile
ORDER BY Age_Decile;


-- 7.Cohort-style Tenure Retention 
SELECT 
    CASE 
        WHEN Tenure_in_Months BETWEEN 0 AND 6 THEN '0-6 Months'
        WHEN Tenure_in_Months BETWEEN 7 AND 12 THEN '7-12 Months'
        WHEN Tenure_in_Months BETWEEN 13 AND 24 THEN '13-24 Months'
        ELSE '25+ Months'
    END AS Tenure_Bucket,
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS Churned_Customers,
    ROUND(100.0 * (1 - (SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*))), 2) AS Retention_Rate
FROM telecom_churn
GROUP BY Tenure_Bucket
ORDER BY Tenure_Bucket;


-- 8.Churn Contribution by Revenue Segment 
WITH revenue_quartiles AS (
    SELECT 
        Customer_ID,
        Customer_Status,
        NTILE(4) OVER (ORDER BY Total_Revenue) AS Revenue_Quartile
    FROM telecom_churn
)
SELECT 
    Revenue_Quartile,
    COUNT(*) AS Total_Customers,
    SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS Churned_Customers,
    ROUND(100.0 * SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) / 
        (SELECT COUNT(*) FROM telecom_churn WHERE Customer_Status = 'Churned'), 2) AS Percent_of_Total_Churn
FROM revenue_quartiles
GROUP BY Revenue_Quartile
ORDER BY Revenue_Quartile;


-- 9.Customers with High Revenue but Short Tenure
SELECT 
    Customer_ID,
    State,
    Tenure_in_Months,
    Total_Revenue,
    ROUND(Total_Revenue / NULLIF(Tenure_in_Months,0), 2) AS Revenue_per_Month
FROM telecom_churn
WHERE Customer_Status = 'Churned'
AND Tenure_in_Months <= 6
ORDER BY Revenue_per_Month DESC
LIMIT 10;


-- 10.Retention Opportunity Segments 
SELECT 
    Customer_ID,
    CASE 
        WHEN Contract = 'Month-to-Month' AND Total_Revenue > 5000 AND Customer_Status = 'Churned'
            THEN 'High Value - Short Contract'
        WHEN Contract IN ('One Year', 'Two Year') AND Customer_Status = 'Stayed'
            THEN 'Loyal Long-Term'
        WHEN Total_Revenue < 1000 AND Customer_Status = 'Churned'
            THEN 'Low Value - Churned'
        ELSE 'Other'
    END AS Segment
FROM telecom_churn LIMIT 15;

-- 11.Impact of Extra Data Charges on Churn
SELECT 
    Customer_Status,
    COUNT(*) AS Total_Customers,
    ROUND(AVG(Total_Extra_Data_Charges), 2) AS Avg_Extra_Data_Charges,
    ROUND(SUM(Total_Extra_Data_Charges), 2) AS Total_Extra_Data_Charges
FROM telecom_churn
GROUP BY Customer_Status
ORDER BY Total_Extra_Data_Charges DESC;

-- 12.Churn Category Frequency
SELECT 
    Churn_Category,
    COUNT(*) AS Total_Churned
FROM telecom_churn
WHERE Customer_Status = 'Churned'
GROUP BY Churn_Category
ORDER BY Total_Churned DESC;


-- 13.Churn Reasons by Age Group
SELECT 
    CASE 
        WHEN Age < 25 THEN 'Under 25'
        WHEN Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN Age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS Age_Group,
    Churn_Reason,
    COUNT(*) AS Reason_Count
FROM telecom_churn
WHERE Customer_Status = 'Churned'
GROUP BY Age_Group, Churn_Reason
ORDER BY Reason_Count DESC;


-- 14.New Customers Joined — Profile Summary
SELECT 
    COUNT(*) AS Total_New_Customers,
    ROUND(AVG(Age), 1) AS Avg_Age,
    ROUND(AVG(Tenure_in_Months), 1) AS Avg_Tenure,
    ROUND(AVG(Number_of_Referrals), 1) AS Avg_Referrals,
    (SELECT State 
     FROM telecom_churn 
     WHERE Customer_Status = 'Joined' 
     GROUP BY State 
     ORDER BY COUNT(*) DESC LIMIT 1) AS Top_State,
    (SELECT Internet_Type 
     FROM telecom_churn 
     WHERE Customer_Status = 'Joined' 
     GROUP BY Internet_Type 
     ORDER BY COUNT(*) DESC LIMIT 1) AS Top_Internet_Type,
    (SELECT Contract 
     FROM telecom_churn 
     WHERE Customer_Status = 'Joined' 
     GROUP BY Contract 
     ORDER BY COUNT(*) DESC LIMIT 1) AS Top_Contract
FROM telecom_churn
WHERE Customer_Status = 'Joined';



-- 15.Correlation Prep — Export Numeric Fields
SELECT 
    Customer_ID,
    Age,
    Number_of_Referrals,
    Tenure_in_Months,
    Monthly_Charge,
    Total_Charges,
    Total_Refunds,
    Total_Extra_Data_Charges,
    Total_Long_Distance_Charges,
    Total_Revenue,
    CASE 
        WHEN Customer_Status = 'Churned' THEN 1
        ELSE 0
    END AS Churn_Flag
FROM telecom_churn limit 15;