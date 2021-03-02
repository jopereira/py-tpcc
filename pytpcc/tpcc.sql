CREATE TABLE "warehouse" (
  "w_id" int PRIMARY KEY,
  "w_name" varchar(10),
  "w_street_1" varchar(20),
  "w_street_2" varchar(20),
  "w_city" varchar(20),
  "w_state" char(2),
  "w_zip" char(9),
  "w_tax" numeric(4,4)
);

CREATE TABLE "district" (
  "d_id" int,
  "d_w_id" int,
  "d_name" varchar(10),
  "d_street_1" varchar(20),
  "d_street_2" varchar(20),
  "d_city" varchar(20),
  "d_state" char(2),
  "d_zip" char(9),
  "d_tax" numeric(4,4),
  PRIMARY KEY ("d_id", "d_w_id"),
  FOREIGN KEY ("d_w_id") REFERENCES "warehouse" ("w_id")
);

CREATE TABLE "customer" (
  "c_id" int,
  "c_d_id" int,
  "c_w_id" int,
  "c_first" varchar(16),
  "c_middle" char(2),
  "c_last" varchar(16),
  "c_street_1" varchar(20),
  "c_street_2" varchar(20),
  "c_city" varchar(20),
  "c_state" char(2),
  "c_zip" char(9),
  "c_phone" char(16),
  "c_since" timestamp,
  "c_credit" char(2),
  "c_credit_lim" numeric(12, 2),
  "c_discount" numeric(4,4),
  "c_data" varchar(500),
  PRIMARY KEY ("c_id", "c_d_id", "c_w_id"),
  FOREIGN KEY ("c_d_id", "c_w_id") REFERENCES "district" ("d_id", "d_w_id")
);

CREATE TABLE "history" (
  "h_c_id" int,
  "h_c_d_id" int,
  "h_c_w_id" int,
  "h_d_id" int,
  "h_w_id" int,
  "h_date" timestamp,
  "h_amount" numeric(6, 2),
  "h_data" varchar(24),
  PRIMARY KEY ("h_c_id", "h_c_d_id", "h_c_w_id", "h_d_id", "h_w_id", "h_date"),
  FOREIGN KEY ("h_c_id", "h_c_d_id", "h_c_w_id") REFERENCES "customer" ("c_id", "c_d_id", "c_w_id"),
  FOREIGN KEY ("h_d_id", "h_w_id") REFERENCES "district" ("d_id", "d_w_id")
);

CREATE TABLE "item" (
  "i_id" int PRIMARY KEY,
  "i_im_id" int,
  "i_name" varchar(24),
  "i_price" numeric(5,2),
  "i_data" varchar(50)
);

CREATE TABLE "orders" (
  "o_entry_d" timestamp,
  "o_d_id" int,
  "o_w_id" int,
  "o_c_id" int,
  PRIMARY KEY ("o_entry_d", "o_d_id", "o_w_id"),
  FOREIGN KEY ("o_d_id", "o_w_id", "o_c_id") REFERENCES "customer" ("c_d_id", "c_w_id", "c_id")
);

CREATE TABLE "order_line" (
  "ol_entry_d" timestamp,
  "ol_d_id" int,
  "ol_w_id" int,
  "ol_number" int,
  "ol_i_id" int,
  "ol_supply_w_id" int,
  "ol_quantity" int,
  "ol_dist_info" char(24),
  PRIMARY KEY ("ol_entry_d", "ol_d_id", "ol_w_id", "ol_number"),
  FOREIGN KEY ("ol_entry_d", "ol_d_id", "ol_w_id") REFERENCES "orders" ("o_entry_d", "o_d_id", "o_w_id"),
  FOREIGN KEY ("ol_i_id") REFERENCES "item" ("i_id"),
  FOREIGN KEY ("ol_supply_w_id") REFERENCES "warehouse" ("w_id")
);

CREATE TABLE "delivery" (
  "dl_delivery_d" timestamp PRIMARY KEY,
  "dl_w_id" int,
  "dl_carrier_id" int,
  FOREIGN KEY ("dl_w_id") REFERENCES "warehouse" ("w_id")
);

CREATE TABLE "stock" (
  "s_i_id" int,
  "s_w_id" int,
  "s_dist_01" char(24),
  "s_dist_02" char(24),
  "s_dist_03" char(24),
  "s_dist_04" char(24), 
  "s_dist_05" char(24),
  "s_dist_06" char(24),
  "s_dist_07" char(24),
  "s_dist_08" char(24),
  "s_dist_09" char(24),
  "s_dist_10" char(24),
  "s_data" varchar(50),
  PRIMARY KEY ("s_i_id", "s_w_id"),
  FOREIGN KEY ("s_i_id") REFERENCES "item" ("i_id"),
  FOREIGN KEY ("s_w_id") REFERENCES "warehouse" ("w_id")
);

