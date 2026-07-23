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

"""
# — Cohort Retention Analysis

You are given a table:

### `orders`

| column      | type |
| ----------- | ---- |
| customer_id | INT  |
| order_date  | DATE |

Each row represents **one purchase**.

---

## Task

For every **cohort month**, calculate the retention rate in Month 0, Month 1, Month 2...

A customer's **cohort month** is the month of their **first-ever purchase**.

Output:

| cohort_month | months_since_signup | retained_customers | cohort_size | retention_rate |
| ------------ | ------------------- | ------------------ | ----------- | -------------- |
| 2024-01      | 0                   | 100                | 100         | 1.0000         |
| 2024-01      | 1                   | 75                 | 100         | 0.7500         |
| 2024-01      | 2                   | 61                 | 100         | 0.6100         |
| 2024-02      | 0                   | 120                | 120         | 1.0000         |
| 2024-02      | 1                   | 92                 | 120         | 0.7667         |

---

### Definitions

A customer is **retained** in Month N if they made **at least one purchase** in that month.

Example:

Customer 1

| order_date |
| ---------- |
| 2024-01-10 |
| 2024-01-25 |
| 2024-02-08 |
| 2024-04-02 |

Their contribution is:

| cohort  | month_since_signup |
| ------- | ------------------ |
| 2024-01 | 0                  |
| 2024-01 | 1                  |
| 2024-01 | 3                  |

Notice:

* Two purchases in January still count as **one retained customer** in Month 0.
* Missing March means **no row for Month 2** for this customer.

  """
  WITH first_order AS (
    SELECT
        customer_id,
        MIN(date_trunc('month', order_date)) OVER (PARTITION BY customer_id) AS first_month,
        (
            EXTRACT(YEAR FROM date_trunc('month', order_date)) * 12
            + EXTRACT(MONTH FROM date_trunc('month', order_date))
        )
        -
        (
            EXTRACT(YEAR FROM MIN(date_trunc('month', order_date)) OVER (PARTITION BY customer_id)) * 12
            + EXTRACT(MONTH FROM MIN(date_trunc('month', order_date)) OVER (PARTITION BY customer_id))
        ) AS months_since_signup
    FROM orders
    GROUP BY customer_id, date_trunc('month', order_date)
),
cohort AS (
    SELECT
        customer_id,
        first_month,
        months_since_signup,
        COUNT(CASE WHEN months_since_signup = 0 THEN customer_id END)
            OVER (PARTITION BY first_month) AS cohort_size
    FROM first_order
)
SELECT
    to_char(first_month, 'YYYY-MM') AS cohort_month,
    months_since_signup,
    COUNT(DISTINCT customer_id) AS retained_customers,
    cohort_size,
    ROUND(COUNT(DISTINCT customer_id)::numeric / NULLIF(cohort_size, 0), 4) AS retention_rate
FROM cohort
GROUP BY first_month, months_since_signup, cohort_size
ORDER BY first_month, months_since_signup;
  """
## Q3 — Cohort Revenue Retention
orders
------
customer_id
order_date
revenue

A customer’s `cohort_month` is the month of their first purchase.
Return:
```text
cohort_month | months_since_signup | monthly_revenue | month0_revenue | revenue_retention_rate
Definitions:

* `monthly_revenue`: total revenue generated by that cohort in that month_since_signup.
* `month0_revenue`: total revenue generated by that cohort in Month 0.
* `revenue_retention_rate = monthly_revenue / month0_revenue`
* Round rate to 4 decimals.

Example:

| cohort_month | months_since_signup | monthly_revenue | month0_revenue | revenue_retention_rate |
| ------------ | ------------------: | --------------: | -------------: | ---------------------: |
| 2024-01      |                   0 |            1000 |           1000 |                 1.0000 |
| 2024-01      |                   1 |             750 |           1000 |                 0.7500 |
| 2024-01      |                   2 |             620 |           1000 |                 0.6200 |

    """
  WITH first_purchase AS (
    SELECT
        customer_id,
        date_trunc('month', order_date)::date AS order_month,
        MIN(date_trunc('month', order_date)::date) OVER (
            PARTITION BY customer_id
        ) AS first_month,
        revenue
    FROM orders
),
    month0 as (
    select customer_id, first_month as cohort_month,
    sum(revenue) as month0_revenue
    from first_purchase
    where first_month = order_month
    group by 1,2
    ),
    month01 as (
    select cohort_month,
    sum(month0_revenue) as month0_revenue
    from month0
    group by 1
    ),
    
month AS (
    SELECT
        customer_id,
        first_month,
        order_month,
        (
            EXTRACT(YEAR FROM order_month) * 12
            + EXTRACT(MONTH FROM order_month)
        )
        -
        (
            EXTRACT(YEAR FROM first_month) * 12
            + EXTRACT(MONTH FROM first_month)
        ) AS month_since_signup,
        SUM(revenue) AS revenue
    FROM first_purchase
    GROUP BY 1, 2, 3, 4
),
    t3 as (
    select first_month,month_since_signup,
    sum(revenue) as revenue
    from month
    group by 1,2
    )
