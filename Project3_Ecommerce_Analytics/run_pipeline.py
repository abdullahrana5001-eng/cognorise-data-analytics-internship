#!/usr/bin/env python3
"""
run_pipeline.py - Run the whole Project 3 SQL pipeline with NO installed software.

Works anywhere Python 3 runs (Google Colab, GitHub Codespaces, any laptop).
Uses only the standard library (sqlite3, csv). Reading .xlsx needs `openpyxl`
(already present in Colab; in Codespaces run: pip install openpyxl).

What it does
  1. Loads your raw file (.csv or .xlsx, 16 columns) into SQLite table raw_ecommerce
     (headers are auto-converted: "Customer Age Group" -> customer_age_group)
  2. Runs sql/01 -> 02 -> 03 -> 04 -> 06 in order, printing every result table
  3. Saves proof of the run:  docs/sql_run_log.txt  and  docs/validation_results.csv
  4. Exports data/ds_analytical.csv and data/ds_price_discount.csv for Power BI

Usage (from inside the Project3_Ecommerce_Analytics folder)
  python run_pipeline.py --input /path/to/raw_ecommerce.csv
  python run_pipeline.py --input /path/to/diversified_ecommerce_dataset.xlsx
"""
import argparse, csv, os, re, sqlite3, sys, time

EXPECTED = ["product_id", "product_name", "category", "price", "discount", "tax_rate",
            "stock_level", "supplier_id", "customer_age_group", "customer_gender",
            "customer_location", "shipping_method", "shipping_cost", "return_rate",
            "seasonality", "popularity_index"]
NUMERIC = {"price", "discount", "tax_rate", "stock_level", "shipping_cost",
           "return_rate", "popularity_index"}
SCRIPTS = ["01_data_cleaning.sql", "02_analytical_dataset.sql", "03_kpi_analysis.sql",
           "04_additional_analysis.sql", "06_validation_checks.sql"]

LOG = []
def say(msg=""):
    print(msg, flush=True)
    LOG.append(str(msg))

def norm(h):
    return re.sub(r"[^a-z0-9]+", "_", str(h).strip().lower()).strip("_")

def to_num(v):
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return v
    s = str(v).strip().replace(",", "").replace("%", "").replace("$", "")
    try:
        return float(s)
    except ValueError:
        return None

def rows_from_csv(path):
    f = open(path, newline="", encoding="utf-8-sig")
    reader = csv.reader(f)
    return next(reader), reader

def rows_from_xlsx(path):
    try:
        import openpyxl
    except ImportError:
        sys.exit("openpyxl is missing. Run:  pip install openpyxl   (or upload a CSV instead)")
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    it = wb.worksheets[0].iter_rows(values_only=True)
    return next(it), it

def load_raw(con, path):
    say(f"Loading {os.path.basename(path)} ... (1M rows takes 1-6 minutes, please wait)")
    t0 = time.time()
    header, rows = rows_from_xlsx(path) if path.lower().endswith(".xlsx") else rows_from_csv(path)
    cols = [norm(h) for h in header]
    missing = [c for c in EXPECTED if c not in cols]
    if missing:
        sys.exit("\nERROR - these expected columns were not found: %s\nYour file has: %s\n"
                 "Rename the headers in row 1 of your file (see the guide, step 'column names') and retry."
                 % (missing, cols))
    idx = [cols.index(c) for c in EXPECTED]
    con.execute("DROP TABLE IF EXISTS raw_ecommerce")
    con.execute("CREATE TABLE raw_ecommerce (%s)" % ", ".join(EXPECTED))
    sql = "INSERT INTO raw_ecommerce VALUES (%s)" % ",".join("?" * len(EXPECTED))
    batch, n = [], 0
    for r in rows:
        if r is None or all(c is None or c == "" for c in r):
            continue
        rec = []
        for c, i in zip(EXPECTED, idx):
            v = r[i] if i < len(r) else None
            if c in NUMERIC:
                v = to_num(v)
            elif isinstance(v, str):
                v = v.strip()
            rec.append(v)
        batch.append(rec)
        if len(batch) == 50000:
            con.executemany(sql, batch); batch = []; n += 50000
            print(f"  ... {n:,} rows", end="\r", flush=True)
    if batch:
        con.executemany(sql, batch); n += len(batch)
    con.commit()
    say(f"Loaded {n:,} rows into raw_ecommerce in {time.time()-t0:.0f}s")
    # Percent columns must be 0-100 (not 0-1). Fix automatically if Excel stored them as fractions.
    for c in ("discount", "return_rate", "tax_rate"):
        mx = con.execute(f"SELECT MAX({c}) FROM raw_ecommerce").fetchone()[0]
        if mx is not None and mx <= 1.0:
            con.execute(f"UPDATE raw_ecommerce SET {c} = {c} * 100.0")
            say(f"NOTE: {c} was stored as 0-1 fractions; multiplied by 100 to get 0-100.")
    con.commit()
    return n

