/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			01_data_management_3.do 
Task: 				Generate eligibility weights
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\02_data_management_3.log", replace t 

/*====================================================================
                        1: Population Survival Rates
====================================================================*/
qui {
	/* Get population estimates for each country, year and gender */
	foreach g in m f {
		loc G = strupper("`g'")
		if "`g'"=="m" loc gen "Males"
		else if "`g'"=="f" loc gen "Females"
		forval yr = 2016/2019 {
			n di as res "`yr'"
			if `yr'==2019 loc tn "`gen'"
			else loc tn "`G'"
			
			loc yr 2019 
			loc tn "Males"
			n di "`tn'"
			import excel "$input\ukmidyearestimates`yr'.xls", clear sh("MYE2 - `tn'")
			keep if inlist(B,"Name","ENGLAND","SCOTLAND","WALES")
			nrow 1
			if `yr'==2016 ren C pop999
			else ren D pop999
			misstable patterns * // remove blank columns 
			cap drop `r(vars)'
			ren _*_ _*
			ren _* pop*
			ren *, lower 
			destring pop*, replace
			keep name  pop*
			reshape long pop, i(name) j(age)
			replace name = strlower(name)
			tostring age, gen(ages)
			replace ages="All Ages" if age==999
			mvdecode age, mv(999)
			ren pop mid_`yr'
			keep name age ages mid_`yr'
			save "$wdata\mid_`yr'_`g'", replace
		}
	}
	
	foreach country in England Scotland Wales {
		loc cou = strlower(substr("`country'",1,3))
		n di as res "`country' (`cou')"
		if "`country'"=="England" loc syr 1971 
		else if "`country'"=="Scotland" loc syr 1961 
		else if "`country'"=="Wales" loc syr 1981 
		
		import excel "$input\ukpopulationestimates1838-2015.xls", clear ///
			sh("`country' SYOA `syr'-2015")
		g n = _n, b(A)
		levelsof n if A=="ALL MALES (units)", loc(m1)
		levelsof n if A=="ALL FEMALES (units)", loc(f1)
		loc m2 = `f1'-1
		cou 
		loc f2 = `r(N)'
		foreach g in m f { 
			n di as res "`g'"
			preserve 
				keep if inrange(n,``g'1',``g'2')
				misstable patterns * // remove blank columns 
				cap drop `r(vars)'
				drop if n==``g'1' | mi(A)
	
				ds n, not 
				loc `g'3 = ``g'1'+1 
				foreach v of varlist `r(varlist)' {
					
					levelsof `v' if n==``g'3', loc(vn) clean
					loc vn = subinstr("`vn'","-","_",.)
					ren `v' `vn'
				}
				drop if n==(``g'3')
				ren *, lower
				ren age ages 
				destring ages,gen(age) force
				replace age = 85 if ages=="85 / 85+"
				replace ages = "85" if ages=="85 / 85+"
				keep name age ages mid_* 
				isvar mid_196? mid_197? mid_198?
				cap drop `r(varlist)'
				drop if mi(name)
				replace name=strlower(name)
				forval yr = 2016/2019 {
					merge 1:1 name age ages using "$wdata\mid_`yr'_`g'", keep(1 3) 
					assert _merge==3 
					drop _merge
				}
				n save "$wdata\pop_est_`country'_`g'", replace
			restore
		}
		
		use "$wdata\pop_est_`country'_m", clear 
		ren mid_* male_`cou'_* 
		merge 1:1 name age ages using "$wdata\pop_est_`country'_f", nogen 
		ren mid_* female_`cou'_*
		save "$wdata\pop_est_`country'", replace
	}
	
	// Dates for Excel sheet titles (BHPS and UKHLS separately)
	forval bi = 1991(3)2008 { 
	    loc b1a `b1a' `bi'
		loc bj = `bi'+2 
		loc b2a `b2a' `bj'
	}
	n di as txt _n "`b1a'" _n "`b2a'"
	loc bc: list sizeof b1a
	
	forval ui = 2010/2017 { 
	    loc u1a `u1a' `ui'
		loc uj = `ui'+2 
		loc u2a `u2a' `uj'
	}
	n di as txt _n "`u1a'" _n "`u2a'"
	loc uc: list sizeof u1a
	
	foreach sv in b u { 
		if "`sv'"=="b" loc sdt = 1990 
		if "`sv'"=="u" loc sdt = 2008
	    forval i = 1/``sv'c' {
			loc `sv'1b: word `i' of ``sv'1a'
			loc `sv'2b: word `i' of ``sv'2a'
			loc `sv'3 ``sv'3' ``sv'1b'-``sv'2b'
		}
		n di as txt _n "``sv'3'"
		
		/* name ages age mid_1990 mid_1991 */
		foreach country in England Scotland Wales {
			loc cou = strlower(substr("`country'",1,3))
			n di as res "`country' (`cou')"
			loc fn0 = 0 
			foreach y of loc `sv'3 {
				loc fn0 = `fn0'+1 
				import excel "$input\nationallifetables3year`cou'", clear sh("`y'")
				loc fy1 = substr("`y'",1,4) // start year
				loc fn1 = `fy1'-`sdt' // start wave
				loc fy2= substr("`y'",6,9) // end year
				loc fn2 = `fy2'-`sdt' // end wave 
				n di "`fn1'-`fn2'"
				drop in 1/5 // drop titles
				ren A age 
				if "`sv'"=="b" {
					macro drop _fn0a 
					forval fn3 = `fn1'/`fn2' { 
						loc fn0a `fn0a' `fn3'
						clonevar qx_male_`cou'_`fn3'=C
						clonevar qx_female_`cou'_`fn3'=I
					}
				}
				if "`sv'"=="u" {
					loc fn3 = `fn1'+17
					ren C qx_male_`cou'_`fn3'
					ren I qx_female_`cou'_`fn3'
				}
			
				drop in 1/2 // drop table titles 
				keep age qx* 
				destring age, replace 
			
				d,si
				missings dropobs *, force // drop blank rows 
				macro drop _fy0a _fy0b
				forval i = `fy1'/`fy2' { 
					loc fy0a `fy0a' `i'
					loc fy0b `fy0b' male_`cou'_`i' female_`cou'_`i'
				}
				n d
				merge 1:1 age using "$wdata\pop_est_`country'", /// 
					keepus(ages `fy0b') nogen
				order age ages, first
				drop if !mi(age) & mi(ages) // pop ests top coded at 90
				destring *male*, replace
				
				if "`sv'"=="b" {
					macro drop _x1 _x2 
					loc x1 = 0 
					forval i = `fy1'/`fy2' { 
						loc x1 = `x1'+1 
						loc x2: word `x1' of `fn0a'
						ren *male_`cou'_`i' tot_*male_`cou'_`x2'
					}
				}
				else if "`sv'"=="u" {
					foreach gender in male female { 
						egen tot_`gender'_`cou'_`fn3' = rowtotal(`gender'_`cou'_*)
						replace tot_`gender'_`cou'_`fn3' = tot_`gender'_`cou'_`fn3'/3
						
					}
					keep age ages *_`fn3'
				}
				n d 
				tempfile `sv'_`cou'_`fn0'
				save ``sv'_`cou'_`fn0''
				
			}

		}
		forval i = 1/`fn0' {
			use ``sv'_eng_`i'', clear
			merge 1:1 age ages using ``sv'_sco_`i'', nogen 
			merge 1:1 age ages using ``sv'_wal_`i'', nogen 
			
			order age ages qx* tot*
			foreach gender in male female { 
				isvar qx_`gender'_eng_* 
				loc vars `r(varlist)'
				foreach v of loc vars { 
					loc x = substr("`v'",strrpos("`v'","_")+1,.)
					egen tot_`gender'_gb_`x' = ///
						rowtotal(tot_`gender'_eng_`x' tot_`gender'_sco_`x' tot_`gender'_wal_`x')
					g qx_`gender'_gb_`x' = 0 
					la var qx_`gender'_gb_`x' "Mortality rate between age x and (x+1) for `gender's in w`x'"
					foreach cou in eng sco wal { 
						g px_`gender'_`cou'_`x' = tot_`gender'_`cou'_`x'/tot_`gender'_gb_`x'
						la var px_`gender'_`cou'_`x' "Proportion of GB persons of age X living in `cou'"
						g rate_`gender'_`cou'_`x' = qx_`gender'_`cou'_`x'*px_`gender'_`cou'_`x'
						replace qx_`gender'_gb_`x' = qx_`gender'_gb_`x' + rate_`gender'_`cou'_`x' 
					}
				}
				
			}
			keep age ages qx_*male_gb_*
			tempfile `i'
			save ``i''
		}
	
		use `1', clear 
		forval i = 2/`fn0' { 
			merge 1:1 age ages using ``i'', nogen 
		}
		tempfile `sv'1 
		save ``sv'1'
	}
	use `b1', clear 
	merge 1:1 age ages using `u1', nogen 
	order age ages qx_female* qx_male*
	keep if inrange(age,16,90) 
	n d
	preserve 
		use "$datasets\bhps_data2", clear 
		n summ age
		loc mx_age `r(max)'
	restore 
	if `mx_age'>90 { 
		loc exp = (`mx_age'-90)+1 
		cou 
		n di "`r(N)'"
		loc a = `r(N)'+1 
		loc b = (`r(N)'+`exp')-1
		expand `exp' if age==90
		loc c = 0 
		n di as txt "`a'/`b'"
		forval d = `a'/`b' {
			loc c = `c'+1 
			replace age = (90+`c') if age==90 in `d'
		}
	}
	drop qx_*_gb_1
	save "$wdata\qx_gb", replace
}

