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