select 
    t3.first_month as cohort_month,
    t3.month_since_signup as months_since_signup,
    t3.revenue as monthly_revenue,
    t2.month0_revenue as month0_revenue,  
    ROUND(t3.revenue::numeric / NULLIF(t2.month0_revenue, 0), 4) AS revenue_retention_rate 
    from t3
    left join month01 t2 
    on t3.first_month = t2.cohort_month
    order by 1,2



  
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


"""showing median for employee's salary
  +--------------+---------+
| Column Name  | Type    |
+--------------+---------+
| id           | int     |
| company      | varchar |
| salary       | int     |
+--------------+---------+
id is the primary key (column with unique values) for this table.
Each row of this table indicates the company and the salary of one employee.
 

Write a solution to find the rows that contain the median salary of each company. While calculating the median, when you sort the salaries of the company, break the ties by id.

Return the result table in any order.

The result format is in the following example.
  Explanation: 
For company A, the rows sorted are as follows:
+----+---------+--------+
| id | company | salary |
+----+---------+--------+
| 3  | A       | 15     |
| 2  | A       | 341    |
| 5  | A       | 451    | <-- median
| 6  | A       | 513    | <-- median
| 1  | A       | 2341   |
| 4  | A       | 15314  |
+----+---------+--------+
For company B, the rows sorted are as follows:
+----+---------+--------+
| id | company | salary |
+----+---------+--------+
| 8  | B       | 13     |
| 7  | B       | 15     |
| 12 | B       | 234    | <-- median
| 11 | B       | 1221   | <-- median
| 9  | B       | 1154   |
| 10 | B       | 1345   |
+----+---------+--------+
For company C, the rows sorted are as follows:
+----+---------+--------+
| id | company | salary |
+----+---------+--------+
| 17 | C       | 65     |
| 13 | C       | 2345   |
| 14 | C       | 2645   | <-- median
| 15 | C       | 2645   | 
| 16 | C       | 2652   |
+----+---------+--------+
  """
with cte as (
    select 
        id,
        company,
        salary,
        row_number() over(partition by company order by salary, id) as rn,
        count(*) over(partition by company) as cnt
    from employee
)
select id, company, salary
from cte
where rn between (cnt + 1) / 2 and (cnt + 2) / 2;

"""
Sessionization
You are given a table:
### `events`
| column     | type      |
| ---------- | --------- |
| user_id    | INT       |
| event_time | TIMESTAMP |
| event_type | TEXT      |

A new session starts when either:
1. It is the user's first event
2. The time gap from the previous event is greater than 30 minutes
Write a PostgreSQL query to return:

| user_id | session_id | session_start | session_end | event_count |
| ------- | ---------: | ------------- | ----------- | ----------: |

Requirements:
* `session_id` should start from `1` for each user.
* Events exactly **30 minutes apart** belong to the same session.
* Events more than **30 minutes apart** start a new session.
* Sort by `user_id`, `session_id`.
  """
  with t1 as 
  (select user_id, event_time, 
  LAG(event_time) over(partition by user_id order by event_time) as previous, 
  event_type 
  from events order by 1,2), 
  
  gaps as 
  (select user_id, 
  event_time, 
  previous, 
  case when previous is null then null 
  else EXTRACT(EPOCH FROM (event_time -previous)) / 60 
  end as gap, 
  event_type 
  from t1) ,
  
  session as 
  (select user_id, 
  event_time, 
  previous, 
  row_number () over (partition by user_id order by event_time) as session_id 
  from gaps 
  where gap is null
  or gap > 30),

  session_e as (
  select t1.user_id, 
  t1.session_id, 
  t1.event_time as session_start, 
  lead(t1.previous) over(partition by user_id order by event_time) as session_end
  from session t1)

select user_id, session_id,session_start,
 COALESCE(t1.session_end, MAX(t2.event_time)) as session_end, 
  count(*) as event_count
from session_e t1
left join gaps t2
on t1.user_id = t2.user_id
and t1.session_start <= t2.event_time 
  and (t1.session_end >= t2.event_time
  or t1.session_end IS NULL)
group by 1,2,3,4
order by 1,2


