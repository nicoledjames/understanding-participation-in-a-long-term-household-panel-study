
/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			02_data_analysis_3.do
Task: 				MN regression (DV - reason for NR)
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\02_data_analysis_3.log", replace t 

/*====================================================================
                        1: Reasons for NR  
====================================================================*/
qui {
	use "$datasets\final_data_ue.dta", clear 
	foreach v of glo revlist2 { 
		recode ivfio`v' /// 54
			(-9/-1=.) ///
			(1=1) ///
			(10 30 50 81 =2) ///
			(32 53 82 =3) /// 
			(2/9 11/12 14/18 31 51/52 54/60 80 83/84 98/99=4) ///
			, gen(res`v')		
	}
	forval i = 2/$wn1c { 
		loc h = `i'-1
		replace res`i'=2 if mi(res`i') & res`h'==2 
		replace res`i'=3 if mi(res`i') & inlist(res`h',1,3)
		replace res`i'=4 if mi(res`i') & res`h'==4
	}
	n fre res*
	g res = res26
	la var res "reason for dropping out"
	la def res 1 "present" 2 "refusal" 3 "non-contact" 4 "other"
	la val res res

	g elig${wn1c}_b = elig${wn1c}
	replace elig${wn1c}_b = elig_ue_${wn1c} if elig${wn1c}==3 
	n fre elig${wn1c}_b
	assert inlist(elig${wn1c}_b,1,2)
	n ta elig${wn1c}_b loyal [iweight=weight],  col // number of people eligible to participate by final wave 
	n ta elig${wn1c}_b loyal [iweight=weight],  row
	save "$wdata\reasfornr.dta", replace

	use "$wdata\reasfornr.dta", clear
	n mlogit res ib7.class ib1.agegrp7 ethnmin ib5.genhealth ///
		c.npens_dv ib7.class##ib1.agegrp7 [iweight=weight] ///
		if class!=1 & res!=1, b(2) vce(robust)
	
	/* Export Regression Results (attaching labels etc.) */ 
	regsave using results, table(reg1, format(%5.2f) parentheses(stderr) ///
			asterisk(10 5 1)) replace
		
	use results, clear
	drop if var=="N"
	g n = _n
	g reason = substr(var,1,strpos(var,":")-1)
	g var2 = substr(var,strpos(var,":")+1,.), after(var)
	g typ = "coef" if strmatch(var,"*_coef") 
	replace typ = "stderr" if strmatch(var,"*_stderr")
	assert inlist(typ,"coef","stderr")
	replace var2 = substr(var,1,length(var)-(length(typ)+1)) // remove suffix (incl. underscore)
	replace var2 = substr(var2,strpos(var2,":")+1,.)
	save results2, replace

	use "$wdata\reasfornr.dta", clear
	/* Labelling Code for Regression Model */ 
	macro drop _vldv* _varl* _vall* varl_*
	loc labcov ib7.class ib1.agegrp7 ethnmin ib5.genhealth c.npens_dv 
	foreach vl of loc labcov  { 
	    *n di as txt "`vl'"
	    macro drop _v 
	    if strmatch("`vl'","*.*") ///
			loc v = substr("`vl'",strpos("`vl'",".")+1,.)
		else loc v "`vl'"
		distinct `v'
		loc vldv_`v' `r(ndistinct)'
		
		if (`vldv_`v''==2 | `vldv_`v''>=15) | strmatch("`vl'","c.*") ///
			loc varl `varl' `v' // binary categorical or continuous 
		else { 
			cou if `v'==0 
			if `r(N)'==0 loc valla `valla' `v' // non-binary categorical, starts at 1
			else loc vallb `vallb' `v' // non-binary categorical, starts at 0
		} 	
	}
	// debug
	foreach x in varl valla vallb { 
		di as txt _n "`x': ``x''"
	}
	
	foreach v of loc varl { 
		glo varl_`v': var label `v' 
		n di "`v': ${varl_`v'}"
	}
	
	mata : st_global("varl2", invtokens(st_dir("global", "macro", "varl_*")'))
	di as txt _n "${varl2}" // store var labels in global list 
	
	foreach t in a b { 
		foreach v of loc vall`t' { 
			levelsof `v', loc(`v'levs)
			glo vls_vl_`v': var label `v'
			loc `v'lset: value label `v' 
			foreach l of loc `v'levs { 
				glo vall`t'_`v'_`l' : label ``v'lset' `l'
				n di "`v' `l': ${vall`t'_`v'_`l'}"
			}
		}
		mata : st_global("vall2`t'", invtokens(st_dir("global", "macro", "vall`t'_*")'))
		n di as txt _n "${vall2`t'}" // store var & val labels in global lists
	}
	/* End of Labelling Code for Regression Model */  


	use results2, clear
	foreach i in refusal non_contact other { 
		foreach typ in coef stderr { 
			preserve 
				keep if reason=="`i'" & typ=="`typ'"
				ren reg1 `typ'`i'
				keeporder var2 `typ'`i' n
				cou
				g n2 = _n 
				tempfile temp`i'`typ'
				save `temp`i'`typ''
			restore
		}
	}
		
	clear 
	g var2 = ""
	g n2 = 0
	foreach i in refusal non_contact other { 
		foreach typ in coef stderr { 
			if "`i'"=="refusal" loc keepvars `typ'`i' n
			else loc keepvars `typ'`i' n
			merge 1:1 var2 n2 using `temp`i'`typ'', nogen keepus(`keepvars')
		}
	}
	sort n
	order n n2, last
	
	/* Exports table to a more readable format and in xlsx */
	n export excel "$output\reasonfornonresp.xlsx", replace first(var) nolabel 
}	

/*====================================================================
                        Program Close
====================================================================*/
cap log close 
ex