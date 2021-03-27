%macro rn_hide_code;
	%global rn_mprint rn_mlogic rn_symbolgen;
	%let mprint=%sysfunc(getoption(mprint)); 
	%let mlogic=%sysfunc(getoption(mlogic));
	%let symbolgen=%sysfunc(getoption(symbolgen));
	
/*	options nomprint nomlogic nosymbolgen;*/
%mend;

