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

  """ Date Spine 2
  Interview Question
You are given the following table:

subscriptions
customer_id	start_date	end_date
A	2026-01-15	2026-03-10
B	2026-02-01	NULL
C	2026-03-20	2026-04-15
Business Definition

A customer is considered active in a month if their subscription overlaps with any day in that month.

For example:

Customer A is active in January, February, and March.
Customer B is active from February onward.
Customer C is active in March and April.
Question

Write a SQL query that returns the number of active customers for every month between:

2026-01-01

and

2026-05-01

Expected output:

month	active_customers
2026-01-01	?
2026-02-01	?
2026-03-01	?
2026-04-01	?
2026-05-01	?
Interview Follow-up #1

Now suppose management also wants to know:

How many new customers started in each month?

Add a column:

month	active_customers	new_customers
Interview Follow-up #2

Now add another column:

How many customers churned in each month?

A customer is considered churned in the month containing their end_date.

month	active_customers	new_customers	churned_customers
Interview Follow-up #3 (Senior Level)

Now calculate:

Net Customer Change
=
New Customers - Churned Customers

for each month."""
 with month as 
  (select 
  generate_series('2026-01-01'::date, 
  '2026-05-01'::date, 
  interval '1 month')::date as month) 
  select month, 
  count(distinct( customer_id)) as active_customers, 
  count(distinct(case when t1.month=date_trunc('month',start_date) 
  then customer_id end)) as new_customers, 
  count(distinct(case when t1.month = date_trunc('month', t2.end_date))) as churned_customers,
   count(distinct(case when t1.month=date_trunc('month',start_date) 
  then customer_id end))
  -
  count(distinct(case when t1.month = date_trunc('month', t2.end_date)))
  as net_change
  from month t1 
  left join subscriptions t2 on t1.month>= date_trunc('month',start_date) 
  and (t1.month <= date_trunc('month',t2.end_date) or t2.end_date is null
  group by month
  order by month 
"""2. Cohort Retention 
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
  where first.customer_id = contracts.customer_id
  and signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ) then customer_id else end)
) as retained_month_1,
  
  count(distinct(
  case when (exists (
  select 1 from contracts
  where first.customer_id = contracts.customer_id
  and
  signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where first.customer_id = contracts.customer_id
  and
  signup_month + interval '2 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '2 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  then customer_id else end)
) as retained_month_2,

  count(distinct(
  case when (exists (
  select 1 from contracts
  where first.customer_id = contracts.customer_id
  and
  signup_month + interval '1 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '1 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where first.customer_id = contracts.customer_id
  and
  signup_month + interval '2 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '2 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  and (exists (
  select 1 from contracts
  where first.customer_id = contracts.customer_id
  and
  signup_month + interval '3 month' >= date_trunc('month', contract_start_date)
  and (signup_month + interval '3 month' <= date_trunc('month', contract_end_date)
  or contract_end_date is null)
  ))
  then customer_id else end)
) as retained_month_3
  
from first
group by 1
order by 1

"""2.Normal cohort retention
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
  date_trunc('week',event_date) = signup_week + interval '2 week'
  ) then user_id end
  )) 
  as RETAINED_WEEK_2,
  count(distinct(case when exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date) = signup_week + interval '3 week'
  ) then user_id end
  )) 
  as RETAINED_WEEK_3,
