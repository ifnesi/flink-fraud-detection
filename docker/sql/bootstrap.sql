-- Create users-config table
DROP TABLE IF EXISTS `users-config`;
CREATE TABLE `users-config` (
  `key` BYTES,
  `first_name` STRING,
  `last_name` STRING,
  `max_speed` DOUBLE,
  PRIMARY KEY (`key`) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'users-config',
  'properties.bootstrap.servers' = 'broker:29092',
  'key.format' = 'raw',
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schema-registry:8081',
  'value.fields-include' = 'EXCEPT_KEY'
);
-- 
-- Create card-transactions table
DROP TABLE IF EXISTS `card-transactions`;
CREATE TABLE `card-transactions` (
  `key` BYTES,
  `timestamp` TIMESTAMP(3),
  `transaction_id` STRING,
  `lat` DOUBLE,
  `lng` DOUBLE,
  `amount` DOUBLE,
  WATERMARK FOR `timestamp` AS `timestamp`
) WITH (
  'connector' = 'kafka',
  'topic' = 'card-transactions',
  'properties.bootstrap.servers' = 'broker:29092',
  'properties.group.id' = 'flink-card-transactions',
  'scan.startup.mode' = 'earliest-offset',
  'key.format'  = 'raw',
  'key.fields'  = 'key',
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schema-registry:8081',
  'value.fields-include' = 'EXCEPT_KEY'
);
-- 
-- Create card-transactions-enriched table
DROP TABLE IF EXISTS `card-transactions-enriched`;;
CREATE TABLE `card-transactions-enriched` (
  `key` BYTES,
  `current_timestamp` TIMESTAMP(3),
  `current_transaction_id` STRING,
  `current_lat` DOUBLE,
  `current_lng` DOUBLE,
  `current_amount` DOUBLE,
  `previous_timestamp` TIMESTAMP(3),
  `previous_transaction_id` STRING,
  `previous_lat` DOUBLE,
  `previous_lng` DOUBLE,
  `previous_amount` DOUBLE,
  `first_name` STRING,
  `last_name` STRING,
  `max_speed` DOUBLE,
  `speed` DOUBLE,
  WATERMARK FOR `current_timestamp` AS `current_timestamp`,
  PRIMARY KEY (`key`) NOT ENFORCED
) WITH (
  'connector' = 'upsert-kafka',
  'topic' = 'card-transactions-enriched',
  'properties.bootstrap.servers' = 'broker:29092',
  'key.format' = 'raw',
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schema-registry:8081',
  'value.fields-include' = 'EXCEPT_KEY'
);
-- 
-- Insert into card-transactions-enriched table
INSERT INTO `card-transactions-enriched`
WITH `card-transactions-paired` AS (
  SELECT
    `key`,
    `timestamp` AS `current_timestamp`,
    `transaction_id` AS `current_transaction_id`,
    `lat` AS `current_lat`,
    `lng` AS `current_lng`,
    `amount` AS `current_amount`,
    LAG(`timestamp`, 1) OVER (PARTITION BY `key` ORDER BY `timestamp`) AS `previous_timestamp`,
    LAG(`transaction_id`, 1) OVER (PARTITION BY `key` ORDER BY `timestamp`) AS `previous_transaction_id`,
    LAG(`lat`, 1) OVER (PARTITION BY `key` ORDER BY `timestamp`) AS `previous_lat`,
    LAG(`lng`, 1) OVER (PARTITION BY `key` ORDER BY `timestamp`) AS `previous_lng`,
    LAG(`amount`, 1) OVER (PARTITION BY `key` ORDER BY `timestamp`) AS `previous_amount`
  FROM `card-transactions`
  WHERE `transaction_id` IS NOT NULL
)
SELECT
  fd.`key`,
  fd.`current_timestamp`,
  fd.`current_transaction_id`,
  fd.`current_lat`,
  fd.`current_lng`,
  fd.`current_amount`,
  fd.`previous_timestamp`,
  fd.`previous_transaction_id`,
  fd.`previous_lat`,
  fd.`previous_lng`,
  fd.`previous_amount`,
  fdc.`first_name`,
  fdc.`last_name`,
  fdc.`max_speed`,
  -- distance_km / hours
  ABS(
    6371 * 2 * ASIN(
      SQRT(
        POWER(SIN(RADIANS(fd.`current_lat` - fd.`previous_lat`) / 2), 2) +
        COS(RADIANS(fd.`previous_lat`)) * COS(RADIANS(fd.`current_lat`)) *
        POWER(SIN(RADIANS(fd.`current_lng` - fd.`previous_lng`) / 2), 2)
      )
    )
  )
  / (TIMESTAMPDIFF(SECOND, fd.`previous_timestamp`, fd.`current_timestamp`) / 3600.0)
  AS `speed`
FROM `card-transactions-paired` AS fd
LEFT JOIN `users-config` AS fdc ON fd.`key` = fdc.`key`
WHERE fd.`previous_timestamp` IS NOT NULL;