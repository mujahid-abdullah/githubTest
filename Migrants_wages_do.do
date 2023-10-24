
/*
Relationship between migrants share and local wage growth rate
Stata version: 17.0 MP
*/

clear all
set more off

*set your own global directory here:
global data "G:\My Drive\Personal data\Migrants and wage growth"

*Data cleaning and reformatting:
import excel "$data\income.xlsx", sheet("Inkomen_van_personen__persoonsk") firstrow clear
foreach v of varlist B-K {
   local x : variable label `v'
   rename `v' income`x'
}
reshape long income, i(Regions) j(year)
label var income "Income level"
gen log_income=log(income)
label var log_income "Log of income level"
bysort Regions: gen wage_growth=100*((income[_n]-income[_n-1])/income[_n-1]) if _n!=1
label var wage_growth "Wage growth rate"
tempfile income
save `income'


import excel "$data\migrant stock final.xlsx", sheet("Bevolking__leeftijd__migratieac") firstrow clear
foreach v of varlist C-R {
   local x : variable label `v'
   rename `v' mig_stock`x'
}
//Requires installing: type "ssc install sencode"
sencode Migratieachtergrond, replace
keep if Migratieachtergrond!=2
reshape long mig_stock, i(Regions Migratieachtergrond) j(year)
bysort Regions year (Migratieachtergrond): gen total_pop=mig_stock[1]
bysort Regions year (Migratieachtergrond): gen total_migrant=mig_stock[2]
drop Migratieachtergrond mig_stock
duplicates drop Regions year total_pop, force
label var total_pop "Total population"
label var total_migrant "Total migrants"
gen mig_share=total_migrant/total_pop
bysort Regions: gen mig_share_change=100*((mig_share[_n]-mig_share[_n-1])/mig_share[_n-1]) if _n!=1
label var mig_share_change "Change in share of migrants" 
tempfile mig_stock
save `mig_stock'


import excel "$data\Number of Highly educated people.xlsx", sheet("Sheet1") clear
//Requires installing: type "ssc install sxpose"
sxpose, clear destring firstnames 
rename _var1 Regions
rename (_var2 _var3 _var4 _var5 _var6 _var7 _var8 _var9 _var10 _var11 _var12) (educ2020 educ2019 educ2018 educ2017 educ2016 educ2015 educ2014 educ2013 educ2012 educ2011 educ2010)
reshape long educ, i(Regions) j(year)
label var educ "Number of highly educated people"
tempfile educ
save `educ'


import excel "$data\age share final.xlsx", sheet("Regionale_kerncijfers_Nederland") firstrow clear
drop C D E F
rename (Periods totalshareofworkingageperr) (year share_working_age)
label var share_working_age "Share of working age people"
tempfile share_working_age
save `share_working_age'


import excel "$data\Labour participation final.xlsx", sheet("Arbeidsdeelname__regionale_inde") firstrow clear
foreach v of varlist B-I {
   local x : variable label `v'
   rename `v' labor_force`x'
}
reshape long labor_force, i(Regions) j(year)
label var labor_force "Labor force participation"
tempfile labor_force
save `labor_force'


import excel "$data\Share right wing Corop.xlsx", sheet("Inkomen_van_personen__persoonsk") firstrow clear
foreach v of varlist B-K {
   local x : variable label `v'
   rename `v' right_wing`x'
}
reshape long right_wing, i(Regions) j(year)
label var right_wing "Share of right wing voters"
tempfile right_wing
save `right_wing'

import excel "$data\final wages.xlsx", sheet("1") firstrow clear
rename Periods year
drop D E F
tempfile hour_wages
save `hour_wages'

*Merging datasets:
local datasets "`income' `mig_stock' `educ' `share_working_age' `labor_force' `right_wing' `hour_wages'"
forvalues i=1/7 {
	local a: word `i' of `datasets'
	local i = `i' + 1
	merge 1:1 Regions year using `a', gen(merge_`i')
}
drop merge_*
order hourlywage, last

save "$data\final_merge.dta", replace



*Regressions:
sencode Regions, replace
xtset Regions year, yearly

*Equation 1 with time fixed effects
//Requires installing: type "ssc install reghdfe"
//Requires installing: type "ssc install ftools"
reghdfe wage_growth mig_share_change educ share_working_age log_income labor_force, absorb(year) vce(robust)
outreg2 using mig_growth_results.doc, replace addtext(Year FE, YES) label
*Equation 1 with time and region fixed effects
reghdfe wage_growth mig_share_change educ share_working_age log_income labor_force, absorb(Regions year) vce(robust)
outreg2 using mig_growth_results.doc, append addtext(Year FE, YES, Region FE, YES) label

*Equation 2 with time fixed effects
gen mig_share_right_wing=mig_share_change*right_wing
label var mig_share_right_wing "Interaction"
reghdfe wage_growth mig_share_change right_wing mig_share_right_wing educ share_working_age log_income labor_force, absorb(year) vce(robust)
outreg2 using mig_growth_results.doc, append addtext(Year FE, YES) label
*Equation 2 with time and region fixed effects
reghdfe wage_growth mig_share_change right_wing mig_share_right_wing educ share_working_age log_income labor_force, absorb(Regions year) vce(robust)
outreg2 using mig_growth_results.doc, append addtext(Year FE, YES, Region FE, YES) label


