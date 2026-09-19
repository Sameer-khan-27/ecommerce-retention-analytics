import os
import random
from datetime import datetime, timedelta
import numpy as np
import pandas as pd
from faker import Faker
from sqlalchemy import create_engine

# 1. Database Connection Details
DB_USER = "postgres"
DB_PASS = "admin123"  # Replace if your PostgreSQL password is different
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "ecommerce_db"

DATABASE_URL = f"postgresql+psycopg://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL)

# 2. Parameters for Realistic E-Commerce Simulation
TOTAL_ROWS = 500000
NUM_CUSTOMERS = 18000
NUM_PRODUCTS = 450
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2024, 12, 31)
DATE_RANGE_DAYS = (END_DATE - START_DATE).days

fake = Faker()
random.seed(42)
np.random.seed(42)

print(f"Generating synthetic profiles for {NUM_CUSTOMERS:,} customers...")

# Customer pool with randomized acquisition dates
customer_ids = [f"CUST_{10000 + i}" for i in range(NUM_CUSTOMERS)]
customer_first_dates = {
    cid: START_DATE + timedelta(days=random.randint(0, DATE_RANGE_DAYS - 60))
    for cid in customer_ids
}

# Product catalog
product_catalog = [
    (
        f"PRD_{100 + i}",
        fake.catch_phrase(),
        round(float(np.random.exponential(scale=28.0) + 2.5), 2),
    )
    for i in range(NUM_PRODUCTS)
]
countries = ["United Kingdom", "Germany", "France", "Spain", "Netherlands", "USA", "Australia"]
country_weights = [0.65, 0.10, 0.08, 0.05, 0.04, 0.05, 0.03]

print(f"Generating {TOTAL_ROWS:,} realistic transactional records...")

records = []
for i in range(TOTAL_ROWS):
    cid = random.choice(customer_ids)
    first_date = customer_first_dates[cid]
    
    # Simulate repeat order decay (exponential inter-purchase time)
    max_days = (END_DATE - first_date).days
    order_offset = int(np.random.exponential(scale=45.0))
    if order_offset > max_days:
        order_offset = random.randint(0, max_days)
    
    order_date = first_date + timedelta(days=order_offset, hours=random.randint(8, 20), minutes=random.randint(0, 59))
    prod_id, prod_name, unit_price = random.choice(product_catalog)
    
    qty = int(np.random.choice([1, 2, 3, 4, 5, 8, 12, 24], p=[0.45, 0.25, 0.12, 0.08, 0.04, 0.03, 0.02, 0.01]))
    
    # 2% return/cancellation rate for realistic data cleaning
    invoice_prefix = "C" if random.random() < 0.02 else ""
    if invoice_prefix == "C":
        qty = -qty

    records.append({
        "invoice_no": f"{invoice_prefix}{500000 + (i // 3)}",
        "stock_code": prod_id,
        "description": prod_name,
        "quantity": qty,
        "invoice_date": order_date,
        "unit_price": unit_price,
        "customer_id": cid,
        "country": random.choices(countries, weights=country_weights)[0]
    })

df = pd.DataFrame(records)

# Save clean CSV copy inside data/
OUTPUT_CSV = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "online_retail.csv")
print(f"Saving generated clean CSV to {OUTPUT_CSV}...")
df.to_csv(OUTPUT_CSV, index=False)

print(f"Loading {len(df):,} records into PostgreSQL (raw_transactions)...")
df.to_sql(
    name="raw_transactions",
    con=engine,
    if_exists="replace",
    index=False,
    chunksize=50000,
)

print("SUCCESS: 500,000 rows generated and loaded into ecommerce_db!")