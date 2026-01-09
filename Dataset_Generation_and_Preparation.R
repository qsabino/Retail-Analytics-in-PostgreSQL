library(dplyr)
library(lubridate)
library(stringi)

set.seed(123)

# ============================================================
# 1. products
# ============================================================
n_products <- 50
products <- tibble(
  product_sku = 1:n_products,
  product_full_description = paste("product", 1:n_products, "full desc"),
  product_gender = sample(c("male", "female", "unisex"), n_products, replace = TRUE),
  product_category = sample(c("furniture", "office supplies", "sports", "electronics", "clothing"), n_products, replace = TRUE),
  product_name = paste("product", 1:n_products),
  product_size = sample(c("s","m","l","xl"), n_products, replace = TRUE),
  product_color = sample(c("black","white","blue","green","red"), n_products, replace = TRUE)
)

# ============================================================
# 2. warehouses
# ============================================================
n_warehouses <- 5
warehouses <- tibble(
  warehouse_id = 1:n_warehouses,
  warehouse_location = paste("warehouse", 1:n_warehouses),
  region = sample(c("africa", "north america", "south america", "europe", "asia"), n_warehouses, replace = TRUE),
  capacity = sample(1000:5000, n_warehouses, replace = TRUE)
)

# ============================================================
# 3. retailers
# ============================================================
n_retailers <- 30
retailers <- tibble(
  retailer_id = 1:n_retailers,
  retailer_channel = sample(c("online", "in-store", "distributor"), n_retailers, replace = TRUE),
  retailer_name = paste("retailer", 1:n_retailers),
  city = paste("city", sample(1:20, n_retailers, replace = TRUE)),
  region = sample(c("africa", "north america", "south america", "europe", "asia"), n_retailers, replace = TRUE),
  area = sample(c("urban","suburban","rural"), n_retailers, replace = TRUE),
  country = sample(c("usa","uk","india","brazil","germany"), n_retailers, replace = TRUE),
  distance_from_warehouse = round(runif(n_retailers, 10, 500), 1)
)

# ============================================================
# 4. customers
# ============================================================
n_customers <- 200
customers <- tibble(
  customer_id = 1:n_customers,
  customer_name = paste("customer", 1:n_customers),
  age_group = sample(c("18-25","26-35","36-45","46-60","60+"), n_customers, replace = TRUE),
  gender = sample(c("male","female","unisex"), n_customers, replace = TRUE),
  region = sample(c("africa", "north america", "south america", "europe", "asia"), n_customers, replace = TRUE),
  channel = sample(c("online","in-store"), n_customers, replace = TRUE),
  loyalty_score = round(runif(n_customers, 0, 100),1)
)

# ============================================================
# 5. orders
# ============================================================
n_orders <- 500
orders <- tibble(
  order_id = 1001:(1000 + n_orders),
  order_date = sample(seq(as.Date('2021-01-01'), as.Date('2024-12-31'), by="day"), n_orders, replace = TRUE),
  retailer_id = sample(retailers$retailer_id, n_orders, replace = TRUE),
  product_sku = sample(products$product_sku, n_orders, replace = TRUE),
  product_price = round(runif(n_orders, 20, 1000),2),
  product_cost = round(runif(n_orders, 10, 800),2),
  order_quantity = sample(1:10, n_orders, replace = TRUE),
  customer_id = sample(customers$customer_id, n_orders, replace = TRUE)
) %>%
  mutate(
    product_discount = round(product_price * order_quantity * runif(n(), 0, 0.3), 2)
  )

# ============================================================
# 6. promotions
# ============================================================
n_promotions <- 30
promotions <- tibble(
  promotion_id = 1:n_promotions,
  product_sku = sample(products$product_sku, n_promotions, replace = TRUE),
  start_date = sample(seq(as.Date('2021-01-01'), as.Date('2024-12-01'), by="day"), n_promotions, replace = TRUE),
  end_date = sample(seq(as.Date('2021-01-02'), as.Date('2024-12-31'), by="day"), n_promotions, replace = TRUE),
  discount_percentage = round(runif(n_promotions, 5, 50),1),
  campaign_name = paste("promo", 1:n_promotions)
) %>%
  mutate(
    end_date = if_else(end_date < start_date, start_date + sample(5:30, n_promotions, replace = TRUE), end_date)
  )

