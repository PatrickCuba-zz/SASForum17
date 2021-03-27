****** DI Studio Code Node ******* ;
options mprint mlogic;
*** Set by User *** ;
%rn_import_report_schedule(Excel=\Actuary\SAS Server\Data Integration Schedule\Report Development\RN_Report_Schedule\RN_Report_Schedule.xlsx);
%rn_import_report_schedule(Excel=\Actuary\SAS Server\Data Integration Schedule\Report Development\RN_Report_Schedule\Testing\RN_Report_Schedule.xlsx);


/*done in L1*/
options mprint mlogic;
%rn_validate_report_schedule;

%Let RN_Log=/var/opt/sas/data/BTFGI/reports/Scratch/logs/;

%Let RN_Batch=/var/opt/sas/conf/Lev1/SAS_BTFGI/BatchServer/sasbatch.sh;
%Let L2_Email_Notification=patrick.cuba@btfinancialgroup.com;
%Let L2_Report_Name=My Report;
%Put L2_Email_Notification=&L2_Email_Notification.;

options mprint mlogic;

*** 1st to run *** ;
/*%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Termination.sas;*/
/*%Let L2_Report_ID=2;*/
*** 2nd to run *** ;
/*%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Emulation.sas;*/
/*%Let L2_Report_ID=1;*/
*** 3rd to run - lets fail this job - edit the program with syntax error *** ;
/*%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Claims.sas;*/
/*%Let L2_Report_ID=3;*/
*** 4th run - shouldn't be able to - we have a failed dependency *** ;
/*%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Pricing.sas;*/
/*%Let L2_Report_ID=5;*/
*** 5th run - lets make this fail too so we can see it in our email *** ;
/*%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Rates.sas;*/
/*%Let L2_Report_ID=4;*/
*** 6th run - finally lets check running the report dependent on everything *** ;
/*%Let RN_Prog= /var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Products.sas;*/
/*%Let L2_Report_ID=6;*/
*** 7th run - with warnings *** ;
/*%Let RN_Prog=  /var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Cat.sas;*/
/*%Let L2_Report_ID=8;*/
/*%Let L2_Trigger=RN_CatCode;*/

*** Blanks in the program name *** ;
%Let RN_Prog=/var/opt/sas/data/BTFGI/reports/Scratch/Scratch/programs/Report 1.sas;
%Let L2_Report_ID=9;
%Let L2_Trigger=;


*** ----------- *** ;
/*Di Step */
/*Pre Code to Node*/
	Data _NULL_;
		If _N_ = 1 Then Do;
			Declare Hash ReadData(Dataset: 'RN_Cntl.RN_REPORT_SCHEDULE', Ordered:'Yes'); 
			ReadData.DefineKey('Report_ID'); 
			ReadData.DefineData('Report_ID', 'Report_Status');               
			ReadData.DefineDone();                             

		End;
		Set RN_Cntl.RN_REPORT_SCHEDULE;

		Can_Run='Y';
		Dependency_Num=Sum(Count(Depends_on,'|'), Anydigit(Depends_on));
		Do __Iter = 1 To Dependency_Num;
			Find_Dep=Input(Scan(Depends_on, __Iter, '|'), 8.);
			/* For each Dependant Report ID - check for Failed or Did not run */
			RC=ReadData.Find(Key: Find_Dep);
			/* Do not check for blanks in status - DI loop & Run Layers ensure that you do not need to check for that */
			If Report_Status in ('Failed' 'Did not run') Then Can_Run='N';
		End;
		Call Symput('RN_Can_Run', Can_Run);

		Where Report_ID=&L2_Report_ID.;
	Run;

	%Put RN_Can_Run=&RN_Can_Run.;

