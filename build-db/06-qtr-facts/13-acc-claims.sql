
/*
Number (not value) of ACC claims

Follows the usual pattern.


*/


IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'ACC_claims';

USE IDI_Sandpit

EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';



-- grab back from the table the new code for our variable and store as a temp table #var_code		
DECLARE @var_code INT;	 
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('One claim', @var_code, 1),
		 ('Two to three claims', @var_code, 2),
		 ('Four or more claims', @var_code, 3);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code;
	
----------------add facts to the fact table-------------------------


INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT
	fk_date_period_ending,
	fk_snz_uid,
	fk_variable_code,
	value,
	value_code AS fk_value_code
FROM
	(SELECT
		qtr_end_date AS fk_date_period_ending,
		snz_uid AS fk_snz_uid,
		@var_code AS fk_variable_code,
		value,
		CASE 
			WHEN value = 1 THEN 'One claim'
			WHEN value >1 AND value <4 THEN 'Two to three claims'
			WHEN value > 3 THEN 'Four or more claims'
		END AS value_category
	FROM
		(SELECT  
			COUNT(*) AS value,
			claims.snz_uid,
			qtr_end_date
		FROM IDI_Clean.acc_clean.claims AS claims
			-- we only want people in our dimension table:
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS spine
				ON claims.snz_uid = spine.snz_uid
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS dte
				ON claims.acc_cla_accident_date = dte.date_dt
			GROUP BY claims.snz_uid, qtr_end_date
		) AS by_qtr 
	) AS with_cats
LEFT JOIN #value_codes AS vc
ON with_cats.value_category = vc.value_category

