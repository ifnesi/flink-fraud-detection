INSERT INTO `fraud-detection-enriched`
WITH `fraud-detection-paired` AS (
    SELECT
        decode(key, 'utf-8') AS `key`,
        `timestamp` AS `current_timestamp`,
        transaction_id AS current_transaction_id,
        lat AS current_lat,
        lng AS current_lng,
        amount AS current_amount,
        LAG(`timestamp`, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_timestamp,
        LAG(transaction_id, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_transaction_id,
        LAG(lat, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_lat,
        LAG(lng, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_lng,
        LAG(amount, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_amount
    FROM `fraud-detection`
    WHERE transaction_id IS NOT NULL
)
SELECT
    `key`,
    current_timestamp,
    current_transaction_id,
    current_lat,
    current_lng,
    current_amount,
    TO_TIMESTAMP_LTZ(previous_timestamp, 3) AS previous_timestamp,
    previous_transaction_id,
    previous_lat,
    previous_lng,
    previous_amount,
    -- Speed in kilometers per hour using Haversine formula
    6371 * 2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(current_lat - previous_lat) / 2), 2) +
            COS(RADIANS(previous_lat)) * COS(RADIANS(current_lat)) *
            POWER(SIN(RADIANS(current_lng - previous_lng) / 2), 2)
        )
    ) / ((`current_timestamp` - previous_timestamp) / 3600000.0) AS speed_kph
FROM `fraud-detection-paired`
WHERE previous_timestamp IS NOT NULL;