/*End of Pre Code*/
%Macro RN_Execute_Report;
	%IF &RN_Can_Run.=Y %Then %Do;

	/*Di Step*/
		proc sql;
		   update RN_Cntl.RN_REPORT_SCHEDULE
		      set 
		         Report_Status= "Running",
		         Flow_Upd_Dtm= DateTime()
		      where
		         Report_ID = &L2_Report_ID.
		   ;
		quit;
	/**/

	*** Execution *** this goes to DI Studio ;
	/*%Macro RN_Execute_Report;*/
		%Global RN_Return_Code;
		*** Final Clean up of variables ;

		%Let RN_LogName=%Sysfunc(Reverse(%Scan(%Scan(%Sysfunc(Reverse(&RN_Prog.)), -1, .), 1, /)));
		Data _Null_;
			Call Symput('RN_LogName', Translate("&RN_LogName.",'_',' '));
		Run;
		%Let RN_Log=&RN_Log./&RN_LogName.;
		%Let RN_Log=%Sysfunc(Tranwrd(&RN_Log., //, /));

		%PUT NOTE: ####################################################################################### ;
		%Put NOTE: Executing RN_Prog=&RN_Prog. ;
		%Put NOTE: Log location RN_Log=&RN_Log. ;
		%PUT NOTE: ####################################################################################### ;
		*** Look for Triggers *** ;
		 *** Monthly - Daily *** ;
		*** Wait 3 minutes *** ;
		%Let Trigger_Found=N;
		%Do %Until(&Trigger_Found.=Y);
			
			%Let DSID=%Sysfunc(Open(RN_Cntl.RN_Trigger_Reg));
			%Let DS_Nobs=%Sysfunc(Attrn(&DSID., NOBS));
			%Let RC=%Sysfunc(Close(&DSID.));
			%Let Custom_Trigger_DS=;

			%If &L2_Trigger.^= %Then %Do;
				%Let DS_Nobs=%Eval(&DS_Nobs.+1); 
				Data __Custom_Trigger;
					If 0 Then Set RN_Cntl.RN_Trigger_Reg;
					Trigger_Name='Custom Trigger';
					Filename_Path="&L2_Trigger.";
				Run;
				%Let Custom_Trigger_DS=__Custom_Trigger;
			%End;

			Data _Null_;
				Array Assign_FileP[&DS_Nobs.] $256 _Temporary_;
				Array Assign_FileT[&DS_Nobs.] $256 _Temporary_;

				** In case we have a custom Trigger to wait for ** ;
				Set &Custom_Trigger_DS. 
			        RN_Cntl.RN_Trigger_Reg End=End;
				Trigger_Found='Y';

				** Deals with Filename and Path/Filename connundrum ;
				Resolved=Strip(Resolve(Filename_Path));
				Num_Slashes=Count(Resolved,'/');
				If Num_Slashes = 0 Then Resolved="&RN_LSFTrigger_Path."||Resolved;

				*** Find the first available slot *** ;
				Open_Slot=WhichC('', of Assign_FileP[*]);

				** Assign FileRefs to Array ** ;
				Assign_FileP{Open_Slot} = Resolved;
				Assign_FileT{Open_Slot} = Trigger_Name;

				If End Then Do;
					Do I = 1 To Open_Slot;
						** Link to Filename Function ** ;
						Rc=Filename("F_Assign", Assign_FileP{I});
						** Open the Fileref ** ;
						F_ID=FOpen("F_Assign");
						** Close ** ;
						Rc=FClose(F_ID);

						If F_ID=0 Then Do;
							Put "Note: Did not find " Assign_FileT{I} ", " Assign_FileP{I};
							Trigger_Found='N';
						End;
						Else Do;
							Put "Note: Found " Assign_FileT{I} ", " Assign_FileP{I};
						End;
					End;
					Call Symput('Trigger_Found', Trigger_Found);
				End;
				Where Trigger_Name in ('Daily Schedule' 'Monthly Schedule' 'Weekly Schedule' 'Custom Trigger');
			Run;

			%Put All Triggers Found=&Trigger_Found.;

			%If &Trigger_Found.=N %Then %Do;
				%Put NOTE: Trigger not found - Sleep for 5 minutes;
				Data _Null_;
					Rc_S=Sleep(300,1);
				Run;
			%End;
		%End;
        
		*** Execute Batch command *** ;
		%Let RN_Log_Parm=%sysfunc(compress(%sysfunc(translate(%sysfunc(PutN(%Sysfunc(Today()), yymmddp10.))_%sysfunc(PutN(%Sysfunc(Time()), time8.)), .,:))));

		%Sysexec(&RN_Batch. -log &RN_Log._&RN_Log_Parm..log -batch -noterminal -logparm "rollover=session"  -sysin &RN_Prog. -lognote1 "SAS Reporting Schedule");
		*** Capture return code *** ;

		**** Read the Log **** ;
		Filename ReadLog "&RN_Log._&RN_Log_Parm..log";

		%Let Log_Message=;
		Data _Null_;
			Length Log_Message $256.;
			Infile ReadLog Lrecl=32000 Truncover DSD;
			Input Readline : $500.;
			Retain Can_Read 'N' SYSRC 0 Log_Message '' FirstWarning 0 ;
			If Strip(Readline) = 'NOTE: >>>> End of Autoexec <<<<' Then Can_Read='Y';
			If Can_Read='Y' Then Do;
				If Strip(Substr(Readline,1 , 8)) = 'WARNING:' & ^FirstWarning Then Do;
					SYSRC=Max(SYSRC, 4);
					Log_Message=Compress(Substr(Readline, 9, 256), '"');
					
					Putlog 'NOTE: Found a warning in the log';
					Call Symput('Log_Message', Log_Message);
					Call Symput('sysrc', SYSRC);
				End;
				If Strip(Substr(Readline,1 , 6)) = 'ERROR:' Then Do;
					SYSRC=Max(SYSRC, 10);
					Log_Message=Compress(Substr(Readline, 7, 256), '"');

					Putlog 'NOTE: Found an error in the log';
					Call Symput('Log_Message', Log_Message);
					Call Symput('sysrc', SYSRC);
					Stop;
				End;
			End;
		Run;

		%Let RN_Return_Code=%Sysfunc(IFC(&sysrc.=0, Success, %Sysfunc(IFC(&sysrc.=4, Ended with Warnings, Failed))));

		%PUT NOTE: ####################################################################################### ;
		%PUT NOTE: System Return Code = &sysrc. = &RN_Return_Code.;
		%Put NOTE: SYSCC=&SYSCC.;
		%PUT NOTE: ####################################################################################### ;

		%If &RN_Return_Code.=Failed %Then %do;
			%PUT NOTE: --------------------------------------------------------------------------------------- ;
			%PUT NOTE: Failed job means that any dependant jobs will not run ;
			%PUT NOTE: --------------------------------------------------------------------------------------- ;
		%End;

		/*Di Step*/
		proc sql;
		   update RN_Cntl.RN_REPORT_SCHEDULE
		      set 
		         Report_Status= "&RN_Return_Code.",
		         Flow_Upd_Dtm= DateTime()
		      where
		         Report_ID = &L2_Report_ID.
		   ;
		quit;
		/**/
		/*Post running */
	%End;
	%Else %Do;
		Data _Update;
			If 0 Then Set RN_Cntl.RN_REPORT_SCHEDULE;
			Report_ID=&L2_Report_ID.;
			Report_Status="Did not run";
		Run;
		
		data RN_Cntl.RN_REPORT_SCHEDULE;
			Set _Update(Rename=(Report_Status=__Report_Status));
			Modify RN_Cntl.RN_REPORT_SCHEDULE Key=Report_ID;
			If _IORC_ = %SYSRC(_SOK) then do;
				Report_Status=__Report_Status;
				Replace;
			End;
		Run;
	%End;
%Mend;
%rn_Execute_Report;

/*To be run by L1*/
%rn_report_end_status;