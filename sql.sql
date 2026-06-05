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
  For each signup month, show what amount of customers still had an active contract 1 month later, 
  2 months later, and 3 months later.
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
  select distinct(signup_month),
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

"""2.a
  USER_EVENTS
- event_id
- user_id
- company_id
- event_date
Question:
Write a SQL query that shows weekly user retention by signup cohort.
For each week a user first logged in, 
  show what percentage of those users came back in week 1, week 2, and week 3 after their first login.
  
  Output:
SIGNUP_WEEK
TOTAL_USERS: Total users = number of users whose first ever login happened in that signup week.
RETAINED_WEEK_1  (count)
RETAINED_WEEK_2  (count)
RETAINED_WEEK_3  (count)
PCT_RETAINED_WEEK_1
PCT_RETAINED_WEEK_2
PCT_RETAINED_WEEK_3
  A user is "retained" in week N if they logged in at least once during that week
  
User first logged in during Week 1 of January → that's their signup week
They logged in again during Week 3 of January → that's 2 weeks after signup

So they would be:
Retained week 1 = No (no login in week 2)
Retained week 2 = Yes (logged in during week 3)
Retained week 3 = depends if they logged in week 4
  """
with first as (
  select distinct(user_id), min(date_trunc('week',event_date)) as signup_week
  from user_events
  group by 1)
  
  select distinct(signup_week) as signup_week,
  count(distinct(user_id)) as total_users,
  
  count(distinct(case when 
  exists (
  select 1 from user_events e
  where e.user_id = first.user_id -- acts like a semi-join.but only return TRUE/FALSE, not extra rows
  and date_trunc('week',event_date)=signup_week + interval '1 week'
) then user_id end
  )) as RETAINED_WEEK_1,
  count(distinct(case when exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and
  date_trunc('week',event_date) =signup_week + interval '2 week'
  ) then user_id end
  )) 
  as RETAINED_WEEK_2,
  count(distinct(case when exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date) =signup_week + interval '3 week'
  ) then user_id end
  )) 
  as RETAINED_WEEK_3,
count(distinct(case when 
  exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date)=signup_week + interval '1 week'
) then user_id end
  )) ::numeric/ nullif(count(distinct(user_id)),0) as PCT_RETAINED_WEEK_1,
  count(distinct(case when 
  exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date)=signup_week + interval '2 week'
) then user_id end
  )) ::numeric/ nullif(count(distinct(user_id)),0) as PCT_RETAINED_WEEK_2,
   count(distinct(case when 
  exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date)=signup_week + interval '3 week'
) then user_id end
  )) ::numeric/ nullif(count(distinct(user_id)),0) as PCT_RETAINED_WEEK_3
  from first 
  group by 1

  
  
"""3. Churn Rate
Churn Rate = Customers lost this month / Customers active last month
  
CONTRACTS
- contract_id
- customer_id
- contract_start_date
- contract_end_date (NULL if still active)

Question:
Write a SQL query that returns for each month:
  If a customer has a contract start on 1/1/2025 and then end on 1/31/2025 and then have another contract
  start from 2/1/2025 and null in end date, it will not consider as a churned customer in anytime

MONTH
ACTIVE_CUSTOMERS (active this month)
CHURNED_CUSTOMERS (were active last month, not active this month)
CHURN_RATE (churned / last month's active)"""

with month as 
  ((select min (date_trunc('month',contract_start_date)) as min, 
  max(date_trunc('month',contract_end_date)) as max 
  from contracts), 
  mon as 
  (select generate_series(min,
  max, 
  interval '1 month') 
  as signup_month 
  from month),
active as (
  select signup_month as month,
  count(distinct(
  customer_id
  )) as active_customer
  from mon 
  left join contracts 
  on singup_month>= date_trunc('month',contract_start_date)
  and (signup_month <= date_trunc('month',contract_end_date)
  or contract_end_date is null)
  group by 1
),
  active_last as (
  select month,
  active_customer,
  LAG(active_customer)
  over (
  order by month
  ) as previous_month_active
  from active
  ),
  churn as (
   select signup_month as month,
  count(distinct(
  customer_id
  )) as churn_customer
  from mon 
  left join contracts 
  on (singup_month - interval '1 month'>= date_trunc('month',contract_start_date) 
  and (signup_month - interval '1 month' <= date_trunc('month',contract_end_date) or contract_end_date is null) 
  and NOT EXISTS (
          SELECT 1
          FROM contracts c_curr
          WHERE c_curr.customer_id = contracts.customer_id
            AND DATE_TRUNC('month', c_curr.contract_start_date) <= mon.signup_month
            AND (
                c_curr.contract_end_date IS NULL
                OR DATE_TRUNC('month', c_curr.contract_end_date) >= mon.signup_month
            )
  group by 1
  )))
  select active_last.month,
  active_last.active_customer as active_customers,
  churn.churn_customer as churned_customers,
  churn.churn_customer::numeric/(nullif(active_last.previous_month_active,0)) as churn_rate
  from active_last
  left join churn 
  on active_last.month = churn.month
  
  