--CREATE INDEX IDX_ORDER_LINE_3COL ON ORDER_LINE (OL_W_ID,OL_D_ID,OL_O_ID);
--CREATE INDEX IDX_ORDER_LINE_2COL ON ORDER_LINE (OL_W_ID,OL_D_ID);
CREATE INDEX IDX_ORDER_LINE_TREE ON "order_line" ("ol_d_id","ol_w_id","ol_entry_d");

CREATE VIEW "orders_id" AS (
  SELECT
    o_entry_d,
    o_d_id AS d_id,
    o_w_id AS w_id,
    ROW_NUMBER() OVER (PARTITION BY o_d_id, o_w_id ORDER BY o_entry_d) AS o_id
  FROM orders
);

CREATE VIEW "delivery_id" AS (
  SELECT
    dl_delivery_d,
    dl_w_id AS w_id,
    ROW_NUMBER() OVER (PARTITION BY dl_w_id ORDER BY dl_delivery_d) AS dl_id
  FROM delivery
);

CREATE VIEW "orders_delivery_match" AS (
  WITH minimum_delivery AS (
    SELECT
      o_entry_d,
      o_d_id AS d_id,
      o_w_id AS w_id,
      MIN(dl_delivery_d) AS dl_delivery_d
    FROM orders
    LEFT JOIN delivery
    ON o_w_id = dl_w_id
    WHERE o_entry_d < dl_delivery_d
    GROUP BY o_entry_d, o_d_id, o_w_id
  ),
  orders_delivery_match AS (
    SELECT
      o_id,
      d_id,
      w_id,
      o_id + MAX(dl_id - o_id) OVER (PARTITION BY d_id, w_id ORDER BY o_entry_d) AS dl_id
    FROM minimum_delivery
    LEFT JOIN orders_id USING(o_entry_d, d_id, w_id)
    LEFT JOIN delivery_id USING(dl_delivery_d, w_id)
  )
  SELECT
    o_id,
    o_entry_d,
    d_id AS o_d_id,
    w_id AS o_w_id,
    dl_id,
    dl_delivery_d,
    w_id AS dl_w_id
  FROM orders_delivery_match
  LEFT JOIN orders_id USING(o_id, d_id, w_id)
  LEFT JOIN delivery_id USING(dl_id, w_id)
);

CREATE VIEW "orders_view" AS (
  WITH order_line_stats AS (
    SELECT
      o_entry_d,
      o_d_id,
      o_w_id,
      COUNT(*) AS o_ol_cnt,
      COUNT(NULLIF(ol_supply_w_id, o_w_id)) = 0 AS o_all_local
    FROM order_line
    LEFT JOIN orders
    ON o_entry_d = ol_entry_d AND o_d_id = ol_d_id AND o_w_id = ol_w_id
    GROUP BY o_entry_d, o_d_id, o_w_id
  )
  SELECT
    o_id,
    o_d_id,
    o_w_id,
    o_c_id,
    o_entry_d,
    dl_carrier_id AS o_carrier_id,
    o_ol_cnt,
    o_all_local
  FROM orders
  LEFT JOIN order_line_stats USING(o_entry_d, o_d_id, o_w_id)
  LEFT JOIN orders_delivery_match USING(o_entry_d, o_d_id, o_w_id)
  LEFT JOIN delivery USING(dl_delivery_d, dl_w_id)
);

CREATE VIEW "new_order_view" AS (
  SELECT
    o_id AS no_o_id,
    o_d_id AS no_d_id,
    o_w_id AS no_w_id
  FROM orders
  LEFT JOIN orders_delivery_match USING(o_entry_d, o_d_id, o_w_id)
  WHERE dl_delivery_d IS NULL
);

CREATE VIEW "order_line_view" AS (
  SELECT
    o_id AS ol_o_id,
    ol_d_id,
    ol_w_id,
    ol_number,
    ol_i_id,
    ol_supply_w_id,
    dl_delivery_d AS ol_delivery_d,
    ol_quantity,
    ol_quantity * i_price AS ol_amount,
    ol_dist_info
  FROM order_line
  LEFT JOIN orders
  ON ol_entry_d = o_entry_d AND ol_d_id = o_d_id AND ol_w_id = o_w_id
  LEFT JOIN item
  ON ol_i_id = i_id
  LEFT JOIN orders_delivery_match USING(o_entry_d, o_d_id, o_w_id)
  LEFT JOIN delivery USING(dl_delivery_d, dl_w_id)
);

CREATE VIEW "stock_view" AS (
  WITH order_line_stats AS (
    SELECT
      ol_i_id AS s_i_id,
      ol_supply_w_id AS s_w_id,
      SUM(ol_quantity * i_price) AS s_ytd,
      COUNT(*) AS s_order_cnt,
      COUNT(NULLIF(ol_supply_w_id, ol_w_id)) AS s_remote_cnt,
      SUM(ol_quantity) AS total_quantity
    FROM order_line
    LEFT JOIN item
    ON ol_i_id = i_id
    GROUP BY ol_i_id, ol_supply_w_id
  )
  SELECT
    s_i_id,
    s_w_id,
    ((-total_quantity % 91) + 91) % 91 + 10 AS s_quantity,
    s_dist_01,
    s_dist_02,
    s_dist_03,
    s_dist_04,
    s_dist_05,
    s_dist_06,
    s_dist_07,
    s_dist_08,
    s_dist_09,
    s_dist_10,
    s_ytd,
    s_order_cnt,
    s_remote_cnt
    s_data
  FROM stock
  LEFT JOIN order_line_stats USING (s_i_id, s_w_id)
);

