# 🏨 Hotel Bookings — End-to-End Data Engineering Project on Microsoft Fabric

A complete end-to-end data engineering project built on **Microsoft Fabric**, implementing Medallion Architecture (Bronze → Silver → Gold) in a single schema-enabled lakehouse, with automated orchestration, a night-level star schema and Power BI reporting with hotel-industry KPIs (Occupancy, ADR, RevPAR).

`Microsoft Fabric` · `Data Pipelines` · `Dataflow Gen2` · `Lakehouse Schemas` · `Data Modeling` · `Star Schema` · `Direct Lake` · `Power BI` · `DAX`

---

## 🎯 Business Goal

Hotel management needs daily visibility into revenue, occupancy, cancellations, and guest satisfaction across multiple properties — without manually pulling and reconciling data from separate booking, guest, and review systems. This pipeline automates that end-to-end: raw booking data lands, gets cleaned and modeled, and is ready in Power BI with no manual intervention.

## 🏗️ Architecture

```
ADLS Gen2 (CSV Source + JSON Config)
   → HB Bronze Data Ingestion (Lookup → ForEach → Copy Data, upsert)  → HB_Data_Product.bronze
   → HB Silver Cleaning (Dataflow Gen2)                                 → HB_Data_Product.silver
   → HB Gold Star Schema (Dataflow Gen2)                                → HB_Data_Product.gold
   → HB Semantic Model (Direct Lake) → HB report (Power BI)

Orchestrated end to end by the parent pipeline: HB Pipeline
```

All three layers live in one lakehouse, **`HB_Data_Product`**, separated by schemas:

| Schema | What happens |
|---|---|
| **`bronze`** | 5 CSVs (`bookings`, `guests`, `hotels`, `rooms`, `reviews`) ingested from **ADLS Gen2** via a metadata-driven pipeline, upsert strategy, 1:1 with source |
| **`silver`** | One cleaned table per entity: `silver_bookings`, `silver_guests`, `silver_hotels`, `silver_rooms`, `silver_reviews` — corrected data types, standardized booking status (`checked_out` → `Checked Out`), reviews kept at review grain (with comments) |
| **`gold`** | Star schema: `fact_stay_nights`, `dim_rooms`, `dim_guests`, `dim_date` |

### Gold data model

| Table | Grain | Built from | Notes |
|---|---|---|---|
| `fact_stay_nights` | **1 row = 1 night of 1 booking** | bookings + rooms + aggregated reviews | `stay_date`, `room_revenue` (nightly rate), `is_first_night`, `booking_status`, `nights_stayed`, `review_rating` |
| `dim_rooms` | 1 row = 1 room | `silver_rooms` ⟕ `silver_hotels` | Room attributes + hotel attributes (name, city, country, rating) |
| `dim_guests` | 1 row = 1 guest | `silver_guests` | Email and phone hidden in the semantic model (PII) |
| `dim_date` | 1 row = 1 day | generated in M | Dynamic range from first check-in to last check-out; weekday sort column |

A booking from 29 Jun to 3 Jul becomes 4 rows (nights of 29 Jun, 30 Jun, 1 Jul, 2 Jul) — revenue is attributed to the night it was earned, so a stay spanning two months is split correctly between them.

## 🧠 Design Decisions

- **One lakehouse with `bronze` / `silver` / `gold` schemas instead of three lakehouses.** A single schema-enabled lakehouse keeps the workspace small, gives one SQL analytics endpoint for cross-layer queries, and means every dataflow and the semantic model reference a single lakehouse ID.
- **Upsert in Bronze instead of append-only.** The classic medallion pattern keeps Bronze append-only and merges in Silver. Here the source CSVs in ADLS Gen2 are persistent and grow daily, so the source itself is the historical archive — any past state can be rebuilt by re-reading the files. 
- **Ingestion split into its own pipeline.** `HB Bronze Data Ingestion` is a child pipeline invoked by the parent `HB Pipeline`, so ingestion can be re-run or tested on its own without refreshing the dataflows.
- **Night-level fact table.** Revenue, occupancy, ADR and RevPAR are defined per room night in the hotel industry. A booking-level fact can only attribute revenue to check-in or check-out date; the night grain gives correct monthly revenue and makes occupancy possible at all.
- **Booking-level measures on a night-level fact.** Bookings are counted once via `is_first_night` (attributed to arrival date), and averages such as length of stay and review rating are computed per `booking_id` with `AVERAGEX`, so long stays are not over-weighted.
- **Hotel attributes folded into `dim_rooms`.** Room → hotel is a strict many-to-one hierarchy and every room belongs to a hotel, so a single room dimension keeps the model a clean star without a snowflake or ambiguous filter paths.
- **Review aggregation in Gold.** Silver keeps individual reviews; the per-booking average is computed in the Gold dataflow as a staging step.
- **Cancellations excluded from revenue, not from the data.** Revenue measures filter out `Cancelled`, while `cancellation_rate` uses `REMOVEFILTERS` on status, so it stays correct even with a report-level filter on non-cancelled bookings.
- **Raw fact columns hidden.** `nights_stayed`, `room_revenue`, `review_rating` and keys are hidden with summarization disabled — at night grain a plain `SUM` would multiply values by the number of nights, so users only see measures.

