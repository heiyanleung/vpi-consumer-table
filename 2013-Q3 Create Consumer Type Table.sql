-- Left Join Source Table to VPI Table
CREATE TABLE CONS_2013Q1_CONSUMER_TYPE AS
-- Table 1 (Source File)
--SELECT COUNT(*) FROM (
SELECT DISTINCT
    -- Source_Table.source_str AS Source_String,
    VPI_Table.vpi_ins_code AS Insured_Code,
    VPI_Table.vpi_create AS Create_Date,
    -- Pick all fields from original Simmons table
    Source_Table.*
FROM

    -- Table 1 (Source File)
    --SELECT COUNT(*) FROM 
    (
    SELECT
        UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) AS source_str,
        s.firstname || ' ' || s.lastname AS full_name,
        s.*
        --s.first_name AS First_Name,
        --s.last_name AS Last_Name,
        --S.NEEDSTATE AS Needstate,
        --s.TYPOLOGY AS Typology
    FROM
        ALEUNG.CONS_2013Q1_EXPERIAN_PH s  -- My PH database with Typologies info from Experian
    --WHERE UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) = 'JEFFREYRICH10942W'
    ) Source_Table

LEFT JOIN

    -- Table 2 (VPI)
    (
    SELECT
        REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str,
        eam.enty_code AS vpi_ins_code,
        trunc(eam.enty_created_on) AS vpi_create
    FROM
        vpiren.entity_address_master eam  -- Updated Monthly
    WHERE
        eam.enty_group_code = 'INSURED'
    ) VPI_Table  -- 1,312,561 records

ON (Source_Table.source_str = VPI_Table.vpi_str)

ORDER BY full_name
--)

-- ALTER TABLE CCONS_2013Q3_CONSUMER_TYPE
-- DROP COLUMN SOURCE_STR


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Data Validation
SELECT COUNT(*)
FROM
    aleung.experian_ph_2013q1 s  -- 383,074 records

--------------------
-- Table 1 (Experian)
SELECT
    DISTINCT UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) AS source_str,
    COUNT(*)
FROM
    aleung.experian_ph_2013q1 s
GROUP BY
    UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', ''))
HAVING
    COUNT(*) > 1
ORDER BY
    COUNT(*) DESC  -- 335 records with 2 records



SELECT COUNT(*) FROM
(
SELECT
    DISTINCT UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) AS source_str
FROM
    aleung.experian_ph_2013q1 s
)  -- 382,739 distinct records out of 383,074 records (99.9%)


--------------------
-- Table 2 (VPI)
SELECT
    DISTINCT REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str,
    COUNT(*)
FROM
    vpiren.entity_address_master eam  -- Updated Monthly
WHERE
    eam.enty_group_code = 'INSURED'
GROUP BY
    REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '')
HAVING
    COUNT(*) > 1
ORDER BY
    COUNT(*) DESC  -- 53,271 records with more than 1 records



SELECT COUNT(*) FROM
(
SELECT
    DISTINCT REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str
FROM
    vpiren.entity_address_master eam  -- Updated Monthly
WHERE
    eam.enty_group_code = 'INSURED'
)  -- 1,252,414 distinct records out of 1,312,561 records (95.4%)


--------------------





--------------------
SELECT COUNT(*) FROM

-- Table 1 (Experian)
(
SELECT
    UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) AS source_str,
    s.firstname || ' ' || s.lastname AS full_name,
    s.*
    --s.first_name AS First_Name,
    --s.last_name AS Last_Name,
    --S.NEEDSTATE AS Needstate,
    --s.TYPOLOGY AS Typology
FROM
    aleung.experian_ph_2013Q1 s  -- My PH database with Typologies info from Experian
) Source_Table  -- 383,074 records

LEFT JOIN

-- Table 2 (VPI)
(
SELECT
    REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str,
    eam.enty_code AS vpi_ins_code,
    trunc(eam.enty_created_on) AS vpi_create
FROM
    vpiren.entity_address_master eam JOIN
                                            (
                                            SELECT
                                                DISTINCT i.insured_code,
                                                y.Pol_Cnt
                                            FROM
                                                dwdaily.dw_dim_insured i LEFT JOIN (SELECT
                                                                                        DISTINCT pp.insured_dwid,
                                                                                        COUNT(pp.insured_dwid) AS Pol_Cnt
                                                                                    FROM
                                                                                        dwdaily.dw_policy_pet pp
                                                                                    GROUP BY
                                                                                        pp.insured_dwid ) y
                                                                                    ON (i.insured_dwid = y.insured_dwid)
                                            WHERE
                                                y.Pol_Cnt IS NOT NULL ) x
                                            ON (eam.enty_code = x.insured_code)

WHERE
    eam.enty_group_code = 'INSURED'
) VPI_Table  -- 1,288,831 records