CREATE VIEW "customer_view" AS (
  WITH order_line_stats AS (
    SELECT
      o_c_id AS c_id,
      ol_d_id AS c_d_id,
      ol_w_id AS c_w_id,
      SUM(ol_quantity * i_price) AS ol_total
    FROM order_line
    LEFT JOIN orders
    ON o_entry_d = ol_entry_d AND o_d_id = ol_d_id AND o_w_id = ol_w_id
    LEFT JOIN item
    ON i_id = ol_i_id
    GROUP BY ol_d_id, ol_w_id, o_c_id
  ),
  history_stats AS (
    SELECT
      h_c_d_id AS c_d_id,
      h_c_w_id AS c_w_id,
      h_c_id AS c_id,
      SUM(h_amount) AS c_ytd_payment,
      COUNT(*) AS c_payment_cnt
    FROM history
    GROUP BY h_c_d_id, h_c_w_id, h_c_id
  ),
  bc_data AS (
    WITH bc_history AS (
      SELECT
        h_c_d_id,
        h_c_w_id,
        h_c_id,
        h_d_id,
        h_w_id,
        h_amount,
        c_data
      FROM history
      LEFT JOIN customer
      ON h_c_d_id = c_d_id AND h_c_w_id = c_w_id AND h_c_id = c_id
      WHERE c_credit = 'BC'
      ORDER BY h_date DESC
    )
    SELECT
      h_c_id AS c_id,
      h_c_d_id AS c_d_id,
      h_c_w_id AS c_w_id,
      left(string_agg(concat_ws(' ', h_c_d_id, h_c_d_id, h_c_w_id, h_d_id, h_w_id, h_amount), '|') || '|' || c_data, 500) AS bc_c_data-- MAX_C_DATA = 500
    FROM bc_history
    GROUP BY h_c_d_id, h_c_w_id, h_c_id, c_data
  ),
  delivery_stats AS (
    SELECT
      o_c_id AS c_id,
      o_d_id AS c_d_id,
      o_w_id AS c_w_id,
      COUNT(dl_delivery_d) AS c_delivery_cnt
    FROM orders_delivery_match
    LEFT JOIN orders USING(o_entry_d, o_d_id, o_w_id)
    GROUP BY o_c_id, o_d_id, o_w_id
  )
  SELECT
    c_id,
    c_d_id,
    c_w_id,
    c_first,
    c_middle,
    c_last,
    c_street_1,
    c_street_2,
    c_city,
    c_state,
    c_zip,
    c_phone,
    c_since,
    c_credit,
    c_credit_lim,
    c_discount,
    ol_total - c_ytd_payment AS c_balanace,
    c_ytd_payment,
    c_payment_cnt,
    c_delivery_cnt,
    COALESCE(bc_c_data, '') AS c_data
  FROM customer
  LEFT JOIN order_line_stats USING(c_id, c_d_id, c_w_id)
  LEFT JOIN history_stats USING(c_id, c_d_id, c_w_id)
  LEFT JOIN bc_data USING(c_id, c_d_id, c_w_id)
  LEFT JOIN delivery_stats USING(c_id, c_d_id, c_w_id)
);

CREATE VIEW "warehouse_view" AS (
  WITH history_stats AS (
    SELECT
      h_w_id AS w_id,
      SUM(h_amount) as w_ytd
    FROM history
    GROUP BY h_w_id
  )
  SELECT
    w_id,
    w_name,
    w_street_1,
    w_street_2,
    w_city,
    w_state,
    w_zip,
    w_tax,
    w_ytd
  FROM warehouse
  LEFT JOIN history_stats USING(w_id)
);

CREATE VIEW "district_view" AS (
  WITH history_stats AS (
    SELECT
      h_d_id AS d_id,
      h_w_id AS d_w_id,
      SUM(h_amount) as d_ytd
    FROM history
    GROUP BY h_w_id, h_d_id
  ),
  orders_stats AS (
    SELECT
      o_d_id AS d_id,
      o_w_id AS d_w_id,
      COUNT(*) as orders_cnt
    FROM orders
    GROUP BY o_d_id, o_w_id
  )
  SELECT
    d_id,
    d_w_id,
    d_street_1,
    d_street_2,
    d_city,
    d_state,
    d_zip,
    d_tax,
    d_ytd,
    orders_cnt + 1 AS d_next_o_id
  FROM district
  LEFT JOIN history_stats USING(d_id, d_w_id)
  LEFT JOIN orders_stats USING(d_id, d_w_id)
)