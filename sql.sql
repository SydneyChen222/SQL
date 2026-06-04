--1. Date Spine
"""CONTRACTS
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
  then contract_id else 0 end)) as number_of_active_contracts, 
  case when date_trunc('month',contract_start_date)= month and (date_trunc('month',contract_end_date) >= month or contract_end_date is null) 
  then contract_id else 0 end)) as number_of_new_contracts, 
  case when date_trunc('month',contract_start_date)<= month and (date_trunc('month',contract_end_date) = month ) 
  then contract_id else 0 end)) as number_of_churned_contracts 
  from month 
  left join contracts 
  on month >= date_trunc('month',contract_start_date) 
  and (month <= date_trunc('month',contract_end_date) or contract_end_date is null) 
  group by 1 
  order by 1 aesc
