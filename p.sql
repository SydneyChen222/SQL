"""
## Mock 1: Payment Authorization Drop
### Tables
**transactions**
| transaction_id | merchant_id | customer_id | created_at | amount | currency | payment_method |
| -------------- | ----------- | ----------- | ---------- | -----: | -------- | -------------- |
| 1              | M1          | C1          | 2026-01-05 |    100 | USD      | card           |
| 2              | M1          | C2          | 2026-01-08 |     80 | USD      | wallet         |
| 3              | M1          | C3          | 2026-02-10 |    120 | USD      | wallet         |
| 4              | M1          | C4          | 2026-02-12 |    200 | USD      | card           |
| 5              | M2          | C5          | 2026-01-15 |     90 | EUR      | card           |
| 6              | M2          | C6          | 2026-02-20 |    150 | EUR      | wallet         |

**payment_events**
| transaction_id | event_time       | event_type | reason_code        |
| -------------- | ---------------- | ---------- | ------------------ |
| 1              | 2026-01-05 10:00 | authorized | null               |
| 2              | 2026-01-08 11:00 | failed     | insufficient_funds |
| 2              | 2026-01-08 11:05 | authorized | null               |
| 3              | 2026-02-10 09:00 | failed     | timeout            |
| 4              | 2026-02-12 13:00 | authorized | null               |
| 5              | 2026-01-15 14:00 | authorized | null               |
| 6              | 2026-02-20 15:00 | failed     | fraud_blocked      |

**fx_rates**
| rate_date  | currency | rate_to_eur |
| ---------- | -------- | ----------: |
| 2026-01-05 | USD      |        0.92 |
| 2026-01-08 | USD      |        0.91 |
| 2026-02-10 | USD      |        0.93 |
| 2026-02-12 | USD      |        0.94 |
| 2026-01-15 | EUR      |        1.00 |
| 2026-02-20 | EUR      |        1.00 |

## SQL Part A
Write a SQL query to calculate, by **merchant_id** and **month**:
* attempted transactions
* authorized transactions
* authorization rate
* processed volume in EUR for authorized transactions only
Important: `payment_events` can have multiple rows per transaction. Use the **latest event** as the final outcome.
"""
with final_event as (
  select transaction_id, event_time,
  max(event_time) over(partition by transaction_id) as final_time, 
  event_type, reason_code
  from payment_events
  order by 1,2
),
 final_authorized as  (
  select distinct(transaction_id) as transaction_id
  from final_event
  where event_time = final_time
  and event_type = 'authorized'
  ),
  
attempted as (
  select merchant_id, 
  date_trunc('month',created_at) as month,
  count(distinct(transaction_id)) as attempted_transactions
  from transactions
  group by 1,2
  order by 1,2
),
authorized as (
  select merchant_id,
  date_trunc('month',created_at) as month,
  count(distinct(t1.transaction_id)) as authorized_transactions,
  sum(case when t2.currency = 'EUR' then amount
  else t2.amount*t3.rate_to_eur end) as processed_volume
  from final_authorized t1
  left join transactions t2
  on t1.transaction_id = t2.transaction_id
  left join fx_rates t3 
  on t3.rate_date::date = t2.created_at::date
  and t3.currency = t2.currency
  group by 1,2
  order by 1,2
)
select t1.merchant_id,
  t1.month,
  t1.attempted_transactions,
  t2.authorized_transactions,
  coalesce(t2.authorized_transactions::numeric,0) / nullif(t1.attempted_transactions,0) as authorized_rates,
  coalesce(t2.processed_volume,0) as processed_volume
from attempted t1
left join authorized t2
on t1.merchant_id = t2.merchant_id
and t1.month = t2.month
order by 1,2
"""
Using your result as `merchant_monthly`, write a query to return merchants whose
  **authorization rate dropped by more than 5 percentage points compared with the previous month**.
Expected output columns:
merchant_id
month
authorization_rate
previous_month_authorization_rate
authorization_rate_change_pp
Key point:
90% → 84% = -6 percentage points
That should qualify.
  """
with previous as (
  select merchant_id,
  month,
  authorized_rate,
  LAG(authorized_rate) OVER(Partition by merchant_id order by month) as previous_month_authorization_rate,
  authorized_rate - 
  LAG(authorized_rate) OVER(Partition by merchant_id order by month) as authorization_rate_change_pp
  from merchant_monthly
  order by 1,2
)
select merchant_id,
month,
authorized_rate as authorization_rate,
previous_month_authorization_rate,
authorization_rate_change_pp::numeric
from previous
where authorization_rate_change_pp < -0.05
order by 1,2
"""
 discrepancy investigation.**
Business asks:
> “Our dashboard says February processed volume is much higher than the finance report. 
  Please identify whether the issue may come from joining transactions to payment events directly.”
  
Write a query comparing two calculations by merchant/month:
1. **Correct volume**
   Use only one final event per transaction, and sum authorized transaction amount once.

2. **Naive volume**
   Join `transactions` directly to `payment_events`, filter `event_type = 'authorized'`, and sum amount.

Output:
merchant_id
month
correct_authorized_volume
naive_authorized_volume
volume_difference
Goal: detect whether duplicate/multiple event rows could inflate volume.
  """