def show(cur, limit=25):
    rows = cur.fetchall()
    names = [d[0] for d in cur.description]
    say("  " + " | ".join(names))
    for r in rows[:limit]:
        say("  " + " | ".join("" if v is None else (f"{v:,.2f}" if isinstance(v, float) else str(v)) for v in r))
    if len(rows) > limit:
        say(f"  ... ({len(rows)-limit} more rows)")
    return names, rows

def run_script(con, path):
    say("\n" + "=" * 70 + f"\nRUNNING {os.path.basename(path)}\n" + "=" * 70)
    t0, buf, last = time.time(), "", None
    with open(path, encoding="utf-8") as f:
        for line in f:
            buf += line
            if sqlite3.complete_statement(buf):
                stmt, buf = buf.strip(), ""
                cur = con.execute(stmt)
                if cur.description:
                    last = show(cur)
    con.commit()
    say(f"-- finished in {time.time()-t0:.0f}s")
    return last

def export(con, table, out):
    cur = con.execute(f"SELECT * FROM {table}")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([d[0] for d in cur.description])
        n = 0
        for row in cur:
            w.writerow(row); n += 1
    say(f"Exported {n:,} rows -> {out}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="raw .csv or .xlsx (16 columns)")
    ap.add_argument("--db", default="ecommerce.db", help="SQLite file to create (stay out of GitHub)")
    ap.add_argument("--project-dir", default=os.path.dirname(os.path.abspath(__file__)))
    a = ap.parse_args()
    P = a.project_dir
    say(f"SQLite version: {sqlite3.sqlite_version}  (needs 3.25+ for window functions)")
    con = sqlite3.connect(a.db)
    con.execute("PRAGMA journal_mode=OFF"); con.execute("PRAGMA synchronous=OFF")
    load_raw(con, a.input)
    last = None
    for s in SCRIPTS:
        last = run_script(con, os.path.join(P, "sql", s))
    os.makedirs(os.path.join(P, "docs"), exist_ok=True)
    os.makedirs(os.path.join(P, "data"), exist_ok=True)
    if last:  # validation table = result of the last script
        names, rows = last
        with open(os.path.join(P, "docs", "validation_results.csv"), "w", newline="") as f:
            w = csv.writer(f); w.writerow(names); w.writerows(rows)
        statuses = [r[names.index("status")] for r in rows] if "status" in names else []
        verdict = "ALL PASS" if statuses and all(s == "PASS" for s in statuses) else "CHECK FAILURES ABOVE"
        say(f"\n>>> VALIDATION: {verdict} ({statuses.count('PASS')}/{len(statuses)} PASS)")
    export(con, "ds_analytical", os.path.join(P, "data", "ds_analytical.csv"))
    export(con, "ds_price_discount", os.path.join(P, "data", "ds_price_discount.csv"))
    with open(os.path.join(P, "docs", "sql_run_log.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))
    say("Saved docs/sql_run_log.txt and docs/validation_results.csv. DONE.")

if __name__ == "__main__":
    main()
