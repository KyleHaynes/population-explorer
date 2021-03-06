-- counts observations by variable
-- Note that this has now been built more formally into the tests
-- Peter Ellis October 2017


  
  select count(1) as observations, fk_variable_code, variable_code, short_name
  FROM [IDI_Sandpit].[pop_exp].[fact_rollup_year] a
  RIGHT JOIN IDI_Sandpit.pop_exp.dim_explorer_variable b
  on a.fk_variable_code = b.variable_code
  WHERE grain = 'person-period'
  group by fk_variable_code, short_name, variable_code
  order by variable_code DESC;
  
  select * from IDI_Sandpit.pop_exp.dim_explorer_variable 
  --placement_event was 37 at 9:30 am
  select * from IDI_Sandpit.pop_exp.fact_rollup_year where fk_variable_code IS NULL
  
select count(1) as observations, fk_variable_code, short_name
  FROM [IDI_Sandpit].[pop_exp_dev].[fact_rollup_year] a
  RIGHT JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable b
  on a.fk_variable_code = b.variable_code
  WHERE grain = 'person-period'
  group by fk_variable_code, short_name
  
  select count(1) as observations, fk_variable_code, short_name
  FROM [IDI_Sandpit].[pop_exp_bak].[fact_rollup_year] a
  RIGHT JOIN IDI_Sandpit.pop_exp_bak.dim_explorer_variable b
  on a.fk_variable_code = b.variable_code
  WHERE grain = 'person-period'
  group by fk_variable_code, short_name

  select top 50 * from IDI_Sandpit.pop_exp_bak.vw_ye_mar_wide