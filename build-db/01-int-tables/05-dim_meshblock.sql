/*
This follows on from the script that created the address_mid_month table.

We need a concordance table of the meshblock codes to everything else, as per the address table, rather than
grabbing it from Metadata which has a bad reputation...  By doing it this way we can be sure we are using the
same concordance that was used in creating the address notification table in the first instance.

I originally tried including post code in this concordance too but it fails because meshblock to post code is many to 
many (not very often, but enough).

This can take a surprisingly long time to run.  It's not a big table to write, but it has to look through all the address
table

*/

-- We drop this next table because it refers to dim_meshblock by a foreign key.  So caution.
IF OBJECT_ID('IDI_Sandpit.intermediate.address_mid_month') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.address_mid_month;
GO


IF OBJECT_ID('IDI_Sandpit.intermediate.dim_meshblock') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.dim_meshblock;
GO

CREATE TABLE IDI_Sandpit.intermediate.dim_meshblock
	(ant_meshblock_code VARCHAR(7) NOT NULL PRIMARY KEY,
	 ant_region_code CHAR(2) NOT NULL,
	 region_name VARCHAR(50) NOT NULL,
	 ant_ta_code CHAR(3) NOT NULL,
	 territorial_authority_name VARCHAR(50) NOT NULL);


INSERT IDI_Sandpit.intermediate.dim_meshblock
  SELECT  DISTINCT 
	ant_meshblock_code,
	ant_region_code,
	r.descriptor_text AS region_name,
	ant_ta_code,
	t.descriptor_text AS territorial_authority
  FROM IDI_Clean.data.address_notification AS a
  LEFT JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_REGC13 AS r
  ON a.ant_region_code = r.cat_code
  LEFT JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_TA13 AS t
  ON a.ant_ta_code = t.cat_code
  WHERE ant_meshblock_code IS NOT NULL;

  
CREATE INDEX idx1 ON IDI_Sandpit.intermediate.dim_meshblock(ant_ta_code)  INCLUDE (ant_meshblock_code);
CREATE INDEX idx2 ON IDI_Sandpit.intermediate.dim_meshblock(ant_region_code)  INCLUDE (ant_meshblock_code);




