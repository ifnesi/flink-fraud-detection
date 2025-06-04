ALTER TABLE `fraud-detection` MODIFY WATERMARK FOR $rowtime AS $rowtime;
