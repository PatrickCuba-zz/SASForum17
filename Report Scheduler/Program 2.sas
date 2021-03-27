
*** SETUP in AUTOEXEC *** ;
%Let RN__SysType=%Sysfunc(IFC(&SYSSCP.=WIN,\,/));
%Let RN_Base_Dir=~&RN__SysType.Report Scheduler;

libname RN_Cntl "&RN_Base_Dir.&RN__SysType.Control Table";
%Let DEFAULT_LOG_LOCATION=&RN_Base_Dir.&RN__SysType.Logs;
%Let RN_Batch=E:\SAS\Config\Lev3\DIReporting\BatchServer\sasbatch.bat;
%Let RN_Semaphore_Dir=&RN_Base_Dir.\Semaphore;

%Put RN__SysType=&RN__SysType.;
%Put RN_Base_Dir=&RN_Base_Dir;
%Put libname RN_Cntl &RN_Base_Dir.&RN__SysType.Control Table;
%Put DEFAULT_LOG_LOCATION=&DEFAULT_LOG_LOCATION.;
%Put RN_Batch=&RN_Batch.;
%Put RN_Semaphore_Dir=&RN_Semaphore_Dir.;

*** TEMP SECTION *** ;
option spool fullstimer mprint mlogic;
proc datasets lib=work nolist nodetails kill;
quit;

* Load to SAS Autos * ;
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_hide_code.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_unhide_code.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_import_report_schedule.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_validate_report_schedule.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_lockds.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_unlockds.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_report_end_status.sas";
%inc "&RN_Base_Dir.&RN__SysType.Macros&RN__SysType.rn_report_save_history.sas";

* ONE off Table Creation ;
Data RN_Cntl.RN_Report_Schedule (Index=(Report_ID))
	RN_Cntl.RN_Report_Schedule_History;
	Attrib Report_ID Length=8
			Report_Name Length=$132
			Depends_on Length=$32
			Run_Group Length=8
			Run_Layer Length=8
			SAS_Program_Package Length=$256
			Log_Location Length=$256
			Email_Notification Length=$256
			Trigger Length=$256
			Trigger_Timeout Length=8
			Flow_Start_Dtm Length=8 Format=Datetime22.
			Flow_End_Dtm Length=8 Format=Datetime22.
			Log_Message Length=$256
			Report_Status Length=$30
;
Stop;
Run;

*** Run only when needed - likely to be saved as SQL Server view by CUA ;
%rn_import_report_schedule(Excel=~/Report Scheduler/Control Table/RN_Report_Schedule.xlsx);

%rn_validate_report_schedule(debug=Y);