"""users----
  user_id        INTEGER
signup_date    DATE
job_title      VARCHAR
  file_evnet ----
  user_id         INTEGER
file_id         VARCHAR
event_type      VARCHAR
event_time      TIMESTAMP
  A new session begins whenever the gap between two consecutive events for the same user is more than 30 minutes.
  possible event_type: 
  file_opened    file_edited  comment_added   file_shared
  expected output:
  | user_id | session_number | session_start | session_end | duration_minutes | total_events | distinct_files |
| ------- | -------------- | ------------- | ----------- | ---------------- | ------------ | -------------- |
| 1       | 1              | 09:00         | 09:18       | 18               | 5            | 2              |
| 1       | 2              | 11:10         | 11:44       | 34               | 8            | 4              |
| 2       | 1              | 10:30         | 10:55       | 25               | 3            | 1              |

  """
  with session as (
  select user_id,file_id,
  event_type, event_time,
  LAG(event_time) OVER(PARTITION BY user_id ORDER BY event_time) as previous_time,
    case when  LAG(event_time) OVER(PARTITION BY user_id ORDER BY event_time) is null then null 
  else EXTRACT(EPOCH FROM (event_time -  LAG(event_time) OVER(PARTITION BY user_id ORDER BY event_time))) / 60 
  end as gap
  from file_event
  order by 1,4),
  session2 as 
  (select user_id,file_id,
  event_type,event_time,previous_time,
  gap,
  ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY event_time) as session_number
  from seesion
  where gap is null or gap>30
  order by 1,7
  ),
  session3 as (
  select user_id,session_number,
  event_time as session_start,
  LEAD(previous_time) OVER(PARTITON BY user_id ORDER BY event_time) as session_end
  from session2
  order by 1,2
  )
  select t1.user_id,t1.session_number,
  t1.session_start,
  coalesce(t1.session_end,max(t2.event_time)) as session_end,
   EXTRACT(
        EPOCH FROM (
            COALESCE(t1.session_end,MAX(t2.event_time)) - t1.session_start)) / 60.0 AS duration_minutes,
  count(evnet_type) as total_events,
  count(distinct(file_id)) as distinct_files
  from session3 t1
  left join session t2
  on t1.user_id = t2.user_id
  and t1.session_start <= t2.event_time
  and (t2.event_time<= t1.session_end
  or t1.session_end IS NULL)
  group by 1,2,3,4,5
  order by 1,2,3,4,5
  --Return the average session duration for every user
  
  select user_id,
  avg(duration_minutes) as avg_duration
  from result1
  group by 1
  order by 1
  --Return the percentage of sessions that contain at least one file_shared
  with result as(
    select t1.user_id,t1.session_number,
  t1.session_start,
  coalesce(t1.session_end,max(t2.event_time)) as session_end,
   EXTRACT(
        EPOCH FROM (
            COALESCE(t1.session_end,MAX(t2.event_time)) - t1.session_start)) / 60.0 AS duration_minutes,
  sum(case when event_type = 'file_shared' then 1 else 0 end) as file_shared,
  count(evnet_type) as total_events,
  count(distinct(file_id)) as distinct_files
  from session3 t1
  left join session t2
  on t1.user_id = t2.user_id
  and t1.session_start <= t2.event_time
  and (t2.event_time<= t1.session_end
  or t1.session_end IS NULL)
  group by 1,2,3,4,5
  order by 1,2,3,4,5)
  select sum(case when file_shared = 0 then 0 else 1 end)::numeric / nullif(count(session_number),0) as percentage_file_shared_session
  from result
  
---A product manager believes users become more engaged after they share a file.
---For every user, calculate
 """ 
  average number of events  BEFORE the first file_shared session
average number of events   AFTER the first file_shared session
  Ignore users who never shared a file.
  """
    with shared as (
select user_id,min(event_time) as first_shared_time,
  from file_event
  where event_type = 'file_shared'
  group by 1
  ),
  result as (
   select t1.user_id,t1.session_number,
  t1.session_start,
  coalesce(t1.session_end,max(t2.event_time)) as session_end,
   EXTRACT(
        EPOCH FROM (
            COALESCE(t1.session_end,MAX(t2.event_time)) - t1.session_start)) / 60.0 AS duration_minutes,
  sum(case when event_type = 'file_shared' then 1 else 0 end) as file_shared,
  count(evnet_type) as total_events,
  count(distinct(file_id)) as distinct_files
  from session3 t1
  left join session t2
  on t1.user_id = t2.user_id
  and t1.session_start <= t2.event_time
  and (t2.event_time<= t1.session_end
  or t1.session_end IS NULL)
  group by 1,2,3,4,5
  order by 1,2,3,4,5),
  flag as (
  select user_id,
  first_shared_time,session_number,
  session_start,session_end,total_events,
  case when first_shared_time >= session_start and first_shared_time <= session_end then 'first_shared_session'
  when first_shared_time > session_end then 'session_before'
  when first_shared_time < session_start then 'session_after' end as flag
  from result t1
  inner join shared t2
  on t1.user_id = t2.user_id)
  select user_id, AVG(
    CASE
        WHEN flag = 'session_before'
        THEN total_events::numeric
    END
) as avg_event_before_shared,
  AVG(
    CASE
        WHEN flag = 'session_after'
        THEN total_events::numeric
    END
) as avg_event_after_shared
  from flag
  group by 1
  



  
