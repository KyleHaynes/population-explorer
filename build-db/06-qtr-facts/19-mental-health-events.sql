/*
Add number of mental health occurrences to the fact table and relevant dimensions to the dimension tables.
Counts one offence per mental health incident, per person, per march ye.  

Incidents come from the previously created intermediate.mha_events table, which has mental-health-related
interactions with pharamceuticals, lab tests, hospitals, MSD (reason for incapacity), and PRIMHD

Peter Ellis 3 November 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Mental_health'
USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';



-- grab back from the table the code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('One', @var_code, 1), 
		 ('Two to five', @var_code, 2),
		 ('Six to 25', @var_code, 3),
		 ('26 or more', @var_code, 4)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code


----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code	AS fk_variable_code,
	occurences	AS value,
	value_code	AS fk_value_code
FROM
	(SELECT
		qtr_end_date AS fk_date_period_ending,
		fk_snz_uid,
		occurences,
		CASE
			WHEN occurences = 1							THEN 'One'
			WHEN occurences > 1 AND occurences <= 5		THEN 'Two to five'	
			WHEN occurences > 5 AND occurences <= 25	THEN 'Six to 25'	
			WHEN occurences > 25						THEN '26 or more'	
		END AS mha_cat
	
	FROM
		(SELECT
			m.snz_uid  AS fk_snz_uid,
			COUNT(1) AS occurences,
			qtr_end_date
		FROM IDI_Sandpit.intermediate.mha_events	AS m
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON m.snz_uid = p.snz_uid
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date	AS d1
			ON m.start_date = d1.date_dt
		GROUP BY d1.qtr_end_date, m.snz_uid) AS orig )			AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
	ON with_cats.mha_cat = vc.value_category;

