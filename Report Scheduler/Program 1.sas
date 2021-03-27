proc datasets lib=work nolist nodetails kill;
quit;

libname RN_Cntl "~/Report Scheduler/Control Table";

%Let RN_Base_Dir=;
%Let DEFAULT_LOG_LOCATION=~/Report Scheduler/Logs/; 

Data RN_Cntl.RN_Report_Schedule ;
	Attrib Report_ID           Length=8
	       Report_Name         Length=$132
	       Depends_on          Length=$32
           Run_Group           Length=8 
           Run_Layer           Length=8             
           SAS_Program_Package Length=$256
	       Log_Location        Length=$256
           Email_Notification  Length=$256
           Trigger             Length=$256
           Flow_Upd_Dtm        Length=8    Format=Datetime22.
           Log_Message         Length=$256 
           Report_Status       Length=$30 
           ;
    Stop;
Run;

%rn_import_report_schedule(Excel=~/Report Scheduler/Control Table/BT_Report_Schedule.xlsx);


%rn_validate_report_schedule;