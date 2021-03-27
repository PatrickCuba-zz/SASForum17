data x;
	x=1;
run;
proc sql noprint;
	create table x as
	select *
	from x;
quit;

Data _Null_;
	Rc_S=Sleep(20,1);
	Put 'Report ID 9, give me a warning';
Run;