"""
Purchase Funnel Conversion
Table:
```text
events
------
user_id INT
event_time TIMESTAMP
event_type TEXT
```
Each row is one user event. Relevant event types are:
```text
view_product
add_to_cart
purchase
```
Return one row showing:

| viewed_users | added_users | purchased_users | view_to_cart_rate | cart_to_purchase_rate | view_to_purchase_rate |

Definitions:

* `viewed_users`: users who had at least one `view_product`
* `added_users`: users who had at least one `add_to_cart`
* `purchased_users`: users who had at least one `purchase`
* Conversion rates should be based on distinct users.
* Round rates to 4 decimals.

Example:

* `view_to_cart_rate = added_users / viewed_users`
* `cart_to_purchase_rate = purchased_users / added_users`
* `view_to_purchase_rate = purchased_users / viewed_users`

Use PostgreSQL.
  """

select count(distinct(case when event_type = 'view_product' then user_id end)) as viewed_users,
count(distinct(case when event_type = 'add_to_cart' then user_id end)) as added_users,
count(distinct(case when event_type = 'purchase' then user_id end)) as purchased_users,
round( count(distinct(case when event_type = 'add_to_cart' then user_id end))::numeric
  /
  nullif(count(distinct(case when event_type = 'view_product' then user_id end)),0),4) as view_to_cart_rate,
round( count(distinct(case when event_type = 'purchase' then user_id end))::numeric
  /
  nullif(count(distinct(case when event_type = 'add_to_cart' then user_id end)),0),4) as cart_to_purchase_rate,
round( count(distinct(case when event_type = 'purchase' then user_id end))::numeric
  /
  nullif(count(distinct(case when event_type = 'view_product' then user_id end)),0),4) as view_to_purchase_rate
from events
"""
  if we need sequential funnal analysis 
  like each step is strickly followed by nexrt step
  """
WITH first_view AS (
    SELECT
        user_id,
        MIN(event_time) AS view_time
    FROM events
    WHERE event_type = 'view_product'
    GROUP BY user_id
),
first_cart_after_view AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS cart_time
    FROM events e
    JOIN first_view v
        ON e.user_id = v.user_id
       AND e.event_time >= v.view_time
    WHERE e.event_type = 'add_to_cart'
    GROUP BY e.user_id
),
first_purchase_after_cart AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS purchase_time
    FROM events e
    JOIN first_cart_after_view c
        ON e.user_id = c.user_id
       AND e.event_time >= c.cart_time
    WHERE e.event_type = 'purchase'
    GROUP BY e.user_id
)
SELECT
    COUNT(DISTINCT v.user_id) AS viewed_users,
    COUNT(DISTINCT c.user_id) AS added_users,
    COUNT(DISTINCT p.user_id) AS purchased_users,
    ROUND(COUNT(DISTINCT c.user_id)::numeric / NULLIF(COUNT(DISTINCT v.user_id), 0), 4) AS view_to_cart_rate,
    ROUND(COUNT(DISTINCT p.user_id)::numeric / NULLIF(COUNT(DISTINCT c.user_id), 0), 4) AS cart_to_purchase_rate,
    ROUND(COUNT(DISTINCT p.user_id)::numeric / NULLIF(COUNT(DISTINCT v.user_id), 0), 4) AS view_to_purchase_rate
FROM first_view v
LEFT JOIN first_cart_after_view c
    ON v.user_id = c.user_id
LEFT JOIN first_purchase_after_cart p
    ON v.user_id = p.user_id;

"""
 ----- Resurrected Users
For each month, return:
month	|  resurrected_users
Definition:
A resurrected user is someone who
was active this month
was NOT active last month
BUT had been active sometime before last month
  """
with user_act as (
  select distinct(user_id) as user_id, 
  date_trunc('month',event_date) as active_month 
  from events
  order by 1,2
),
t1 as (
  select user_id, active_month,
  LAG(active_month) over(PARTITION BY user_id Order by active_month) as previous_month,
  from user_act
),
diff as (
  select user_id,active_month,
  case when previous_month is null then null
  else EXTRACT(YEAR FROM AGE(date_trunc('month',active_month), date_trunc('month', previous_month))) * 12 + 
       EXTRACT(MONTH FROM AGE(date_trunc('month', active_month), date_trunc('month', previous_month))) 
  end 
  as gap
  from t1 
)

select active_month as month,
count(distinct(user_id)) as resurrected_users
from diff
  where gap is not null
and gap > 1
group by 1
order by 1

"""
## Q4 — New / Returning / Resurrected Users
Table:
events
------
user_id
event_date
Each row means a user was active on that date.
For each month, return:
month | new_users | returning_users | resurrected_users

Definitions:
A **new user** is active this month and has no activity before this month.
A **returning user** is active this month and was also active last month.
A **resurrected user** is active this month, was **not** active last month, but had activity before last month.
Use PostgreSQL.
  """
