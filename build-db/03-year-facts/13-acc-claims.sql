
/*
Number (not value) of ACC claims

Follows the usual pattern.

Peter Ellis and Miriam Tankersley 11 October 2017

Miriam Tankersley 24 October 2017, 
Updates to align with new dim_date table:
Replaced datecode with date, and removed extra join to date table (as no longer need to look up datecode).

*/


IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'ACC_claims';

USE IDI_Sandpit

EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';



----------------add variable to the variable table-------------------

INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		(short_name, 
		long_name,
		quality,
		origin,
		var_type,
		grain,
		units,
		measured_variable_description,
		target_variable_description,
		origin_tables,
		date_built,
		variable_class) 
	VALUES   
		(@var_name,
		'ACC Injury Claims',
		'Good',
		'ACC',
		'count',
		'person-period',
		'number of claims',
		'Count by person of all ACC claims, rolled up into the relevant period based on accident date.  No filtering or removal of duplicates has been done.',
		'How many accidents did this person suffer in a given time period?',
		'IDI_Clean.acc_clean.claims',
		(SELECT CONVERT(date, GETDATE())),
		'Health and wellbeing');

-- grab back from the table the new code for our variable and store as a temp table #var_code		
DECLARE @var_code INT;	 
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('One claim', @var_code, 1),
		 ('Two to five claims', @var_code, 2),
		 ('Six or more claims', @var_code, 3);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code;
	
----------------add facts to the fact table-------------------------


INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT
	fk_date_period_ending,
	fk_snz_uid,
	fk_variable_code,
	value,
	value_code AS fk_value_code
FROM
	(SELECT
		ye_dec_date AS fk_date_period_ending,
		snz_uid AS fk_snz_uid,
		@var_code AS fk_variable_code,
		value,
		CASE 
			WHEN value = 1 THEN 'One claim'
			WHEN value >1 AND value <6 THEN 'Two to five claims'
			WHEN value > 5 THEN 'Six or more claims'
		END AS value_category
	FROM
		(SELECT  
			COUNT(*) AS value,
			claims.snz_uid,
			ye_dec_date
		FROM IDI_Clean.acc_clean.claims AS claims
			-- we only want people in our dimension table:
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS spine
				ON claims.snz_uid = spine.snz_uid
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS dte
				ON claims.acc_cla_accident_date = dte.date_dt
			GROUP BY claims.snz_uid, ye_dec_date
		) AS by_year 
	) AS with_cats
LEFT JOIN #value_codes AS vc
ON with_cats.value_category = vc.value_category

