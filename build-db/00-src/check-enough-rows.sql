/*
This script defines a stored procedure that checks the number of rows in the fact_rollup_year table in the Population Explorer pattern schema
for a given variable. It throws an error if there are less than 1,000 rows of facts for that variable.

Usage is
EXECUTE lib.check_enough_rows @variable_name = 'Income', @schema_name = 'pop_exp_dev';
EXECUTE lib.check_enough_rows @variable_name = 'Colour', @schema_name = 'pop_exp_test';

or, in our general pattern for adding variables to the fact table:
EXECUTE lib.check_enough_rows @variable_name = @var_name, @schema_name = 'pop_exp_dev';

I did have a plan to put a line like at the bottom of each script that adds a variable, but it seems to be painfully slow (10 minutes) on the unindexed table
so am not sure now whether this is a good idea.
*/

USE IDI_Sandpit;

IF OBJECT_ID('IDI_Sandpit.lib.check_enough_rows') IS NOT NULL
	DROP PROCEDURE lib.check_enough_rows;
GO

CREATE PROCEDURE lib.check_enough_rows (
	@variable_name VARCHAR(30),
	@schema_name   VARCHAR(30)
	)
AS
BEGIN
  
  DECLARE @query VARCHAR(8000)
  
  SET @query = '
  DECLARE @nrows INT;
  
  SET @nrows = (SELECT COUNT(1) 
				  FROM IDI_Sandpit.' + @schema_name + '.fact_rollup_year			AS a
				  LEFT JOIN IDI_Sandpit.' + @schema_name + '.dim_explorer_variable	AS b
				  ON a.fk_variable_code = b.variable_code
				  WHERE b.short_name = ''' + @variable_name + ''');
    
	IF @nrows < 1000
	BEGIN
		print ''Only '' + @nrows + '' in the main fact table for' + @variable_name + ''';
		THROW 666666, ''Stopping: implausibly few rows for that variable.'', 1;
	END'
	EXECUTE (@query);

END