/*====================================================================
                        2: Qx_gb 
====================================================================*/
qui {
	use "$datasets\bhps_data2", clear 
	keep pidp *elig* age female
	keep if eligstat==3
	g exp = $wn1c - wtranselig + 2
	expand exp 
	bys pidp: g n = _n
	order n, after(pidp)
	sort wtranselig pidp n

	g eli2inel = .
	summ exp
	loc min `r(min)'
	loc max `r(max)'
	forval a = `min'/`max' {
		loc wt = ($wn1c + 2) - `a'
		di as res "`a': `wt'"
		loc b = 0 
		forval c = `wt'/$wn1c { 
			loc b = `b'+1 
			di as txt "elig`c' - exp==`a' - n==`b'"
			replace elig`c'=2 if exp==`a' & n==`b' & elig`c'==3
			replace eli2inel = `c' if exp==`a' & n==`b' & elig`c'==2 & mi(eli2inel)
			if "`c'"!="`wt'" { 
				loc d = `c'-1
				replace elig`c'=2 if elig`d'==2 & elig`c'==3
			}
			replace elig`c'=1 if exp==`a' & n!=`b' & elig`c'==3 	
		}	
	}
	sort wtranselig pidp n
	drop eligstat elig_chk 
	egen elig = rowmean(elig*)
	replace elig=0 if elig!=1
	
	g age_lktc = age 
	replace age_lktc = 90 if age_lktc>90 & !mi(age_lktc)
	la var age_lktc "Age at last known wave to be alive (top coded at age 90)"

	g eli2inelm = eli2inel 
	g sx_gb = 1
	preserve 
		forval i = 0/1 { 
		    use "$wdata\qx_gb", clear 
			ren age age_lktc 
		    if `i'==0 loc il "male"
			else loc il "female"
			n di "`il'"
			keep age_lktc qx_`il'* 
			ren qx_`il'* qx*
			g female = `i'
			n d
			ren qx_gb_* sx_gb_* 
			tempfile qx_`i'
			save `qx_`i''
		}
		use `qx_0', clear 
		n merge 1:1 age_lktc female  using `qx_1', nogen 
		tempfile qx 
		save `qx'
		
	restore 
	forval i = 2/$wn1c {
		loc j = ((${wn1c}+2)-`i')
		n merge m:1 age_lktc female /*elig eli2inelm*/ using `qx' , ///
			keep(1 3) nogen keepus(sx_gb_`i')
		replace sx_gb_`i' = (1-sx_gb_`i') if elig`i'==1 // survival rate
		/*
		In the scenario that someone dies at wave x, the probability of them 
		continuing to be dead at each subsequent wave is 1.0, so for each 
		scenario (line in spreadsheet), you should have between 0 and 26 
		values 1-qx, followed by a single value of qx 
		(except for the final scenario, where they are still alive at w26), 
		followed by 1s.
		*/
		replace sx_gb_`i' = 1 if `i'>eli2inel 
		replace sx_gb_`i' = 1 if `i'<wtranselig 
		replace sx_gb = sx_gb * sx_gb_`i' if !mi(sx_gb_`i' )
		replace age_lktc = age_lktc+1 if age_lktc<90
	}
	order sx_gb_*, alpha
	order sx_gb_? sx_gb_1? sx_gb_2?
	order sx_gb_*, after(sx_gb)
	sort wtranselig pidp n
	
	/* Check: the total of sx_gb for each pidp should be 1 or very close to 1) */
	bys pidp (n): egen chk = total(sx_gb)
	n fre chk
	assert inrange(chk,.9999,1.0001)
	drop chk 
	/*end of check*/
	
	ren elig* elig_ue_*
	ren wtranselig wtranselig_ue
	n save "$wdata\ue_exp", replace 
}