count(distinct(case when 
  exists (
  select 1 from user_events e
  where e.user_id = first.user_id
  and date_trunc('week',event_date)= signup_week + interval '1 week'
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

  """ 3. normal Rentention 
  Question:
Of users active in Month M, how many were active again in Month M+1?
You're looking at all active users, regardless of when they signed up.
| User | Jan | Feb |
| ---- | --- | --- |
| A    | ✓   | ✓   |
| B    | ✓   | ✗   |
| C    | ✓   | ✓   |
| D    | ✗   | ✓   |

  | user | event_date |
| ---- | ----- |
| A    | Jan   |
| A    | Feb   |
| B    | Jan   |
| C    | Feb   |


  """
  with monthly_users as (
    select distinct
        user_id,
        date_trunc('month', event_date) as month
    from user_events

)

select
    m1.month,
    count(distinct m1.user_id) as active_users,
    count(distinct m2.user_id) as retained_users,
    count(
        distinct case
            when m2.user_id is null
            then m1.user_id
        end
    ) as churned_users,
    count(distinct m2.user_id) * 1.0
        / count(distinct m1.user_id)
        as retention_rate,
    count(
        distinct case
            when m2.user_id is null
            then m1.user_id
        end
    ) * 1.0
        / count(distinct m1.user_id)
        as churn_rate

from monthly_users m1
left join monthly_users m2
    on m1.user_id = m2.user_id
   and m2.month = m1.month + interval '1 month' -- This is for retain / churn in next month
group by 1
order by 1;

  
  
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

  """another churn rate 
  Subscription business
A customer churned if:

active on first day of month
NOT active on last day of month
  | customer | start_date | end_date |
| -------- | ---------- | -------- |
| A        | Jan 1      | Mar 15   |
| B        | Jan 1      | NULL     |
| C        | Feb 10     | Apr 20   |

  Monthly churn over time:

month	active_users	churned_users	churn_rate
Jan	100	10	10%
Feb	120	15	12.5%
  """
  
with monthly_users as (
select distinct
    user_id,
    date_trunc('month', event_date) as month
from user_events
),

churn as (
select
    m1.month,
    count(distinct m1.user_id) as active_users,
    count(
        distinct case
            when m2.user_id is null -- active in m1, but missing in m2
            then m1.user_id
        end
    ) as churned_users
from monthly_users m1
left join monthly_users m2
    on m1.user_id = m2.user_id
   and m2.month = m1.month + interval '1 month' -- make sure we are getting the churned user for month 2 is from month 1 active users
group by 1
)

select *,
       churned_users * 1.0 / active_users as churn_rate
from churn

  
  """ 4 Window Function

### inventory_transactions

| sku | transaction_date | inventory_qty |
| --- | ---------------- | ------------- |
| A   | 2026-01-01       | 100           |
| A   | 2026-01-03       | 90            |
| A   | 2026-01-05       | 80            |
| B   | 2026-01-02       | 50            |
| B   | 2026-01-04       | 60            |

**Question:**

Return the latest inventory quantity for each SKU.
and also return:

sku	latest_inventory	previous_inventory
A	80	90
B	60	50
"""
  WITH rn AS (
    SELECT
        sku,
        transaction_date,
        inventory_qty,
        ROW_NUMBER() OVER (
            PARTITION BY sku
            ORDER BY transaction_date DESC
        ) AS rn
    FROM inventory_transactions
)
SELECT
    sku,
    transaction_date,
    inventory_qty
FROM rn
WHERE rn = 1;
--b
with rn as (
  select sku,
  transaction_date,
  inventory_qty,
  ROW_NUMBER() OVER( PARTITION BY sku 
  ORDER BY transaction_date DESC) as rn,
  LAG(inventory_qty) OVER(PARTITION BY sku 
  ORDER BY transaction_date DESC) as previous_inventory
  from inventory_transactions
  )
  select sku,inventory_qty as latest_inventory,
  previous_inventory 
  from rn 
  where rn = 1;
  
"""5. recrusive 
All reports under a manager recursive CTE

An organization table has employee_id, manager_id, and name. 
  Find every direct and indirect report under manager_id = 1, 
  returning employee_id, manager_id, name, the level in the tree, and the full hierarchy_path."""
WITH RECURSIVE reports AS (
    -- base case: direct reports under manager_id = 1
    SELECT
        employee_id,
        manager_id,
        name,
        1 AS level,
        name::text AS hierarchy_path
    FROM organization
    WHERE manager_id = 1
    UNION ALL
    -- recursive case: find reports of previous reports
    SELECT
        o.employee_id,
        o.manager_id,
        o.name,
        r.level + 1 AS level,
        r.hierarchy_path || ' > ' || o.name AS hierarchy_path
    FROM organization o
    JOIN reports r
        ON o.manager_id = r.employee_id
)

SELECT
    employee_id,
    manager_id,
    name,
    level,
    hierarchy_path
FROM reports
ORDER BY level, employee_id;
  
"""6. Island and Gap
inventory
----------
sku
inventory_date
inventory_qty
| sku | inventory_date | inventory_qty |
| --- | -------------- | ------------- |
| A   | Jan 1          | 0             |
| A   | Jan 2          | 0             |
| A   | Jan 3          | 0             |
| A   | Jan 4          | 15            |
| A   | Jan 5          | 0             |
| A   | Jan 6          | 0             |
Question

Find stockout periods lasting at least 2 consecutive days.
| sku | start_date | end_date | days |
| --- | ---------- | -------- | ---- |
| A   | Jan 1      | Jan 3    | 3    |
| A   | Jan 5      | Jan 6    | 2    |"""

  with rn as (
  select sku,inventory_date,ROW_NUMBER() OVER(PARTITION BY sku ORDER BY inventory_date) as rn
  from invenotry_qty
  where inventory_qty = 0
  ),
grp as (
  select sku,inventory_date,
  inventory_date - rn * interval '1 day' as grp
from rn)
select sku,
  min(inventory_date) as start_date,
  max(inventory_date) as end_date,
  count(*) as days
from grp 
group by sku,grp
having count(*) >=2

  """7 Window Function Running total
  Table: 
  deliveries
delivery_date  factory_id  vehicles_delivered
  
  For each factory and month show:

mom_growth_pct
| month | factory | monthly | ytd_running | mom  |
| ----- | ------- | ------- | ----------- | ---- |
| Jan   | TX      | 1000    | 1000        | NULL |
| Feb   | TX      | 1200    | 2200        | 20%  |
| Mar   | TX      | 1500    | 3700        | 25%  |
Note: Running Total Resets every year
"""
with monthly as(select date_trunc('month',delivery_date) as month,
  factory_id, sum(vehicles_delivered) as monthly
  from deliveries
  group by 1,2
  order by 1,2),
  running as(
  select month,factory_id,
  monthly,
  sum(vehicles_delivered) OVER (
  PARTITION BY factory_id, date_trunc('year', year) 
  ORDER BY month
  rows between unbounded preceding and current row) as ytd_running
  from monthly)
   select month,factory_id,
  monthly,ytd_running,
  (monthly - LAG(monthly) OVER(PARTITION BY factory_id ORDER BY month))::numeric
  /
  nullif(LAG(monthly) OVER(PARTITION BY factory_id ORDER BY month),0) as mom
  from running
  order by 1,2


""" 7 days running total
  For each server and day, compute the average CPU usage over the current day plus the previous six days — a 7-day rolling average.
  server_id int	usage_date date	cpu_usage numeric
1	2022-05-01	62.4
1	2022-05-02	58.1

  
  """
  SELECT server_id, usage_date,
       ROUND(AVG(cpu_usage) OVER (PARTITION BY server_id
                                  ORDER BY usage_date
                                  ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7d_avg
FROM server_usage
ORDER BY server_id, usage_date;
  

""" 8. TOP N per group 
  supplier_orders

| supplier | plant | month | spend |
| -------- | ----- | ----- | ----- |
| S1       | TX    | Jan   | 1000  |
| S2       | TX    | Jan   | 900   |
| S3       | TX    | Jan   | 800   |
| S4       | TX    | Jan   | 700   |

Question

For each plant and month, return the top 3 suppliers by total spend.

Output:

| month | plant | supplier | spend |
| ----- | ----- | -------- | ----- |
| Jan   | TX    | S1       | 1000  |
| Jan   | TX    | S2       | 900   |
| Jan   | TX    | S3       | 800   |


  If there is a tie for third place, should I include all ties or return exactly 3 rows?
  if include all ties then dense_rank()
  if only 3 supplier for each group then row_number()
  if need to find the second highest spend then rank(), since there might be no rn=2 if we use dense_rank() and the rn =2 for row_number may be still the highest if the No.1 high has a tie.
  """
  
with t1 as(
  select month, plant,supplier_id, sum(spend) as spend
  from supplier_orders
  group by 1,2,3),
  rn as (
  select month,plant,supplier,spend,
  dense_rank() over(partition by month, plant order by spend desc) as rn
  from t1)
  select month, plant, supplier,spend
  from rn
  where rn<=3
  order by 1,2,3
  
""" table: departments
  id name
  2  D1
  3  D2
  4  D3
  5  D4
  6  D5
  write a query to return following outputs:
  original_id   swapped_id    original_name    swapped_name
  2               3               D1              D2
  3               2               D2              D1
  4               5               D3              D4
  5               4               D4              D3
  6               6               D5              D5
  if the number of the total departments is odd then swap each 2 consecutive department id and name, 
  keep the last department not swapped.
  """
select
    id as original_id,
    case
        when id % 2 = 1 and id != (select max(id) from department)
            then id + 1
        when id % 2 = 0
            then id - 1
        else id
    end as swapped_id,
    name as original_name,
    case
        when id % 2 = 1 and id != (select max(id) from department)
            then lead(name) over (order by id)
        when id % 2 = 0
            then lag(name) over (order by id)
        else name
    end as swapped_name
from department
order by id;



with numbered as (
    select
        id,
        name,
        row_number() over (order by id) as rn
    from department
),

mapped as (
    select
        id,
        name,
        rn,
        case
            when rn % 2 = 1 then rn + 1
            when rn % 2 = 0 then rn - 1
        end as partner_rn
    from numbered
)

select
    m.id as original_id,
    coalesce(p.id, m.id) as swapped_id,
    m.name as original_name,
    coalesce(p.name, m.name) as swapped_name
from mapped m
left join numbered p
    on m.partner_rn = p.rn
order by m.id;

  