with new_user as 
  (select distinct user_id,  
  date_trunc('month', event_date)::date AS event_month, 
    MIN(date_trunc('month', event_date)::date) OVER (
            PARTITION BY user_id
        ) AS first_month 
  from events 
  order by 1,2), 
t1 as (
  select user_id, first_month,
  event_month,
  LAG(event_month) over(PARTITION BY user_id order by event_month) as previous_active_month
  from new_user
  order by 1,2,3
),
  t2 as (
  select user_id, first_month,
  event_month, previous_active_month,
          (
            EXTRACT(YEAR FROM event_month) * 12
            + EXTRACT(MONTH FROM event_month)
        )
        -
        (
            EXTRACT(YEAR FROM previous_active_month) * 12
            + EXTRACT(MONTH FROM previous_active_month)
        ) AS diff
  from t1
  )
  select event_month as month,
  count(distinct(case when event_month = first_month then user_id end)) as new_users,
  count(distinct(case when diff = 1 then user_id end)) as returning_users,
  count(distinct(case when diff > 1 then user_id end)) as resurrected_user
from t2
  group by 1
  order by 1

  -- or
  
  
"""
# Q2 — LTV Curve (Lifetime Value)
orders
------
customer_id
order_date
revenue
```
Each row is one purchase.

For every **cohort month**, calculate the **cumulative LTV curve**.
A customer's **cohort month** is the month of their **first purchase**.

Return:
| cohort_month | months_since_signup | cumulative_ltv |
| ------------ | ------------------- | -------------- |
| 2024-01      | 0                   | 100.00         |
| 2024-01      | 1                   | 185.50         |
| 2024-01      | 2                   | 247.20         |
| 2024-02      | 0                   | 92.30          |
| 2024-02      | 1                   | 176.80         |

### Example

Customer A
| order_date | revenue |
| ---------- | ------- |
| 2024-01-05 | 100     |
| 2024-02-10 | 50      |
| 2024-02-20 | 30      |
| 2024-04-02 | 20      |

Contributes:

| cohort  | month_since_signup | revenue |
| ------- | ------------------ | ------- |
| 2024-01 | 0                  | 100     |
| 2024-01 | 1                  | 80      |
| 2024-01 | 3                  | 20      |

The LTV curve becomes:

| month_since_signup | cumulative_ltv |
| ------------------ | -------------- |
| 0                  | 100            |
| 1                  | 180            |
| 2                  | 180            |
| 3                  | 200            |

Notice the important difference from the cohort retention question:
### Cohort retention

```text
Month0 -> retained users
Month1 -> retained users
Month2 -> retained users
```
### LTV

```text
Month0 -> cumulative revenue
Month1 -> cumulative revenue
Month2 -> cumulative revenue
```
  """
WITH first_purchase AS (
    SELECT
        customer_id,
        date_trunc('month', order_date)::date AS order_month,
        MIN(date_trunc('month', order_date)::date) OVER (
            PARTITION BY customer_id
        ) AS first_month,
        revenue
    FROM orders
),
month AS (
    SELECT
        customer_id,
        first_month,
        order_month,
        (
            EXTRACT(YEAR FROM order_month) * 12
            + EXTRACT(MONTH FROM order_month)
        )
        -
        (
            EXTRACT(YEAR FROM first_month) * 12
            + EXTRACT(MONTH FROM first_month)
        ) AS month_since_signup,
        SUM(revenue) AS revenue
    FROM first_purchase
    GROUP BY 1, 2, 3, 4
),
cohort_size AS (
    SELECT
        first_month AS cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM month
    WHERE month_since_signup = 0
    GROUP BY 1
),
t2 AS (
    SELECT
        first_month AS cohort_month,
        month_since_signup,
        SUM(revenue) AS revenue
    FROM month
    GROUP BY 1, 2
),
t3 AS (
    SELECT
        cohort_month,
        month_since_signup,
        SUM(revenue) OVER (
            PARTITION BY cohort_month
            ORDER BY month_since_signup
        ) AS cumulative_revenue
    FROM t2
)
SELECT
    t3.cohort_month,
    t3.month_since_signup,
    ROUND(t3.cumulative_revenue / cs.cohort_size, 2) AS cumulative_ltv
FROM t3
JOIN cohort_size cs
    ON t3.cohort_month = cs.cohort_month
