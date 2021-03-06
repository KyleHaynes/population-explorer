/*
Add TA most lived in, from the table made in script 15a, to the fact table.

See description in script 7.  Both this script and those draw on assets saved
in the derived schema intermediate.address_mid_month and intermediate.dim_meshblock which have
information on where people were living on 15th of each motnh.

Peter Ellis 
16 October created
*/




IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'TA';

USE IDI_Sandpit

EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';

----------------add variable to the variable table-------------------

--select top 5 * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable
--select top 5 * from IDI_Sandpit.pop_exp_dev.fact_rollup_year

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
		date_built,
		variable_class,
		has_numeric_value) 
	VALUES   
		(@var_name,
		'Territorial Authority most lived in',
		'Good',
		'notifications',
		'category',
		'person-period',
		'Address notifications have been used to estimate the meshblock at which each person on the spine was living on the 15th of each month, and this is stored 
		as IDI_Sandpit.intermediate.address_mid_month.  These meshblock locations are joined to districts/cities (ie Territorial Authority) and aggregated by time period, 
		and the TA each individual lived longest in during the time period is recorded.  In the event of ties (eg six months each in two TAs, if the period is a year) a TA 
		is chosen at random from the top TAs.  There is no continuous version of this variable, only the categorical value of the TA.',
		'In which District or City did the person live most in a given time period?',
		'IDI_Clean.data.address_notification, IDI_Sandpit.intermediate.address_mid_month, IDI_Sandpit.intermediate.dim_meshblock, 
		IDI_Metadata.clean_read_CLASSIFICATIONS.CEN_REGC13',
		(SELECT CONVERT(date, GETDATE())),
		'Residency, housing and transport',
		'No numeric value');


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value_year(short_name, fk_variable_code, var_val_sequence)
SELECT DISTINCT
	territorial_authority_name			as short_name,
	@var_code							as fk_variable_code,
	CAST(ant_ta_code AS INT)			as var_val_sequence
FROM IDI_Sandpit.intermediate.dim_meshblock;

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;
	-- select * from IDI_Sandpit.pop_exp_dev.dim_explorer_value_year; 
	-- select * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable;
	
----------------add facts to the fact table-------------------------
-- value has to be NOT NULL so we make it zero.  

INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, value, fk_variable_code, fk_value_code)
	SELECT 
			ye_dec_date as fk_date_period_ending, 
			fk_snz_uid, 
			value = 0,
			fk_variable_code = @var_code,
			value_code as fk_value_code
	FROM
		(SELECT
			d.snz_uid                           AS fk_snz_uid,
			ye_dec_date,
			ta_most_lived_in
		FROM IDI_Sandpit.intermediate.ta_lived_in_ye_dec AS d
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON d.snz_uid = p.snz_uid) AS a
	LEFT JOIN #value_codes 
		ON a.ta_most_lived_in = #value_codes.value_category;



