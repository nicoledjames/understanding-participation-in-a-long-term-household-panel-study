
/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			02_data_analysis_2.do
Task: 				MN regression (DV - class assignment)
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\02_data_analysis_2.log", replace t 

/*====================================================================
                        1: Summary Statistics 
====================================================================*/
qui {
	cls
	foreach x in 1 ue {
		n di as res _n(4) _dup(90) "-"
		n di as res "final_data_`x'" _n
		use "$datasets\final_data_`x'.dta",clear
		n cou
		
		summ class 
		loc min = `r(min)'
		loc max = `r(max)'
		
		foreach v in class female ethnmin {
			if "`v'"=="class" {
				loc by ""
				loc stats b pct 
			}
			else {
				loc by "class"
				loc stats rowpct 
			}
			n estpost tab `by' `v' [iweight=weight]
			foreach s of loc stats {
				matrix `s'_`v' = e(`s')'
				matrix list `s'_`v'
			}
		}
		/* iweight not allowed (aweight produces same result) */
		n estpost tabstat age [aweight=weight], by(class) 
		matrix mean_age = e(mean)'
		matrix list mean_age
		
		preserve 
			clear 
			loc s = `min'+`max'+1 
			loc e = `s'+`max'
			loc tot = `max'+2
			svmat rowpct_female 
			svmat rowpct_ethnmin
			keep in `s'/`e'
			foreach y in b_class pct_class mean_age {
				svmat `y'
			}
			g class = _n
			ren *1 *
			order class b_class pct_class rowpct_female mean_age rowpct_ethnmin 
			n li *, noobs nol clean
			
			putexcel set "$output\summary_stats_`x'.xlsx", replace sh("`x'", replace)
			putexcel A1=("Class") B1=("Class Size") C1=("% of Sample") ///
				D1=("% of Female Respondents") E1=("Mean Age") ///
				F1=("% of Ethnic Minority Respondents")
			export excel using "$output\summary_stats_`x'.xlsx", ///
				sh("`x'", modify) cell(A2)
			putexcel A`tot'=("Total")
		restore 
		n di as res _n _dup(90) "-"
	}
	
}

/*====================================================================
                        2.1: Labelling Code for Regression Model
====================================================================*/
qui {
	use "$datasets\final_data_1.dta", clear 
	/* Labelling Code for Regression Model */ 
	macro drop _vldv* _varl* _vall* varl_*
	foreach vl of glo cov  { 
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
}

/*====================================================================
                        2.2: MN Regression
====================================================================*/
qui {
	/* Multinomial Regression */
	foreach x in 1 ue {
		cls
		use "$datasets\final_data_`x'.dta",clear
		summ class 
		loc cln = `r(max)'
		sort pidp
	 
		/* MN Regression */
		n mlogit class ${cov} [iweight=weight], b(1) vce(robust)
		loc stres_`x' N chi2 p r2_p // stored results 
		loc stres2_`x': list sizeof stres_`x' // number of stored results options
		
		foreach y of loc stres_`x' { 
			loc mnr_`x'_`y' "`e(`y')'"
		}
		
		/* Export Regression Results (attaching labels etc.) */ 
		regsave using results, table(reg1, format(%5.2f) parentheses(stderr) ///
			asterisk(10 5 1)) replace
		
		use results, clear
		drop if var=="N"
		g n = _n
		g class = substr(var,1,1)
		destring class, replace
		assert inrange(class,1,`cln') 
		g prefix = strpos(var,".")
		fre prefix
		
		replace var = substr(var,prefix+1,.) if prefix>0 // remove prefix 
		replace var = substr(var,3,.) if prefix==0 // remove prefix
		g typ = "coef" if strmatch(var,"*_coef") 
		replace typ = "stderr" if strmatch(var,"*_stderr")
		assert inlist(typ,"coef","stderr")
		replace var = substr(var,1,length(var)-(length(typ)+1)) // remove suffix (incl. underscore)
		forval i = 1/`cln' { 
			foreach typ in coef stderr { 
				preserve 
					keep if class==`i' & typ=="`typ'"
					ren reg1 `typ'`i'
					keeporder var `typ'`i' n
					cou
					g n2 = _n 
					tempfile temp`i'`typ'
					save `temp`i'`typ''
				restore
			}
		}
		
		clear 
		g var = ""
		g n2 = 0
		forval i = 1/`cln' { 
			foreach typ in coef stderr { 
				if `i'==1 loc keepvars `typ'`i' n
				else loc keepvars `typ'`i' n
				merge 1:1 var n2 using `temp`i'`typ'', nogen keepus(`keepvars')
			}
		}
		sort n
		order n n2, last
			
		bys var(n2): gen n3 = cond(_N==1,1,_n)
		sort n2 n3
		g varl="", a(var)
		foreach z1 of glo varl2 { 
			loc z1b = substr("`z1'",6,.)
			replace varl = "${`z1'}" if var=="`z1b'"
		}
		foreach t in a b { 
			foreach z1 of glo vall2`t' { 
				loc z1b= substr("`z1'",7,strrpos("`z1''","_")-7)
				loc z1c = substr("`z1'",strrpos("`z1'","_")+1,.)
	
				if "`t'"=="a" replace varl = "${`z1'}" if var=="`z1b'" & n3==`z1c'
				else if "`t'"=="b" replace varl = "${`z1'}" ///
					if var=="`z1b'" & & n3==`z1c'+1
			}
		}
		
		forval i = 2/`cln' { 
			destring coef`i', gen(tmp_coef`i') force
			replace tmp_coef`i'=100 if mi(tmp_coef`i') // make sure coefficients with some 0s aren't listed as ref categories
			
		}
		
		egen x = rowtotal(tmp_coef*)
		g ref = (x==0)
		
		bys var: egen y = total(ref==1)
		order y, after(ref)

		ds, has(type string)
		loc svs `r(varlist)'
		foreach sv of loc svs {
			replace `sv' = char(9) + `sv'  if (y==1 & ref==0)
		}

		sort n2 
		
		foreach t in a b { 
			foreach z1 of loc vall`t' { 
				replace varl = "${vls_vl_`z1'} " + char(9) + ///
					"(ref: " + varl + ")" if var=="`z1'" & ref==1
			}
		}
		
		drop tmp_coef* x n y
		
		replace var = ustrtrim(var)
		g n4 = 0 
		m : st_local("a", invtokens(st_sdata(., "var")'))
		loc a : list uniq a
		di "`a'"
		loc b = 0 
		foreach a1 of loc a { 	
			loc a2 = `a2'+1 
			replace n4 = `a2' if var=="`a1'" 
		}
		
		g n5 = n3 
		replace n5 = 0 if ref==1
		
		sort n4 n5
	
		/* add stored results to the bottom of the table */ 
		d 
		loc obs `r(N)' // number of rows in table 
		replace varl =  "Constant" if mi(varl) in `obs'
		insobs `stres2_`x'' // add extra rows for stored results 
		forval i = 1/`stres2_`x'' { // loop through stored results
			loc j: word `i' of `stres_`x''
			loc k = `obs' + `i'
			replace varl = "`j': `mnr_`x'_`j''" if mi(varl) in `k' // add stored results 
		}
		keep varl coef* stderr*

		/* */ 
		foreach z1 in coef stderr { 
			forval i = 1/`cln' { 
				replace `z1'`i' = ""  if strmatch(varl,"*(ref:*")
			}
		}
		
		/* Exports table to a more readable format and in xlsx */
		n export excel using "$output/mnr_`x'.xlsx", first(var) nolabel sh("`x'", modify) 
	}
}

/*====================================================================
                        Program Close
====================================================================*/
cap log close