ORDER BY 1, 2;
"""
## Q5 — Subscription NRR Cohort Curve
Table:
subscriptions
-------------
customer_id
start_date
end_date
mrr

Each row represents a customer subscription.
Return:
cohort_month | months_since_signup | remaining_mrr | initial_mrr | nrr

Definitions:
A customer's `cohort_month` is the month of their `start_date`.

For each cohort and each month since signup:
* `initial_mrr` = total MRR of the cohort in Month 0
* `remaining_mrr` = total MRR from cohort customers who are still active in that month
* `nrr = remaining_mrr / initial_mrr`

A subscription is active in Month N if:
start_date <= month_end
AND (end_date IS NULL OR end_date >= month_start)

Generate months from `2024-01-01` to `2024-06-01`.
Output should include all cohort-month combinations that can exist within that range.
  """
with month as (
  select generate_series (
  '1/1/2024',
  '6/1/2024',
  interval '1 month' 
  )::date as month
),
  t1 as (
SELECT
    s1.month as cohort_month,
    EXTRACT(YEAR FROM AGE(s2.month, s1.month)) * 12 +
    EXTRACT(MONTH FROM AGE(s2.month, s1.month))      AS diff
FROM month s1
JOIN month s2 
  ON s2.month >= s1.month
ORDER BY s1.month, diff
  ),
first_month AS (
    SELECT
        customer_id,
        date_trunc('month', start_date)::date AS cohort_month,
  date_trunc('month',end_date)::date as end_month,
         (
            EXTRACT(YEAR FROM case when date_trunc('month',end_date) >= '6/1/2024' or end_date is null
  then '6/1/2024' else date_trunc('month',end_date)) * 12
            + EXTRACT(MONTH FROM case when date_trunc('month',end_date) >= '6/1/2024' or end_date is null
  then '6/1/2024' else date_trunc('month',end_date))
        )
        -
        (
            EXTRACT(YEAR FROM date_trunc('month',start_date)) * 12
            + EXTRACT(MONTH FROM date_trunc('month',start_date))
        ) AS month_since_signup,
  mrr
    FROM subscriptions
),
  t2 as (
  SELECT
    customer_id,
    cohort_month,
    end_month,
    mrr,
    (cohort_month + (n * INTERVAL '1 month'))::date AS expanded_month,
  n as month_since_signup
FROM first_month,
LATERAL GENERATE_SERIES(0, month_since_signup) AS n
ORDER BY customer_id, expanded_month),
  
  initial as (
  select cohort_month,
  sum(mrr) as initial_mrr
  from t2 
  where expanded_month = cohort_month
  group by 1
  ),
  remaining as (
  select cohort_month,
  expanded_month, 
  month_since_signup,
  sum(mrr) as remaining_mrr
  from t2
  group by 1,2,3
  )

  select t1.cohort_month,
 t1.diff as month_since_signup,
   t2.remaining_mrr,
  t3.initial_mrr,
   ROUND(COALESCE(t2.remaining_mrr, 0)::numeric / NULLIF(t3.initial_mrr, 0), 4) AS nrr
  from t1
  left join initial t3
  on t1.cohort_month = t3.cohort_month
  left join remaining t2 
  on t1.cohort_month = t2.cohort_month
  and t1.diff = t2.month_since_signup
  
  
  

  
WITH months AS (
    SELECT generate_series(
        '2024-01-01'::date,
        '2024-06-01'::date,
        interval '1 month'
    )::date AS calendar_month
),
cohorts AS (
    SELECT DISTINCT
        date_trunc('month', start_date)::date AS cohort_month
    FROM subscriptions
    WHERE start_date >= '2024-01-01'
      AND start_date < '2024-07-01'
),
cohort_month_grid AS (
    SELECT
        c.cohort_month,
        m.calendar_month,
        (
            EXTRACT(YEAR FROM m.calendar_month) * 12
            + EXTRACT(MONTH FROM m.calendar_month)
        )
        -
        (
            EXTRACT(YEAR FROM c.cohort_month) * 12
            + EXTRACT(MONTH FROM c.cohort_month)
        ) AS months_since_signup
    FROM cohorts c
    JOIN months m
        ON m.calendar_month >= c.cohort_month
),
initial_mrr AS (
    SELECT
        date_trunc('month', start_date)::date AS cohort_month,
        SUM(mrr) AS initial_mrr
    FROM subscriptions
    WHERE start_date >= '2024-01-01'
      AND start_date < '2024-07-01'
    GROUP BY 1
),
remaining_mrr AS (
    SELECT
        g.cohort_month,
        g.months_since_signup,
        SUM(CASE
            WHEN s.start_date <= g.calendar_month + interval '1 month' - interval '1 day'
             AND (s.end_date IS NULL OR s.end_date >= g.calendar_month)
            THEN s.mrr
            ELSE 0
        END) AS remaining_mrr
    FROM cohort_month_grid g
    LEFT JOIN subscriptions s
        ON date_trunc('month', s.start_date)::date = g.cohort_month
    GROUP BY g.cohort_month, g.months_since_signup
)
SELECT
    r.cohort_month,
    r.months_since_signup,
    r.remaining_mrr,
    i.initial_mrr,
    ROUND(r.remaining_mrr::numeric / NULLIF(i.initial_mrr, 0), 4) AS nrr