# ============================================================
# 7. shippings
# ============================================================
shippings <- orders %>%
  select(order_id, order_date) %>%
  mutate(
    ship_date = order_date + sample(1:5, nrow(.), replace = TRUE),
    delivery_duration = sample(2:10, nrow(.), replace = TRUE),
    delivery_date = ship_date + delivery_duration,
    shipping_method = sample(c("standard", "express", "same-day"), nrow(.), replace = TRUE),
    carrier = sample(c("fedex", "ups", "dhl", "usps"), nrow(.), replace = TRUE),
    shipping_cost = round(runif(nrow(.), 5, 50), 2),
    delivery_status = sample(c("on-time", "delayed", "returned"), nrow(.), replace = TRUE, prob = c(0.7, 0.25, 0.05)),
    warehouse_id = sample(warehouses$warehouse_id, nrow(.), replace = TRUE)
  )

# ============================================================
# 8. returns
# ============================================================
n_returns <- 50
returns <- tibble(
  order_id = sample(orders$order_id, n_returns, replace = TRUE),
  return_year = sample(2021:2024, n_returns, replace = TRUE),
  return_month = sample(1:12, n_returns, replace = TRUE),
  return_day = sample(1:28, n_returns, replace = TRUE),
  hour = sample(0:23, n_returns, replace = TRUE),
  minute = sample(0:59, n_returns, replace = TRUE),
  second = sample(0:59, n_returns, replace = TRUE)
) %>%
  mutate(
    returndate = as.POSIXct(ISOdatetime(return_year, return_month, return_day, hour, minute, second, tz = "UTC"))
  ) %>%
  left_join(orders %>% select(order_id, product_sku, order_quantity), by = "order_id") %>%
  rowwise() %>%
  mutate(return_quantity = sample(1:order_quantity, 1)) %>%
  ungroup() %>%
  select(order_id, product_sku, return_quantity, return_year, return_month, return_day, returndate)

# ============================================================
# 9. calendar
# ============================================================
all_dates <- seq(as.Date("2021-01-01"), as.Date("2024-12-31"), by="day")
calendar <- tibble(
  date = all_dates,
  year = year(all_dates),
  month = month(all_dates),
  quarter = quarter(all_dates),
  weekday = weekdays(all_dates),
  is_holiday = sample(c(TRUE, FALSE), length(all_dates), replace = TRUE, prob = c(0.1, 0.9))
)

# Write CSVs files
write.csv(products, "dim_products.csv", row.names = FALSE)
write.csv(warehouses, "dim_warehouses.csv", row.names = FALSE)
write.csv(retailers, "dim_retailers.csv", row.names = FALSE)
write.csv(customers, "dim_customers.csv", row.names = FALSE)
write.csv(orders, "fact_orders.csv", row.names = FALSE)
write.csv(promotions, "dim_promotions.csv", row.names = FALSE)
write.csv(shippings, "fact_shippings.csv", row.names = FALSE)
write.csv(returns, "fact_returns.csv", row.names = FALSE)
write.csv(calendar, "dim_date.csv", row.names = FALSE)



if(!require(DBI)) install.packages("DBI")
if(!require(RPostgres)) install.packages("RPostgres")

library(DBI)
library(RPostgres)

# 1. Connect to PostgreSQL
con <- dbConnect(RPostgres::Postgres(),
                 dbname = "Retail_Analytics",
                 host = "localhost",
                 port = 5432,
                 user = "postgres",
                 password = "1979")

