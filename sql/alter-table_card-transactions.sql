ALTER TABLE `card-transactions` MODIFY WATERMARK FOR $rowtime AS $rowtime;