/*====================================================================
                        3: Weight
====================================================================*/
qui {
	use "$datasets\bhps_data2", clear 
	merge 1:m pidp using "$wdata\ue_exp", keep(1 3) nogen 
	mvencode n, mv(1) o
	g weight = 0 
	replace weight = 1 if inlist(eligstat,1,2)
	replace weight = sx_gb if eligstat==3
	
	ren loyal loyal_uw
	
	// Ineligibility 
	g total_1 = 1 // excludes w1
	g total_m = 0 
	forval i = 2/$wn1c { 
		loc j = `i'-1
		replace w`i'=. if (eligstat==2 & ((wtranselig==`i') | mi(w`j'))) ///
			| (eligstat==3 & elig_ue_`i'==2)
		replace total_1 = total_1 + 1 if w`i'==1 
		replace total_m = total_m + 1 if w`i'==. 
	}
	
	n fre total* 
	
	/* people who are "loyal" includes people who have responded at 
	every wave as well as those who responded at every wave up to
	becoming ineligible */ 
	g total = total_1 + total_m 
	cap drop loyal 
	g loyal = (total==$wn1c)
	n fre loyal
	
	/* Check */ 
	n duplicates tag pidp, gen(dup)
	n assert dup==0 if inlist(eligstat,1,2)
	n assert dup>0 if eligstat==3
	drop dup 
	/* End of Check */ 
	
	br pidp w* eligstat wtranselig* elig_ue*
	sort pidp n 
	n save "$datasets\bhps_data3", replace

	cls 
	n di in red `"Save "$datasets\bhps_data3.csv" (Y/N)"' _request(_SAVE)
	loc save = strupper("`SAVE'")
	if "`save'"=="Y" {
		keep pidp loyal wtranselig eligstat w* weight 
		n export delim "$datasets\bhps_data3.csv", replace
	}
}

/*====================================================================
                        Program Close
====================================================================*/
cap log close 
