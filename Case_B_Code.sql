DROP TABLE IF EXISTS Col_Trans;
CREATE TABLE Col_Trans (
	`Process_Date`	TEXT,
	`Trade_ID`	TEXT,
	`Transaction_Date`	TEXT,
	`Currency`	TEXT,
	`Customer_ID`	TEXT,
	`Encum_Status`	NUMERIC,
	`Product_Type`	TEXT,
	`PV`	DECIMAL(12,2),
	`PV_CDE`	DECIMAL(12,2),
	`Encum_Mat_Date`	TEXT,
	`Margin_Type`	TEXT,
	`Security_ID`	TEXT,
	`Post_Direction`	TEXT,
	`CSA_ID`	TEXT,
	`Quantity`	NUMERIC
);


DROP TABLE IF EXISTS Customer;
CREATE TABLE Customer (
	`Customer_ID`	TEXT,
	`Customer_Name`	TEXT,
	`Industry`	TEXT,
	`Jurisdiction`	TEXT,
	`CreditRating`	TEXT
);


DROP TABLE IF EXISTS Sec;
CREATE TABLE Sec (
	Security_ID	TEXT,
	Security_ID_2	TEXT,
	Issuer	TEXT,
	Issuer_Credit_Rating	TEXT,
	Industry	TEXT,
	Currency	TEXT,
	Security_Type	TEXT,
	Maturity_date	TEXT,
	Issue_Date	TEXT,
	Coupon	TEXT,
	Price	FLOAT,
	Factor	TEXT,
	MTM_Date	TEXT,
	Fixed_Flag	TEXT,
	primary key (Security_ID)
);

--Step 1:

create table cust2 as
select *,
       case 
            when jurisdiction = 'Canada' and industry = 'Financial' then 'Domestic Banks'
            when jurisdiction = 'Canada' and industry <> 'Financial' then 'Other Domestic'
            else 'Foreign Cpty'
       end as cpty_type
from customer
;

--Step 2:

create table sec2 as
select *,
     case
         when industry = 'Sovereign' and security_type = 'Bond' then 'Level_1_Asset'
         when industry not in ('Sovereign', 'Financial', 'Insurance')
          and issuer_credit_rating like 'A%' 
          and issuer_credit_rating <> 'A-'  then 'Level_2_Asset'
          else 'Level_3_Asset'
     end as asset_class
from sec
;

--Step 3:

create table cust_join as
select  a.*,
        b.cpty_type
from col_trans a
left join cust2 b
on a.customer_id = b.customer_id
where a.product_type = 'Security'
;


--Step 4:

create table sec_join as
select
      a.*,
      case when b.asset_class is null then c.asset_class else b.asset_class end asset_class
from cust_join a
left join sec2 b on a.security_id = b.security_id
left join sec2 c on a.security_id = c.security_id_2
;

create table sec_join_1 as
select
      a.*,
      coalesce(b.asset_class, c.asset_class) asset_class
from cust_join a
left join sec2 b on a.security_id = b.security_id
left join sec2 c on a.security_id = c.security_id_2
;

create table sec_join_2 as
select
      a.*,
      b.asset_class
from cust_join a
left join sec2 b on a.security_id = b.security_id
                 or a.security_id = b.security_id_2

;

create table sec_join_3 as
select 
      a.*,  
      (  
          select b.asset_class from sec2 b
          where  b.security_id   = a.security_id
             or  b.security_id_2 = a.security_id
      ) as asset_class
from cust_join a
;


--Step 5:

create table output as
select 
      cpty_type,
      case when post_direction = 'Deliv to Bank' then 'Collateral Received'
           else 'Collateral Pledged'
      end as direction,
      margin_type,
      sum(case when asset_class = 'Level_1_Asset' then pv_cde else 0 end) as Level_1_Asset,
      sum(case when asset_class = 'Level_2_Asset' then pv_cde else 0 end) as Level_2_Asset,
      sum(case when asset_class = 'Level_3_Asset' then pv_cde else 0 end) as Level_3_Asset
from sec_join 
group by cpty_type, direction, margin_type
order by cpty_type, direction, margin_type
;



--Step 6:

create table struct as
select
      a.cpty_type,
      b.direction,
      c.margin_type
from (select distinct cpty_type from output) a
cross join (select distinct direction from output) b
cross join (select distinct margin_type from output) c
order by a.cpty_type, b.direction, c.margin_type
;


--Step 7:

create table col_trans_report as
select
      a.cpty_type 'Counterparty Type',
      a.direction,
      a.margin_type 'Collateral Type',
      coalesce(b.Level_1_Asset, 0) as Level_1_Asset,
      coalesce(b.Level_2_Asset, 0) as Level_2_Asset,
      coalesce(b.Level_3_Asset, 0) as Level_3_Asset
from struct a
left join output b
on a.cpty_type    = b.cpty_type
and a.direction   = b.direction
and a.margin_type = b.margin_type
;





