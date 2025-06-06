INSERT INTO `fraud-detection-enriched`
WITH `fraud-detection-paired` AS (
    SELECT
        `key`,
        decode(key, 'utf-8') AS user_id,
        `timestamp` AS `current_timestamp`,
        transaction_id AS current_transaction_id,
        lat AS current_lat,
        lng AS current_lng,
        amount AS current_amount,
        LAG(`timestamp`, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS `previous_timestamp`,
        LAG(transaction_id, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_transaction_id,
        LAG(lat, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_lat,
        LAG(lng, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_lng,
        LAG(amount, 1) OVER (PARTITION BY key ORDER BY $rowtime) AS previous_amount
    FROM `fraud-detection`
    WHERE transaction_id IS NOT NULL
)
SELECT
    fd.user_id,
    TO_TIMESTAMP_LTZ(fd.`current_timestamp`, 3) AS `current_timestamp`,
    fd.current_transaction_id,
    fd.current_lat,
    fd.current_lng,
    fd.current_amount,
    TO_TIMESTAMP_LTZ(fd.`previous_timestamp`, 3) AS `previous_timestamp`,
    fd.previous_transaction_id,
    fd.previous_lat,
    fd.previous_lng,
    fd.previous_amount,
    fdc.first_name,
    fdc.last_name,
    fdc.max_speed,
    -- Speed in kilometers per hour using Haversine formula
    ABS(6371 * 2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(fd.current_lat - fd.previous_lat) / 2), 2) +
            COS(RADIANS(fd.previous_lat)) * COS(RADIANS(fd.current_lat)) *
            POWER(SIN(RADIANS(fd.current_lng - fd.previous_lng) / 2), 2)
        )
    )) / ((fd.`current_timestamp` - fd.`previous_timestamp`) / 3600000.0) AS speed_kph
FROM `fraud-detection-paired` AS fd
LEFT JOIN `fraud-detection-config` AS fdc ON fd.`key` = fdc.`key`
WHERE previous_timestamp IS NOT NULL;