ON (Source_Table.source_str = VPI_Table.vpi_str)  -- 397,006 records


--------------------
SELECT
    DISTINCT Source_Table.source_str,
    COUNT(*)
FROM

    -- Table 1 (Experian)
    (
    SELECT
        UPPER(REPLACE(s.firstname, ' ', '') || REPLACE(s.lastname, ' ', '') || REPLACE(SUBSTR(s.addr,1,8), ' ', '')) AS source_str,
        s.firstname || ' ' || s.lastname AS full_name,
        s.*
        --s.first_name AS First_Name,
        --s.last_name AS Last_Name,
        --S.NEEDSTATE AS Needstate,
        --s.TYPOLOGY AS Typology
    FROM
        aleung.experian_ph_2013Q1 s  -- My PH database with Typologies info from Experian
    ) Source_Table  -- 383,074 records

    LEFT JOIN

    -- Table 2 (VPI)
    (
    SELECT
        REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str,
        eam.enty_code AS vpi_ins_code,
        trunc(eam.enty_created_on) AS vpi_create
    FROM
        vpiren.entity_address_master eam  -- Updated Monthly
    WHERE
        eam.enty_group_code = 'INSURED'
    ) VPI_Table  -- 1,312,561 records

    ON (Source_Table.source_str = VPI_Table.vpi_str)  -- 404,892 records

GROUP BY
    Source_Table.source_str
HAVING
    COUNT(*) > 1
ORDER BY
    COUNT(*) DESC


--------------------
SELECT COUNT(*) FROM (
SELECT
    REPLACE(eam.enty_first_name, ' ', '') || REPLACE(eam.enty_last_name, ' ', '') || REPLACE(SUBSTR(eam.enty_address1,1,8), ' ', '') AS vpi_str,
    eam.enty_code AS vpi_ins_code,
    trunc(eam.enty_created_on) AS vpi_create,
    x.Pol_Cnt
FROM
    vpiren.entity_address_master eam JOIN
                                            (
                                            SELECT
                                                DISTINCT i.insured_code,
                                                y.Pol_Cnt
                                            FROM
                                                dwdaily.dw_dim_insured i LEFT JOIN (SELECT
                                                                                        DISTINCT pp.insured_dwid,
                                                                                        COUNT(pp.insured_dwid) AS Pol_Cnt
                                                                                    FROM
                                                                                        dwdaily.dw_policy_pet pp
                                                                                    GROUP BY
                                                                                        pp.insured_dwid ) y
                                                                                    ON (i.insured_dwid = y.insured_dwid)
                                            WHERE
                                                y.Pol_Cnt IS NOT NULL ) x
                                            ON (eam.enty_code = x.insured_code)

WHERE
    eam.enty_group_code = 'INSURED'
) VPI_Table  -- 1,312,561 records before joining to Policy Pet
             -- 1,288,831 records after joining to Policy Pet


SELECT COUNT(*)
FROM
    vpiren.entity_address_master eam
WHERE
    eam.enty_group_code = 'INSURED'    -- 1,312,561 records


SELECT COUNT(*)
FROM
    dwdaily.dw_dim_insured i    -- 1,312,561 records


SELECT *
FROM
    dwdaily.dw_policy_pet pp    -- 1,847,506 records



SELECT COUNT(*) FROM
(
SELECT
    i.insured_dwid AS I_Insured,
    pp.insured_dwid AS PP_Insured
FROM
    dwdaily.dw_dim_insured i LEFT JOIN dwdaily.dw_policy_pet pp ON (i.insured_dwid = pp.insured_dwid)
) Insured

WHERE
    Insured.PP_Insured IS NULL  -- 23,730 Insured Codes with No Policies attached



SELECT COUNT(*) FROM (
SELECT
    DISTINCT i.insured_dwid,
    y.Pol_Cnt
FROM
    dwdaily.dw_dim_insured i LEFT JOIN (SELECT
                                            DISTINCT pp.insured_dwid,
                                            COUNT(pp.insured_dwid) AS Pol_Cnt
                                        FROM
                                            dwdaily.dw_policy_pet pp
                                        GROUP BY
                                            pp.insured_dwid ) y
                                        ON (i.insured_dwid = y.insured_dwid)
WHERE
    y.Pol_Cnt > 1
ORDER BY
    y.Pol_Cnt DESC
)  -- 1,312,561
   -- 1,288,831




    
