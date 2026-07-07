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
  max(event_time) over(partition by transaction_id order by event_time desc) as final_time, 
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
  and t3.curency = t2.currency
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




