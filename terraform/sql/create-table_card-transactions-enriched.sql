CREATE TABLE `card-transactions-enriched` (
  `key` STRING PRIMARY KEY NOT ENFORCED,
  `current_timestamp` TIMESTAMP_LTZ(3),
  `current_transaction_id` STRING,
  `current_lat` DOUBLE,
  `current_lng` DOUBLE,
  `current_amount` DOUBLE,
  `previous_timestamp` TIMESTAMP_LTZ(3),
  `previous_transaction_id` STRING,
  `previous_lat` DOUBLE,
  `previous_lng` DOUBLE,
  `previous_amount` DOUBLE,
  `first_name` STRING,
  `last_name` STRING,
  `max_speed` DOUBLE,
  `speed` DOUBLE,
  WATERMARK FOR `current_timestamp` AS `current_timestamp`
) DISTRIBUTED INTO 1 BUCKETS
WITH (
  'key.format' = 'raw',
  'value.format' = 'avro-registry',
  'scan.startup.mode' = 'earliest-offset'
);