## ⚙️ Orchestration

**`HB Pipeline`** — the parent pipeline, run end to end with on-success dependencies between every step:

<img width="783" height="122" alt="HB Pipeline" src="https://github.com/user-attachments/assets/17303498-d97d-466c-b3a7-f9b165b713fc" />

1. **Bronze Data Ingestion** (Invoke pipeline) — runs the child pipeline `HB Bronze Data Ingestion`
2. **Silver Cleaning** (Dataflow) — refreshes `HB Silver Cleaning` once ingestion succeeds
3. **Gold Star Schema** (Dataflow) — refreshes `HB Gold Star Schema` once Silver succeeds

**`HB Bronze Data Ingestion`** — a single **metadata-driven** child pipeline instead of one hardcoded Copy Data activity per file:

1. **Lookup (`lookup_json_config`)** — reads a JSON config file from **ADLS Gen2**, listing each source file (→ target table name) and its key column
2. **ForEach (`for_each_csv`)** — iterates over that config and dynamically invokes a **Copy Data** activity per entry — adding a new source file means editing the config, not the pipeline
3. **Copy Data (upsert)** — writes each table into the `bronze` schema, merging records on the key column defined in the config (insert new, update existing)

<details>
<summary><b>📸 Click to view the Bronze Data Ingestion pipeline</b></summary>

<br>

<img width="533" height="297" alt="image" src="https://github.com/user-attachments/assets/330da0cc-6a79-4e34-84ac-7b5d6e90443a" />

</details>

The chain can be scheduled daily, and the Direct Lake semantic model picks up the new Gold data automatically — no manual intervention required end to end.

## 🔄 Dataflows

**`HB Silver Cleaning`** — reads the five tables from the `bronze` schema and writes one cleaned table per entity to the `silver` schema: type casting, booking status standardization, reviews kept at review grain.

**`HB Gold Star Schema`** — reads the `silver` schema and builds the star schema in `gold`: `dim_rooms` (rooms ⟕ hotels), `dim_guests`, a dynamic `dim_date`, and `fact_stay_nights` — a staging booking-level query (bookings + room rate + aggregated review rating) expanded into one row per stay night.

<details>
<summary><b>📸 Click to view dataflow screenshots</b></summary>

<br>

**HB Silver Cleaning**

<img width="522" height="384" alt="HB Silver Cleaning dataflow" src="https://github.com/user-attachments/assets/27643f24-31a0-453e-a0f4-95ffc505eb5d" />

**HB Gold Star Schema**

<img width="1074" height="384" alt="HB Gold Star Schema dataflow" src="https://github.com/user-attachments/assets/10ad9378-aa39-498f-ac87-9d80f66a83b0" />

</details>

## 📊 Power BI Report

### Semantic Model

<img width="800" height="470" alt="HB Semantic Model" src="https://github.com/user-attachments/assets/c4372734-0103-4741-963d-ab9b055bd169" />

`HB Semantic Model` is a Direct Lake model on the `gold` schema of `HB_Data_Product` — no import refresh needed, reads directly from OneLake.

Relationships (all many-to-one, single direction):
- `fact_stay_nights[stay_date]` → `dim_date[Date]`
- `fact_stay_nights[room_id]` → `dim_rooms[room_id]`
- `fact_stay_nights[guest_id]` → `dim_guests[guest_id]`

### Report Pages

- **Page 1 — Summary:** KPI cards (Revenue, Room Nights Sold, Bookings, Occupancy, ADR, RevPAR, Avg Length of Stay, Avg Review Rating, Cancellation Rate), KPI trend over time (year → quarter → month → weekday drill-down), KPI by hotel country / hotel / room type, field-parameter KPI slicer
- **Page 2 — Guests & Hotel Performance:** revenue by guest country and guest, hotel rating vs revenue scatter plot, average rating by hotel
- Cancelled bookings are excluded via a report-level filter; cancellation rate still reflects all bookings.

<details>
<summary><b>📸 Click to view report screenshots</b></summary>

<br>

**Page 1 — Summary**

<img width="1232" height="686" alt="Summary page" src="https://github.com/user-attachments/assets/ce992d37-aaf4-4432-93bb-04c545e58c34" />

**Page 2 — Guests & Hotel Performance**

<img width="1240" height="697" alt="Guests and hotel performance page" src="https://github.com/user-attachments/assets/64f03bbc-1d5b-413e-b444-b563adac1f4e" />

</details>

### 📐 Hotel KPIs

