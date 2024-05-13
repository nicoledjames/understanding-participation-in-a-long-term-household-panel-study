/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			02_data_analysis_1.do 
Task: 				Produce Graphs
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\02_data_analysis_1.do", replace t 

/*====================================================================
                        1: Response Patterns Graph
====================================================================*/
qui {
    /* unweighted */
	import excel "$latent_gold\results\lgf_1_profile.xlsx", clear ///
		first sh("Sheet1") case(lower)
	g n = _n, before(a)
	levelsof n if a=="Known Class",loc(kc)
	cou 
	loc N `r(N)'
	drop if inrange(n,`kc',`N')
	drop if inlist(a,"Cluster Size","Indicators")
	destring a, gen(wave) force
	order wave, after(a)
	la var wave "Wave"
	cou
	loc i = 0
	forval j = 3(3)`r(N)' { 
		loc i = `i'+1
		replace wave = `i' if wave==1 in `j'
	}
	drop n a 
	drop if mi(wave) | wave==0
	save "$wdata\unweighted.dta",replace
	

	macro drop _tw _cn _mn
	colorpalette s2, nograph // sets `r(p)'
	loc cn = 7
	loc mn = `cn'-4
	forval i = 1/`cn' { 
		loc tw = "`tw' (line cluster`i' wave, lcolor(`r(p`i')'))"
	}
	loc fn "lca_`cn'_classes_1"
	graph set window fontface "Times New Roman"
	n twoway `tw', name(`fn', replace) saving("`fn'", replace) ///
		xline(18, lp(dash) lc(black)) ///
		ti("RMLCA Model `mn' (unweighted)", color(black)) ///
		l1("Probability of Response", color(black)) /// 
		xlab(1(1)${wn1c}, grid glc(gs15)) ///
		ylab(0(0.1)1, grid glc(gs15)) ///
		graphr(fc(white) lp(solid) lc(black) margin(medium)) ///
		plotr(fc(white) lp(solid) lc(gs15) margin(medium)) ///
		legend(off) ///
		text(1 23 `"Class 1 "Loyal""', place(ne) s(vsmall) m(vsmall)) ///
		text(.2 4.2 `"Class 2"', place(e) s(vsmall) m(vsmall)) ///
		text(.16 4.5 `""Attrition by W8""', place(e) s(vsmall) m(vsmall)) ///
		text(.89 22.4 `"Class 4"', place(e) s(vsmall) m(vsmall)) ///
		text(.86 22.7 `""Stayers""', place(e) s(vsmall) m(vsmall)) ///
		text(.36 19.5 `"Class 3"', place(e) s(vsmall) m(vsmall)) ///
		text(.32 19.8 `""Attrition by W23""', place(e) s(vsmall) m(vsmall)) ///
		text(.2 10.9 `"Class 5"', place(e) s(vsmall) m(vsmall)) ///
		text(.16 11.2 `""Attrition by W14""', place(e) s(vsmall) m(vsmall)) ///
		text(.3 15.4 `"Class 6"', place(e) s(vsmall) m(vsmall)) ///
		text(.26 15.7 `""Attrition"', place(e) s(vsmall) m(vsmall)) ///
		text(.23 15.9 `"by W22""', place(e) s(vsmall) m(vsmall)) ///
		text(.63 4.3 `"Class 7"', place(e) s(vsmall) m(vsmall)) ///
		text(.6 4.6 `""Nudged""', place(e) s(vsmall) m(vsmall)) 
	n graph export "$output/`fn'.png", width(1386) height(1008) replace name(`fn')
	graph close `fn'

	/* weighted */
	import excel "$latent_gold\results\lgf_ue_profile.xlsx", clear ///
		first sh("Sheet1") case(lower)
	g n = _n, before(a)
	levelsof n if a=="Known Class",loc(kc)
	cou 
	loc N `r(N)'
	drop if inrange(n,`kc',`N')
	drop if inlist(a,"Cluster Size","Indicators")
	destring a, gen(wave) force
	order wave, after(a)
	la var wave "Wave"
	cou
	loc i = 0
	forval j = 3(3)`r(N)' { 
		loc i = `i'+1
		replace wave = `i' if wave==1 in `j'
	}
	drop n a 
	drop if mi(wave) | wave==0
	save "$wdata\weighted.dta",replace
	
	macro drop _tw _cn _mn
	colorpalette s2, nograph 
	loc cn = 7 
	loc mn = `cn'-4
	forval i = 1/`cn' { 
		loc tw = "`tw' (line cluster`i' wave, lcolor(`r(p`i')'))"
	}
	loc fn "lca_ue_`cn'_classes"
	graph set window fontface "Times New Roman"
	n twoway `tw', name(`fn', replace) saving("`fn'", replace) ///
		xline(18, lp(dash) lc(black)) ///
		ti("RMLCA Model `mn' (weighted)", color(black)) ///
		l1("Probability of Response", color(black)) /// 
		xlab(1(1)${wn1c}, grid glc(gs15)) ///
		ylab(0(0.1)1, grid glc(gs15)) ///
		graphr(fc(white) lp(solid) lc(black) margin(medium)) ///
		plotr(fc(white) lp(solid) lc(gs15) margin(medium)) ///
		legend(off) ///
		text(1 23 `"Class 1 "Loyal""', place(ne) s(vsmall) m(vsmall)) ///
		text(.1 5.5 `"Class 2"', place(e) s(vsmall) m(vsmall)) ///
		text(.06 5.8 `""Attrition by W8""', place(e) s(vsmall) m(vsmall)) ///
		text(.08 21.2 `"Class 3"', place(e) s(vsmall) m(vsmall)) ///
		text(.05 21.6 `""Attrition by W22""', place(e) s(vsmall) m(vsmall)) ///
		text(.93 21.8 `"Class 4"', place(e) s(vsmall) m(vsmall)) ///
		text(.9 22.1 `""Stayers""', place(e) s(vsmall) m(vsmall)) ///
		text(.75 8.7 `"Class 5"', place(e) s(vsmall) m(vsmall)) ///
		text(.72 9.0 `""Attrition"', place(e) s(vsmall) m(vsmall)) ///
		text(.69 9.3 `"by W16""', place(e) s(vsmall) m(vsmall)) ///
		text(.37 13.9 `"Class 6"', place(e) s(vsmall) m(vsmall)) ///
		text(.34 14.2 `""Abruptly Nudged""', place(e) s(vsmall) m(vsmall)) ///
		text(.55 4.2 `"Class 7"', place(e) s(vsmall) m(vsmall)) ///
		text(.52 4.5 `""Gradually Nudged""', place(e) s(vsmall) m(vsmall)) 
	n graph export "$output/`fn'.png", width(1386) height(1008) replace name(`fn')
	graph close `fn'
}

/*====================================================================
                        2: Response Rates Graph
====================================================================*/
qui {
	foreach typ in unweighted weighted {
		use "$wdata/`typ'.dta", clear 
		la var overall "Response Rate"
		*format overall %3.2f
		graph set window fontface "Times New Roman"
		n twoway (connected overall wave), ///
			name(rr_`typ', replace) saving("rr_`typ'", replace) ///
			ti("Response Rates (`typ')", color(black)) ///
			xline(18, lp(dash) lc(black)) ///
			xlab(1(1)${wn1c}, grid glc(gs15)) ///
			ylab(0(0.1)1, grid glc(gs15)) ///
			graphr(fc(white) lp(solid) lc(black) margin(medium)) ///
			plotr(fc(white) lp(solid) lc(gs15) margin(medium)) ///
			legend(off)
		*n graph export "$output/rr_`typ'.jpg", ///
			width(1386) height(1008) replace name(rr_`typ')
		n graph export "$output/rr_`typ'.png", ///
			width(1386) height(1008) replace name(rr_`typ')
		graph close rr_`typ'
	}
}

/*====================================================================
                        Program Close
====================================================================*/
cap log close
ex