FROM remaining_mrr r
JOIN initial_mrr i
    ON r.cohort_month = i.cohort_month
ORDER BY r.cohort_month, r.months_since_signup;
"""
  subscriptions

customer_id      INTEGER
subscription_id  INTEGER
plan_name        VARCHAR
monthly_price    DECIMAL(10,2)
start_date       DATE
end_date         DATE
monthly_price is the monthly MRR contribution of the subscription.
end_date is NULL if the subscription is still active.
A customer may have multiple subscriptions at the same time.
Assume there are no overlapping records for the same subscription_id.

A subscription contributes to a month if it is active at any point during that month.
active_customers = distinct customers with at least one active subscription.
active_subscriptions = number of active subscriptions.
MRR = sum of monthly_price of all active subscriptions.
  
  Write a SQL query that returns the monthly MRR from January 2025 through June 2025.
  | month | active_customers | active_subscriptions | MRR |
| ----- | ---------------- | -------------------- | --- |
  """
with month as (
  select generate_series(
  '1/1/2025',
  '6/1/2025',
  interval '1 month'
  )::date as month
)
select month,
  count(distinct(customer_id)) as active_customers,
  count(distinct(subscription_id)) as active_subscriptions,
  coalesce(sum(monthly_price),0) as mrr
 from month
left join subscriptions t2
on date_trunc('month',start_date) <= month
and (date_trunc('month',end_date) >= month or end_date is null)
group by 1
order by 1

"""
  user_sessions
  user_id        INTEGER
session_start  TIMESTAMP
  For each month from January 2025 through June 2025, return :
  | month | DAU | WAU | stickiness |
| ----- | --: | --: | ---------: |
Definitions:
DAU = average Daily Active Users during the month.
Daily Active Users = distinct users who had at least one session that day.
WAU = average Weekly Active Users during the month.
Weekly Active Users = distinct users who had at least one session that week.
Stickiness = DAU / WAU.
  
Return one row per month.
  """
with month as (
  select generate_series(
  '1/1/2025',
  '6/1/2025',
  interval '1 month'
  )::date as month
),
daily as (
  select date_trunc('day',session_start) as daily,
  count(distinct(user_id)) as daily_active
  from user_sessions
  group by 1
  order by 1
),
weekly as (
  select date_trunc('week',session_start) as weekly,
  count(distinct(user_id)) as weekly_active
  from user_sessions
  group by 1
  order by 1
),
  daily_avg as (
select month,
  avg(daily_active) as DAU
from month
left join daily t1
on month.month = date_trunc('month',t1.daily)
  group by 1),
  weekly_avg as (
  select month,
  avg(weekly_active) as WAU
from month
left join weekly t2
on month.month = date_trunc('month',t2.weekly)
  group by 1
)
select month,
  DAU,
  WAU,
  DAU/nullif(WAU,0) as stickness
  from 
  daily_avg t1
  left join weekly_avg t2 on 
  t1.month = t2.month
order by 1
"""
user_activity
-------------
user_id       INTEGER
activity_date DATE

Each row means that a user was active on that date. A user can have multiple rows on the same date.
Write query that returns **monthly cohort retention** for users whose first active month is between January 2025 and March 2025.
Return:
cohort_month
month_number
cohort_size
retained_users
retention_rate

Definitions:
* `cohort_month` = the month of the user’s first-ever activity
* `month_number = 0` for the cohort month, `1` for the following month, and so on
* `cohort_size` = total number of users in that cohort
* `retained_users` = number of users from that cohort who were active in the corresponding month
* `retention_rate = retained_users / cohort_size`
* Count each user at most once per activity month

Example:
cohort_month | month_number | cohort_size | retained_users | retention_rate
2025-01-01   | 0            | 100         | 100            | 1.000
2025-01-01   | 1            | 100         | 62             | 0.620
2025-01-01   | 2            | 100         | 45             | 0.450

You may assume the activity data extends through June 2025.
  """
