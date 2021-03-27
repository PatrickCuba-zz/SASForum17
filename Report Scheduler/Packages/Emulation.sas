Data _NULL_;
	Put 'it worked';
run;

%TOEXCEL(dataset=SAShelp.cars, outfile=\PeterC_WIP\SchedTest\testNull3.xls, sheet=Final );

Data _Null_;
	Rc_S=Sleep(20,1);
	Put 'Report ID 1, depends on 2, testing PC File Server ';
Run;