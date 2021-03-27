%macro rn_unhide_code;
	%Let rn_mprint=%sysfunc(ifc(&rn_mprint.^=, &rn_mprint., ));
	%Let rn_mlogic=%sysfunc(ifc(&rn_mlogic.^=, &rn_mlogic., ));
	%Let rn_symbolgen=%sysfunc(ifc(&rn_symbolgen.^=, &rn_symbolgen., ));
	options &rn_mprint. &rn_mlogic. &rn_symbolgen.;
%mend;