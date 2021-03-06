/*
Add number of CYF (Child Youth and Family) placement events to the main fact table.

For now, we are just counting all the events.  Not removing duplicates or making any other kind of filtering.

An alternative approach would take into account how long each event is, and count days on placement.

Peter Ellis 4 November 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(25) = 'Placement_events'
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
		measured_variable_description,
		target_variable_description,
		origin_tables,
		units,
		earliest_data,
		date_built,
		variable_class) 
	VALUES   
		(@var_name,
		'Number of child, youth and family placement events',
		'Good',
		'CYF',
		'count',
		'person-period',
		'Simple count of all commencing placement events, ignoring their length.  No attempt has been made at this stage to remove duplicates or any other filtering.',
		'How much has the state intervened in placing this person in different homes?',
		'IDI_Clean.cyf_clean.cyf_placements_event',
		'number of events',
		(SELECT MIN(cyf_ple_event_from_date_wid_date) FROM IDI_Clean.cyf_clean.cyf_placements_event),
		(SELECT CONVERT(date, GETDATE())),
		'Family and childhood')


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('One', @var_code, 1), 
		 ('Two to five', @var_code, 2),
		 ('Six or more', @var_code, 3)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code


----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code	AS fk_variable_code,
	occurences	AS value,
	value_code	AS fk_value_code
FROM
	(SELECT
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		occurences,
		CASE
			WHEN occurences = 1							THEN 'One'
			WHEN occurences > 1 AND occurences <= 5		THEN 'Two to five'	
			WHEN occurences > 5							THEN 'Six or more'	
		END AS cyf_cat
	
	FROM
		(SELECT
			c.snz_uid  AS fk_snz_uid,
			COUNT(1) AS occurences,
			ye_dec_date
		FROM IDI_Clean.cyf_clean.cyf_placements_event AS c
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date	AS d1
			ON c.cyf_ple_event_from_date_wid_date = d1.date_dt
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON p.snz_uid = c.snz_uid
		GROUP BY d1.ye_dec_date, c.snz_uid) AS orig )			AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
	ON with_cats.cyf_cat = vc.value_category;