| KPI | Formula | What it tells you |
|---|---|---|
| **Room Nights Sold** | count of non-cancelled stay nights | Volume actually sold |
| **Occupancy** | room nights sold ÷ (rooms × days) | Share of capacity used |
| **ADR** (Average Daily Rate) | room revenue ÷ room nights sold | Average price paid per occupied room night |
| **RevPAR** (Revenue per Available Room) | room revenue ÷ (rooms × days) = ADR × Occupancy | Revenue per room including empty ones — combines price and occupancy |
| **ALOS** (Avg Length of Stay) | average nights per booking | Longer stays mean lower turnover cost per night |
| **Cancellation Rate** | cancelled bookings ÷ all bookings (by arrival date) | Demand risk |

<details>
<summary><b>📐 DAX measures (click to expand)</b></summary>

<br>

```dax
total_revenue =
CALCULATE ( SUM ( fact_stay_nights[room_revenue] ),
    fact_stay_nights[booking_status] <> "Cancelled" )

room_nights_sold =
CALCULATE ( COUNTROWS ( fact_stay_nights ),
    fact_stay_nights[booking_status] <> "Cancelled" )

-- each booking counted once, on its arrival night
total_bookings =
CALCULATE ( COUNTROWS ( fact_stay_nights ), fact_stay_nights[is_first_night] = TRUE () )

avg_nights =
AVERAGEX ( VALUES ( fact_stay_nights[booking_id] ),
    CALCULATE ( MAX ( fact_stay_nights[nights_stayed] ) ) )

avg_review_rating =
AVERAGEX ( VALUES ( fact_stay_nights[booking_id] ),
    CALCULATE ( MAX ( fact_stay_nights[review_rating] ) ) )

cancellation_rate =
VAR _cancelled =
    CALCULATE ( [total_bookings], fact_stay_nights[booking_status] = "Cancelled" )
VAR _all =
    CALCULATE ( [total_bookings], REMOVEFILTERS ( fact_stay_nights[booking_status] ) )
RETURN DIVIDE ( _cancelled, _all, 0 )

ADR = DIVIDE ( [total_revenue], [room_nights_sold] )

occupancy =
DIVIDE ( [room_nights_sold], COUNTROWS ( dim_rooms ) * COUNTROWS ( dim_date ) )

RevPAR =
DIVIDE ( [total_revenue], COUNTROWS ( dim_rooms ) * COUNTROWS ( dim_date ) )
```

</details>

## 📈 Scaling Considerations

The architecture (metadata-driven ingestion, medallion layers, star schema on Direct Lake) scales well — a new source is a config entry, and a night-level fact of tens of millions of rows is well within Direct Lake limits. The current *implementation* is sized for a small dataset.

<details>
<summary><b>What I would change at production volume (click to expand)</b></summary>

<br>

1. **Incremental processing instead of daily full reloads.** Every run re-reads the full growing CSVs, merges them into Bronze, and fully replaces Silver and Gold, so runtime and capacity usage grow with total history. Next step: daily partitioned source files or a last-modified watermark in Copy Data, and incremental refresh / merge of changed records only in Silver and Gold.
2. **Spark notebooks for heavy transformations.** Dataflow Gen2 joins run in the mashup engine without query folding. For large volumes the Silver/Gold logic would move to PySpark notebooks (Delta `MERGE`, partitioning) or Warehouse T-SQL.
3. **Native aggregations instead of DAX iterators.** `avg_nights` and `avg_review_rating` iterate over every `booking_id` with context transition. At millions of bookings, storing these values only on the `is_first_night` row (null elsewhere) would allow a plain `AVERAGE`, computed natively by the storage engine.
4. **Environment parameterization.** Workspace and lakehouse IDs are hard-coded in the dataflows and the semantic model; dev/test/prod promotion would use Fabric deployment pipelines with variable libraries.
5. **Data quality checks and alerting.** Row-count, null-key and orphaned-key checks after each layer, plus a failure notification activity in the pipeline.
6. **Layer isolation.** With more teams consuming the data, Gold could move to its own lakehouse or workspace (shortcuts to the curated tables) for simpler, item-level access control.

</details>

## ⚠️ Assumptions & Limitations

The data is **synthetic** — 120 bookings across 100 rooms over ~1 year — so absolute values (e.g. ~1% occupancy) are not realistic; the focus is on correct modeling and KPI definitions.

<details>
<summary><b>Further assumptions (click to expand)</b></summary>

<br>

- **Flat nightly rate.** Revenue per night equals the room's `price_per_night`; real hotels use variable rates per night (season, weekend).
- **Full availability assumed.** Capacity counts every room as available every day — `is_available` is a current-state flag with no history, so out-of-order rooms can't be excluded.
- **Room revenue only.** No F&B, spa or other revenue streams (TRevPAR not covered).
- **Calendar range.** `dim_date` spans exactly the data range, which keeps occupancy correct but means DAX time-intelligence functions (YTD, YoY) would need a full-year calendar.
- **Data quality observation.** Some reviews in the source data belong to cancelled or not-yet-completed bookings; with cancellations filtered out in the report these are excluded automatically.

</details>

---

*Built with Microsoft Fabric — Bronze to Power BI end-to-end.*
