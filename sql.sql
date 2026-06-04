"""1. Date Spine
CONTRACTS
- contract_id
- customer_id  
- contract_start_date
- contract_end_date (NULL if still active)

DATE_TABLE
- date
- month (first day of each month)

  Question:
Write a SQL query that returns for each calendar month:

MONTH
NUMBER_OF_ACTIVE_CONTRACTS
NUMBER_OF_NEW_CONTRACTS
NUMBER_OF_CHURNED_CONTRACTS (contracts that ended that month)"""

with month as 
  (select distinct(month) as month 
  from date_table
  ) 
  select month, 
  count(distinct( case when date_trunc('month',contract_start_date)<= month and (date_trunc('month',contract_end_date) >= month or contract_end_date is null) 
  then contract_id else end)) as number_of_active_contracts, 
  case when date_trunc('month',contract_start_date)= month and (date_trunc('month',contract_end_date) >= month or contract_end_date is null) 
  then contract_id else end)) as number_of_new_contracts, 
  case when date_trunc('month',contract_start_date)<= month and (date_trunc('month',contract_end_date) = month ) 
  then contract_id else end)) as number_of_churned_contracts 
  from month 
  left join contracts 
  on month >= date_trunc('month',contract_start_date) 
  and (month <= date_trunc('month',contract_end_date) or contract_end_date is null) 
  group by 1 
  order by 1 asc

"""2. Retention 
CONTRACTS
- contract_id
- customer_id
- contract_start_date
- contract_end_date (NULL if still active)
  
Question:
Write a SQL query that shows cohort retention. 
  For each signup month, show what amount of customers still had an active contract 1 month later, 2 months later, and 3 months later.
Output:
  SIGNUP_MONTH
TOTAL_CUSTOMERS
RETAINED_MONTH_1
RETAINED_MONTH_2
RETAINED_MONTH_3
Note: If a customer signed up on 1/1/2025 and then ended on 1/30/2025 and then re signed up on 3/1/2025, 
  it will only be consider as the new customer for 1/1/2025 and the retention is only 0 month, the gap between will cut the retention, 
  the question is only ask for new customers' concecutive retention """

with first as (
  select distinct(customer_id), min(date_trunc('month',contract_start_date)) as signup_month
  from contracts
  group by 1
)
  select signup_month,
  count(distinct(customer_id)) as total_customers,
count(distinct(
  case when exists (
  select 1 from contracts
  where 
  signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ) then customer_id else end)
) as retained_month_1,
  
  count(distinct(
  case when (exists (
  select 1 from contracts
  where 
  signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where 
  signup_month + interval '2 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '2 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  then customer_id else end)
) as retained_month_2,

  count(distinct(
  case when (exists (
  select 1 from contracts
  where 
  signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where 
  signup_month + interval '2 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '2 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where 
  signup_month + interval '3 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '3 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  then customer_id else end)
) as retained_month_3
  
from first
group by 1
order by 1

  