WITH monthly_activity AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('month', activity_date)::date AS active_month
    FROM user_activity
),
first_month AS (
    SELECT
        user_id,
        active_month,
        MIN(active_month) OVER (
            PARTITION BY user_id
        ) AS cohort_month
    FROM monthly_activity
),
month as (
  select generate_series(
  '1/1/2025',
  '6/1/2025',
  interval '1 month'
  )::date as month
),
cohort_month as (
  select cohort_month,
  count(distinct(user_id)) as cohort_size
  from first_month
  group by 1
),
cohort_month_grid AS (
    SELECT
        c.cohort_month,
        m.month,
        (
            EXTRACT(YEAR FROM m.month) * 12
            + EXTRACT(MONTH FROM m.month)
        )
        -
        (
            EXTRACT(YEAR FROM c.cohort_month) * 12
            + EXTRACT(MONTH FROM c.cohort_month)
        ) AS months_number,
  c.cohort_size
    FROM cohort_month c
    JOIN month m
        ON m.month >= c.cohort_month
  where c.cohort_month between '1/1/2025' and '3/1/2025'
)
   SELECT
        g.cohort_month,
        g.months_number,
      g.cohort_size,
  count(distinct( user_id)) as retained_users,
  count(distinct(user_id))::numberic 
  / nullif(g.cohort_size,0) as retention_rate
    FROM cohort_month_grid g
    LEFT JOIN first_month s
        ON s.cohort_month = g.cohort_month
     AND s.active_month = g.month
    GROUP BY 1,2
  order by 1,2

""" Daily Active Users and 7-Day Rolling Average
events
-------
user_id        INT
event_time     TIMESTAMP
event_type     VARCHAR
Each row represents one user event.

Write a SQL query that returns, for every calendar date:
event_date
daily_active_users
rolling_7d_avg_dau

Definitions:
* `daily_active_users` = number of distinct users with at least one event that day.
* `rolling_7d_avg_dau` = average DAU for the current date and previous six calendar dates.
* Dates with no events must still appear with `daily_active_users = 0`.
* Assume PostgreSQL.
* The output date range should run from the earliest event date through the latest event date.

Example data:
user_id | event_time
--------+---------------------
1       | 2026-07-01 10:00:00
1       | 2026-07-01 11:00:00
2       | 2026-07-01 12:00:00
1       | 2026-07-03 09:00:00
3       | 2026-07-03 15:00:00
2       | 2026-07-04 14:00:00
  """
WITH daily_active AS (
    SELECT
        event_time::date AS event_date,
        COUNT(DISTINCT user_id) AS daily_active_users
    FROM events
    GROUP BY event_time::date
),

date_bounds AS (
    SELECT
        MIN(event_time::date) AS min_date,
        MAX(event_time::date) AS max_date
    FROM events
),

calendar_dates AS (
    SELECT
        GENERATE_SERIES(
            min_date,
            max_date,
            INTERVAL '1 day'
        )::date AS event_date
    FROM date_bounds
),

daily_with_zeros AS (
    SELECT
        c.event_date,
        COALESCE(d.daily_active_users, 0) AS daily_active_users
    FROM calendar_dates c
    LEFT JOIN daily_active d
        ON c.event_date = d.event_date
)

SELECT
    event_date,
    daily_active_users,
    AVG(daily_active_users) OVER (
        ORDER BY event_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg_dau
FROM daily_with_zeros
ORDER BY event_date
"""
users
-----
user_id
signup_date

events
------
user_id
event_time
  
Return, for each `signup_date`:
signup_date
cohort_size
day_7_retained_users
day_7_retention_rate
A user is retained if they have at least one event on Day 1 through Day 7 after signup.
  """
with signup as (
  select date_trunc('day',signup_date) as signup_date,
  count(distinct(user_id)) as cohort_size
  from users
  group by 1
  order by 1
 ),
retained as (
  select user_id,
  date_trunc('day',signup_date) as signup_date,
  date_trunc('day',event_time) as event_date,
  case when date_trunc('day',event_time)::date - date_trunc('day',signup_date)::date<=7 and  date_trunc('day',event_time)::date > date_trunc('day',signup_date)::date then 1 else 0 end as gaps
  from users u
  left join events e
  on u.user_id = e.user_id
),
seven_retain as (
  select user_id,
  signup_date,
  sum(gaps) as flag
  from retained
  group by 1,2
),
retained_user as (
  select signup_date,
  count(distinct(case when flag >0 then user_id end)) as day_7_retained_users
  from seven_retain
  group by 1
)
select s.signup_date, cohort_size,
   COALESCE(r.retained_users, 0) AS retained_users,
    COALESCE(r.retained_users, 0)::numeric
        / NULLIF(s.cohort_size, 0) AS retention_rate
from signup s
left join retained_user r
on s.signup_date = r.signup_date
order by 1;

WITH signup AS (
    SELECT
        signup_date::date AS signup_date,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM users
    GROUP BY signup_date::date
),
retained_user AS (
    SELECT
        u.signup_date::date AS signup_date,
        COUNT(DISTINCT e.user_id) AS retained_users
    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id
       AND e.event_time::date BETWEEN u.signup_date::date
                                  AND u.signup_date::date + 7
    GROUP BY u.signup_date::date
)
SELECT
    s.signup_date,
    s.cohort_size,
    r.retained_users,
    r.retained_users::numeric
        / NULLIF(s.cohort_size, 0) AS retention_rate
FROM signup s
JOIN retained_user r
    ON s.signup_date = r.signup_date
ORDER BY s.signup_date;