with final_event as (
  select transaction_id, event_time,
  max(event_time) over(partition by transaction_id) as final_time, 
  event_type, reason_code
  from payment_events
  order by 1,2
),
   final_authorized as  (
  select distinct(transaction_id) as transaction_id
  from final_event
  where event_time = final_time
  and event_type = 'authorized'
  ),
t1 as (
  select t1.merchant_id, date_trunc('month',t1.created_at) as month,
  sum(amount) as correct_authorized_amount
  from transactions t1
  right join final_authorized t2
  on t1.transaction_id = t2.transaction_id
  group by 1,2
  order by 1,2
),
native as (
  select t1.merchant_id, date_trunc('month',t1.created_at) as month,
  sum(t1.amount) as naive_authorized_volume
  from transactions t1
  join payment_events t2
  on t1.transaction_id = t2.transaction_id
  where t2.event_type = 'authorized'
  group by 1,2
  order by 1,2
)
select t1.merchant_id,t1.month,
  t1.correct_authorized_amount,
  t2.native_authorized_amount,
   coalesce(t2.naive_authorized_amount,0)
  - coalesce(t1.correct_authorized_amount,0)
  as volume_difference
from t1
left join native t2 
on t1.merchant_id = t2.merchant_id
and t1.month = t2.month
order by 1,2

"""
## PROJECT 1 — SQL: Settlement & Merchant Health (~90 min)
**Schema + data** (this is your full universe — hand-verify against it):
```
merchants
---------
merchant_id | merchant_name | country | tier    | onboarded_at
10          | Acme          | US      | gold    | 2023-11-01
20          | Globex        | GB      | silver  | 2024-01-15
30          | Initech       | DE      | gold    | 2023-06-20
40          | Umbrella      | US      | bronze  | 2024-02-01
50          | Hooli         | GB      | silver  | 2024-02-10
```
transactions
------------
txn_id | merchant_id | created_at          | amount   | currency | status       | method
1      | 10          | 2024-03-01 09:15    | 1200.00  | USD      | authorized   | card
2      | 10          | 2024-03-01 22:40    | 800.00   | USD      | authorized   | wallet
3      | 10          | 2024-03-03 11:00    | 500.00   | USD      | declined     | card
4      | 10          | 2024-03-04 08:30    | 300.00   | USD      | refunded     | card
5      | 20          | 2024-03-01 14:00    | 2000.00  | GBP      | authorized   | card
6      | 20          | 2024-03-02 10:20    | 1500.00  | GBP      | chargeback   | card
7      | 20          | 2024-03-02 16:45    | 900.00   | GBP      | authorized   | wallet
8      | 20          | 2024-03-05 12:00    | 1100.00  | GBP      | authorized   | card
9      | 30          | 2024-03-01 07:00    | 400.00   | EUR      | authorized   | card
10     | 30          | 2024-03-02 09:30    | 650.00   | EUR      | authorized   | wallet
11     | 30          | 2024-03-04 13:15    | 720.00   | EUR      | declined     | card
12     | 30          | 2024-03-06 18:00    | 380.00   | EUR      | authorized   | card
13     | 40          | 2024-03-02 11:11    | 250.00   | USD      | authorized   | card
14     | 40          | 2024-03-03 15:00    | 90.00    | USD      | refunded     | wallet
15     | 50          | 2024-03-01 20:00    | 3000.00  | GBP      | authorized   | card
16     | 50          | 2024-03-01 20:30    | 2200.00  | GBP      | authorized   | card
17     | 50          | 2024-03-03 09:00    | 1800.00  | GBP      | chargeback   | wallet
18     | 50          | 2024-03-04 10:00    | 2500.00  | GBP      | authorized   | card
```
(Statuses in play: `authorized`, `declined`, `refunded`, `chargeback`.)

**Q1 (warm-up).** Total authorized `amount` and authorized transaction *count*, per merchant. 
  Include merchant name. Order by authorized amount desc.
"""
select t1.merchant_id,t2.merchant_name,
  count(case when t1.status = 'authorized' then txn_id end) as authorized_transaction,
   coalesce(sum(case when t1.status = 'authorized' then amount end),0) as authorized_amount
  from transactions t1
  left join merchants t2
  on t1.merchant_id = t2.merchant_id
  group by 1,2
  order by 4 desc
  
  """
**Q2 (conditional aggregation).** For each merchant, return: 
  total transaction count, authorization rate, 
  chargeback rate, and refund rate — each as a percentage (2 dp).
  Auth rate = authorized ÷ all. 
  Chargeback rate and refund rate — 
  *you decide the denominator and state it.* Only include merchants with ≥ 3 total transactions.
"""
  select merchant_id,
  count(txn_id) as total_transaction_count,
  round(100* count(case when status = 'authorized' then txn_id end)/nullif(count(txn_id),0),2) as authorization_rate,
  round(100*count(case when status = 'chargeback' then txn_id end) /nullif(count( case when status = 'authorized' then txn_id end),0),2) as chargeback_rate,
  round(100*count(case when status = 'refunded' then txn_id end)/nullif(count(case when status = 'authorized' then txn_id end),0),2) as refund_rate
  from transactions
  group by 1
  having count(txn_id)>= 3
  --- I'm defining chargeback and refund rate over authorized transactions, since those events can only occur on authorized payments — note that differs from the auth-rate denominator, which is all transactions. If you'd prefer all three on a common base, I'd switch to total."
  
  """
**Q3 (window function).** Rank merchants by total authorized volume **within their country**, highest = rank 1.
  Return only each country's **top-ranked** merchant. Handle the tie-break rule explicitly and say which you chose.
"""
  with t1 as (
  select transactions.merchant_id,country,
  count(case when status = 'authorized' then amount end) as authorized_volume
  from transactions 
  left join merchants
  on transactions.merchant_id = merchants.merchant_id
  group by 1,2
  order by 1,2
  ),
  rak as (
  select merchant_id, country,
  authorized_volume,
  row_number() over(PARTITION BY country order by authorized_volume desc) as rnk
  from t1
  )
  select merchant_id,country,authorized_volume,
  rnk
  from rak
  where rnk =1
  order by country
  
  """
  
**Q4 (calendar spine).** For merchant 50 (Hooli), produce a row for **every day** from 2024-03-01 to 2024-03-06 with that day's total authorized amount. 
  Days with none must show 0. Order by day.
  """
