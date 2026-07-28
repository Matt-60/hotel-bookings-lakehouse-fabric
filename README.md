# 🏨 Hotel Bookings — End-to-End Data Engineering Project on Microsoft Fabric

A complete end-to-end data engineering project built on **Microsoft Fabric**, implementing Medallion Architecture (Bronze → Silver → Gold) with automated orchestration and Power BI reporting.

`Microsoft Fabric` · `Data Pipelines` · `Dataflow Gen2` · `Data Modeling` · `Star Schema` · `Power BI`

---

## 🎯 Business Goal

Hotel management needs daily visibility into revenue, occupancy, cancellations, and guest satisfaction across multiple properties — without manually pulling and reconciling data from separate booking, guest, and review systems. This pipeline automates that end-to-end: raw booking data lands, gets cleaned and modeled overnight, and is ready in Power BI every morning with no manual intervention.

## 🏗️ Architecture

```
ADLS Gen2 (CSV Source + JSON Config) → Lookup (JSON config) → ForEach (per CSV) → Copy Data (upsert) → Bronze Lakehouse
   → Dataflow Gen2 → Silver Lakehouse (OBT)
   → Dataflow Gen2 → Gold Lakehouse (Star Schema)
   → Semantic Model (Direct Lake) → Power BI Report
```

| Layer | What happens |
|---|---|
| **Bronze** | 5 CSVs (`bookings`, `guests`, `hotels`, `rooms`, `reviews`) ingested from **ADLS Gen2** via a metadata-driven pipeline, upsert strategy, 1:1 with source |
| **Silver** | All 5 tables joined into one denormalized `Silver_OBT` (grain: 1 row = 1 booking); renamed columns, corrected types, calculated `nights_stayed` & `total_price` |
| **Gold** | Star schema: `fact_bookings`, `dim_guests`, `dim_hotels` (hotel+room combined), `dim_flags` (junk: status + is_reviewed), `dim_date` |

**Lineage:** each record carries `silver_processed_date` and `gold_processed_at` timestamps for traceability.

## ⚙️ Orchestration

<img width="1035" height="260" alt="image" src="https://github.com/user-attachments/assets/12ab793e-4865-4743-ad1a-ab83aac396a2" />

A single **metadata-driven Data Pipeline** handles ingestion instead of one hardcoded Copy Data activity per file:

1. **Lookup (`lookup_json_config`)** — reads a JSON config file from **ADLS Gen2**, listing each source file (→ target table name) and its key column
2. **ForEach (`for_each_csv`)** — iterates over that config and dynamically invokes a **Copy Data** activity per entry — adding a new source file means editing the config, not the pipeline
3. **Copy Data (upsert)** — writes each table into the **Bronze Lakehouse**, merging records on the key column defined in the config (insert new, update existing)
4. **Dataflow `bronze_to_silver`** — runs once all Bronze copies succeed, builds the Silver OBT
5. **Dataflow `silver_to_gold`** — runs after Silver completes, builds the Gold star schema

The whole chain runs **daily at 13:10 UTC+1** with on-success dependencies between every step, and the Direct Lake Semantic Model refreshes automatically once Gold is updated — no manual intervention required end to end.

## 📊 Power BI Report

### Semantic Model

<img width="800" height="400" alt="semantic model" src="https://github.com/user-attachments/assets/5a17b51b-619b-4839-9621-65493fab1f5b" />

Direct Lake semantic model built on top of the Gold star schema — no import/refresh needed, reads directly from OneLake.

### Report Preview

<details>
<summary><b>📸 Click to view report screenshots</b></summary>

**Page 1 — Bookings Analysis**

<img width="1224" height="681" alt="image" src="https://github.com/user-attachments/assets/dbbc4e41-7936-4cf2-b251-6d20d79fcf7b" />

**Page 2 — Guests & Hotel Performance**

<img width="1234" height="680" alt="image" src="https://github.com/user-attachments/assets/b3fb86ce-5030-4bb4-8aed-436becf7cf50" />

</details>

- **Page 1 — Bookings Analysis:** KPI cards (Revenue, Bookings, Avg Nights, Cancellation Rate), review rating gauge, revenue by hotel, revenue trend, field-parameter KPI slicer
- **Page 2 — Guests & Hotel Performance:** bookings by guest, avg rating by hotel, rating-vs-bookings correlation scatter plot

<details>
<summary><b>📐 DAX measures (click to expand)</b></summary>

```dax
Total Revenue = SUM(FactBookings[total_price])
Avg Revenue = AVERAGE(FactBookings[total_price])
Total Bookings = COUNTROWS(FactBookings)
Avg Nights = AVERAGE(FactBookings[nights_stayed])
Avg Review Rating = AVERAGE(FactBookings[review_rating])
Cancellation Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_bookings), KEEPFILTERS(dim_flags[booking_status] = "cancelled")),
    COUNTROWS(fact_bookings), 0
)

</details>

---

*Built with Microsoft Fabric — Bronze to Power BI end-to-end.*