# 2. Create tables in PostgeSQL using R
# 1. Products
dbExecute(con,"
CREATE TABLE dim_products (
  product_sku             INT PRIMARY KEY,
  product_full_description TEXT,
  product_gender          VARCHAR(20),
  product_category        VARCHAR(50),
  product_name            VARCHAR(50),
  product_size            VARCHAR(10),
  product_color           VARCHAR(20)
);")

# 2. Warehouses
dbExecute(con,"
CREATE TABLE dim_warehouses (
  warehouse_id       INT PRIMARY KEY,
  warehouse_location VARCHAR(50),
  region             VARCHAR(50),
  capacity           INT
);")

# 3. Retailers
dbExecute(con,"
CREATE TABLE dim_retailers (
  retailer_id              INT PRIMARY KEY,
  retailer_channel         VARCHAR(20),
  retailer_name            VARCHAR(50),
  city                     VARCHAR(50),
  region                   VARCHAR(50),
  area                     VARCHAR(20),
  country                  VARCHAR(50),
  distance_from_warehouse  NUMERIC(10,2)
);")

# 4. Customers
dbExecute(con,"
CREATE TABLE dim_customers (
  customer_id     INT PRIMARY KEY,
  customer_name   VARCHAR(50),
  age_group       VARCHAR(20),
  gender          VARCHAR(20),
  region          VARCHAR(50),
  channel         VARCHAR(20),
  loyalty_score   NUMERIC(5,1)
);")

# 5. Promotions
dbExecute(con,"
CREATE TABLE dim_promotions (
  promotion_id        INT PRIMARY KEY,
  product_sku         INT REFERENCES dim_products(product_sku),
  start_date          DATE,
  end_date            DATE,
  discount_percentage NUMERIC(10,1),
  campaign_name       VARCHAR(50)
);")

# 6. Calendar
dbExecute(con,"
CREATE TABLE dim_date (
  date        DATE PRIMARY KEY,
  year        INT,
  month       INT,
  quarter     INT,
  weekday     VARCHAR(20),
  is_holiday  BOOLEAN
);")

# 7. Orders
dbExecute(con,"
CREATE TABLE fact_orders (
  order_id         INT PRIMARY KEY,
  order_date       DATE,
  retailer_id      INT REFERENCES dim_retailers(retailer_id),
  product_sku      INT REFERENCES dim_products(product_sku),
  product_price    NUMERIC(10,2),
  product_cost     NUMERIC(10,2),
  order_quantity   INT,
  customer_id      INT REFERENCES dim_customers(customer_id),
  product_discount NUMERIC(10,2)
);")

# 8. Shippings
dbExecute(con,"
CREATE TABLE fact_shippings (
  order_id           INT PRIMARY KEY REFERENCES fact_orders(order_id),
  order_date         DATE,
  ship_date          DATE,
  delivery_duration  INT,
  delivery_date      DATE,
  shipping_method    VARCHAR(20),
  carrier            VARCHAR(20),
  shipping_cost      NUMERIC(10,2),
  delivery_status    VARCHAR(20),
  warehouse_id       INT REFERENCES dim_warehouses(warehouse_id)
);")

# 9. Returns
dbExecute(con,"
CREATE TABLE fact_returns (
  return_id       SERIAL PRIMARY KEY,
  order_id        INT REFERENCES fact_orders(order_id),
  product_sku     INT REFERENCES dim_products(product_sku),
  return_quantity INT,
  return_year     INT,
  return_month    INT,
  return_day      INT,
  returndate      TIMESTAMP
);")


# 3. Read CSVs
products <- read.csv("dim_products.csv")
warehouses <- read.csv("dim_warehouses.csv")
retailers <- read.csv("dim_retailers.csv")
customers <- read.csv("dim_customers.csv")
orders <- read.csv("fact_orders.csv")
promotions <- read.csv("dim_promotions.csv")
shippings <- read.csv("fact_shippings.csv")
returns <- read.csv("fact_returns.csv")
date <- read.csv("dim_date.csv")

# 4. Insert data into tables in PostgeSQL using R
dbWriteTable(con, 
             name = "dim_products", 
             value = products, 
             append = TRUE, 
             row.names = FALSE)

dbWriteTable(con, "dim_warehouses", warehouses, append=TRUE, row.names=FALSE)
dbWriteTable(con, "dim_retailers", retailers, append=TRUE, row.names=FALSE)
dbWriteTable(con, "dim_customers", customers, append=TRUE, row.names=FALSE)
dbWriteTable(con, "fact_orders", orders, append=TRUE, row.names=FALSE)
dbWriteTable(con, "dim_promotions", promotions, append=TRUE, row.names=FALSE)
dbWriteTable(con, "fact_shippings", shippings, append=TRUE, row.names=FALSE)
dbWriteTable(con, "fact_returns", returns, append=TRUE, row.names=FALSE)
dbWriteTable(con, "dim_date", date, append=TRUE, row.names=FALSE)

# 5. Check by reading back the data
head(dbReadTable(con, "dim_products"))
head(dbReadTable(con, "dim_warehouses"))
head(dbReadTable(con, "dim_retailers"))
head(dbReadTable(con, "dim_customers"))
head(dbReadTable(con, "fact_orders"))
head(dbReadTable(con, "dim_promotions"))
head(dbReadTable(con, "fact_shippings"))
head(dbReadTable(con, "fact_returns"))
head(dbReadTable(con, "dim_date"))

dbDisconnect(con)