with daily as (
  select generate_series(
  '2024-03-01'::date,
  '2024-03-06'::date,
  interval '1 day')::date
  as days
  )

select days,
  coalesce(sum(amount),0) as authorized_amount
  from daily t1
  left join transactions t2
  on t1.days = t2.created_at::date
  and t2.merchant_id = 50
  and t2.status = 'authorized'
  group by 1
  order by 1
  """

**Q5 (window + spine, builds on Q4).** Extend Q4: add a column for **day-over-day change** in authorized amount (today − yesterday). 
  First day is null. (This is the spine + `LAG` combo — the spine is what makes the day-over-day correct, since it guarantees no missing days.)
"""
with daily as (
  select generate_series(
  '2024-03-01'::date,
  '2024-03-06'::date,
  interval '1 day')::date
  as days
  ),
  t1 as (
select days,
  coalesce(sum(amount),0) as authorized_amount
  from daily t1
  left join transactions t2
  on t1.days = t2.created_at::date
  and t2.merchant_id = 50
  and t2.status = 'authorized'
  group by 1)
  select days,
  authorized_amount,
  authorized_amount - LAG(authorized_amount) OVER(ORDER BY days) as dod_change
  from t1
  order by 1

  """
users
user_id    signup_date   country

events
user_id    event_name     event_time
`event_name` can include: file_created file_shared comment_added

Write a SQL query that returns, for each signup month:
* number of users who signed up
* number of those users who created at least one file within 7 days of signup
* activation rate
signed_up_users = all users who signed up in that signup month.
activated_users = users who performed at least one file_created event within 7 days (inclusive) of their signup date.
Each user should count at most once, regardless of how many files they created.
  
Example output:
signup_month | signed_up_users | activated_users | activation_rate
2026-01-01   | 1000            | 420             | 0.420
"""
  with signup as (
select date_trunc('month',signup_date) as signup_month,
  count(distinct(user_id)) as signed_up_users
  from users
  group by 1
  order by 1
),
active as (
  select date_trunc('month',signup_date) as signup_month,
  count(distinct(case when events.event_name = 'file_created' then events.user_id end)) as activated_users
  from users 
  left join events 
  on users.user_id = events.user_id
  and users.signup_date <= events.event_time
  and users.signup_date + interval '7 days' >= events.event_time
  group by 1
  order by 1
)
select signup.signup_month,
  signup.signed_up_users,
  active.activated_users,
  active.activated_users::numeric/nullif(signup.signed_up_users,0) as activation_rate
from signup
left join active
on signup.signup_month = active.signup_month
order by 1
"""
  A user is activated only if they both create a file and share a file within seven days of signup.
  The two actions can happen in any order, and each user should still count once."""
  
  with signup as (
select date_trunc('month',signup_date) as signup_month,
  count(distinct(user_id)) as signed_up_users
  from users
  group by 1
  order by 1
),
active as (
  select date_trunc('month',signup_date) as signup_month,
   count(distinct(case when (exists (
  select 1 from events
  where events.user_id = users.user_id
  and events.event_name = 'file_created'
    and users.signup_date <= events.event_time
  and users.signup_date + interval '7 days' >= events.event_time)
  and 
  exists(select 1
  from events
  where events.user_id = users.user_id
  and event.event_name = 'file_shared'
    and users.signup_date <= events.event_time
  and users.signup_date + interval '7 days' >= events.event_time)
  then events.user_id end))) as activated_users
  from users 
  group by 1
  order by 1
)
select signup.signup_month,
  signup.signed_up_users,
  active.activated_users,
  active.activated_users::numeric/nullif(signup.signed_up_users,0) as activation_rate
from signup
left join active
on signup.signup_month = active.signup_month
order by 1
