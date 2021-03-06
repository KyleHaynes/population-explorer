/*
Sets up empty shells of the variable and value dimension tables in the twelve month reporting
star schema

Peter Ellis September 2017, then modified numerous times since then (usually adding attributes)
*/

---------------------clean up-------------------
-- Drop the any previous version of the tables we are making if necessary
-- They have to be dropped in the order below because of the various foreign key constraints.
-- This sections is really on here for development, as the preceding "clean-up" script will normally have done this
-- for you if doing a full sequential build.
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.fact_rollup_year', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year;
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.fact_rollup_qtr', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr;
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_value', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value;
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr;
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_variable', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_variable;
GO
----------------dimension tables----------------------
-- note the use of NVARCHAR(4000) rather than VARCHAR(4000) for measured_variable_description, because of https://github.com/zozlak/RODBCext/issues/6
-- Also note use of NVARCHAR not VARCHAR - this is so we can have Unicode encoding eg for Māori.  Alos, 4000 is the maximum characters
-- for NVVARCHAR (no option of VARCHAR(8000) or VARCHAR(MAX)) 
CREATE TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_variable (
	-- auto incrementing:
	variable_code						INT NOT NULL IDENTITY PRIMARY KEY, 
	short_name							NVARCHAR(25) NOT NULL,
	long_name							NVARCHAR(100) NOT NULL,
	quality								NVARCHAR(25),
	origin								NVARCHAR(40),
	var_type							NVARCHAR(20) ,
	grain								NVARCHAR(20) ,
	measured_variable_description		NVARCHAR(4000) NOT NULL,
	target_variable_description			NVARCHAR(4000) NOT NULL,
	origin_tables						VARCHAR(2000) NOT NULL,
	units								NVARCHAR(30),
	earliest_data						DATE,
	date_built							DATE,
	data_linked_to_spine				FLOAT,
	snz_uid_linked_to_spine				FLOAT,
	variable_class						NVARCHAR(100) NOT NULL,
	number_observations					INT,
	observations_in_front_end			INT,
	status								VARCHAR(20),
	use_in_front_end					VARCHAR(10),
	loaded_into_wide_table              VARCHAR(15),
	has_numeric_value                   VARCHAR(20),
	spine_to_sample_ratio				NUMERIC(8, 2),
	data_type							VARCHAR(20)
	);
	
CREATE NONCLUSTERED INDEX nc_var_name ON IDI_Sandpit.pop_exp_dev.dim_explorer_variable(short_name);
CREATE NONCLUSTERED INDEX nc_var_type ON IDI_Sandpit.pop_exp_dev.dim_explorer_variable(var_type);
ALTER TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_variable ADD CONSTRAINT unq_var_sn UNIQUE(short_name)
ALTER TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_variable ADD CONSTRAINT unq_var_ln UNIQUE(long_name)


-- Annual version of value dimension:
CREATE TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_year (
	-- auto incrementing:
	value_code			INT NOT NULL IDENTITY PRIMARY KEY, 
	short_name			NVARCHAR(100) NOT NULL,
	fk_variable_code	INT NOT NULL,
	var_val_sequence	INT,
	full_description	NVARCHAR(200)
	);
	
CREATE NONCLUSTERED INDEX nc_val_name_y ON IDI_Sandpit.pop_exp_dev.dim_explorer_value_year(short_name);
CREATE NONCLUSTERED INDEX nc_var_cod_y ON IDI_Sandpit.pop_exp_dev.dim_explorer_value_year(fk_variable_code);

-- foreign key connecting the value and variable tables together
ALTER TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
	ADD CONSTRAINT fk_value_var_yr
	FOREIGN KEY (fk_variable_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_variable(variable_code);

-- Quarterly version of value dimension 
-- (because eg income will have a different set of bands for quarterly compared to annual):
CREATE TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr (
	value_code			INT NOT NULL IDENTITY PRIMARY KEY, 
	short_name			NVARCHAR(100) NOT NULL,
	fk_variable_code	INT NOT NULL,
	var_val_sequence	INT,
	full_description	NVARCHAR(200)
	);
	
CREATE NONCLUSTERED INDEX nc_val_name_q ON IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr(short_name);
CREATE NONCLUSTERED INDEX nc_var_cod_q ON IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr(fk_variable_code);

-- foreign key connecting the value and variable tables together.  Quarterly and annual versions share the 
-- same variable dimension
ALTER TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
	ADD CONSTRAINT fk_value_var_qtr
	FOREIGN KEY (fk_variable_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_variable(variable_code);


------------some starter variable and value dimensions-------------------

INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_variable (short_name, long_name, origin_tables, 
					measured_variable_description, target_variable_description, 
					variable_class, use_in_front_end, status)
	VALUES	('Generic', 'Applies to all variables', 'None', 
	'This is a place-holder variable for "values" such as "No data" that are shared across all variables.', 'None', 
	'Generic', 'Don''t use', 'Not applicable');

DECLARE @var_code INT;	 
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'Generic');

-- Usually when there is "No data" it means "zero" and we want it to be first in the value sequence, so it gets
-- a negative value for var_val_sequence:
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value_year (short_name, fk_variable_code, var_val_sequence, full_description)
	VALUES
	('Missing', @var_code, 1000000, 'Data is missing'),
	('No data', @var_code, -1, 'No data observed');

-----------Fact tables--------------------

CREATE TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year (
	-- auto incrementing:
	rollup_year_var_uid		BIGINT		NOT NULL IDENTITY, --PRIMARY KEY NONCLUSTERED, 
	fk_date_period_ending	DATE		NOT NULL,
	fk_snz_uid				INT			NOT NULL,
	fk_variable_code		INT			NOT NULL,
	value					INT			NOT NULL,
	fk_value_code			INT			NOT NULL)
	--ON variable_code_range_ps(fk_variable_code);


CREATE TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr (
	-- auto incrementing:
	rollup_qtr_var_uid		BIGINT		NOT NULL IDENTITY, -- PRIMARY KEY NONCLUSTERED, 
	fk_date_period_ending	DATE		NOT NULL,
	fk_snz_uid				INT			NOT NULL,
	fk_variable_code		INT			NOT NULL,
	value					INT			NOT NULL,
	fk_value_code			INT			NOT NULL)
	--ON variable_code_range_ps(fk_variable_code);


-- We don't make any indexes for the main fact table yet because it will grow to have billions
-- of rows that we will be adding one chunk at a time, and it will slow all the INSERTs down
-- massively if it has to index it all the time.  So we save indexing this particular table
-- for the very last step.
