/*
It should be impossible for there to be more than one value in the main fact table per person-period-variable
combination.  In fact, the index that's added to the fact table after all the variables are loaded will
fail if that happens.  This script is to find out which variable is causing the problem

17 November, Peter Ellis
*/


  SELECT 
	DISTINCT(v.short_name) AS variables_with_more_than_one_value_per_person
  FROM
  (SELECT 
	COUNT(1) as n,
	fk_date_period_ending, fk_snz_uid, fk_variable_code
  FROM [IDI_Sandpit].[pop_exp_test].[fact_rollup_year]
  GROUP BY fk_date_period_ending, fk_snz_uid, fk_variable_code
  HAVING COUNT(1) > 1) AS counts
  LEFT JOIN IDI_Sandpit.pop_exp_test.dim_explorer_variable AS v
  ON counts.fk_variable_code = v.variable_code
  
