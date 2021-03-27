%macro rn_import_report_schedule(Excel=);
    %rn_hide_code;

	*** Check if Excel exists *** ;
	Data _Null_;
		File_id=Filename("CheckF", "&Excel.");
		File_Exists=FExist("CheckF");
		Call Symput('File_Exists', File_Exists);
	Run;

	%If &File_Exists. %Then %Do;

		proc import file="&Excel."
			dbms=xlsx
			out=rn_report_schedule_upload replace;
		run;
		
		*** Retrieve Target Table Column Types v Source Table Column Types *** ;
		*** Convert Column if needed *** ;
		%Let RN_Convert=N;
		%Let RN_Conversions=0;

		Data RN_Cntl.RN_Report_Schedule_Upload ;
			Attrib Report_ID           Length=8
				   Report_Name         Length=$132
				   Depends_on          Length=$32
				   Run_Date            Length=8 
				   Run_Day             Length=$20           
				   SAS_Program_Package Length=$256
				   Log_Location        Length=$256
				   Email_Notification  Length=$256
				   Trigger             Length=$256
				   Trigger_Timeout     Length=8
				   Work_Days_Only      Length=$1
			;
			Stop;
		Run;

		Proc Contents Data=rn_Cntl.RN_Report_Schedule_Upload noprint Out=Master_Cols(Keep=Name Type Length Format);
		Quit;
		Proc Contents Data=RN_Report_Schedule_Upload noprint Out=Slave_Cols(Keep=Name Type Length Format);
		Quit;
		Data Chk_Cols;
			Merge Master_Cols(Rename=(Type=Master_type Length=Master_Length))
			      Slave_Cols(Rename=(Type=Slave_type Length=Slave_Length))
				  ;
			By Name;
			If Master_Type ne Slave_Type Then Do;
			    Cnt+1;
			    Call Symput(Compress('RN_Convert_Name_'||Put(Cnt, 8. -L)), Strip(Name));
				Call SymputX(Compress('RN_Convert_Type_'||Put(Cnt, 8. -L)), Master_Type);
				Call SymputX(Compress('RN_Convert_Length_'||Put(Cnt, 8. -L)), Slave_Length);			
				Call Symput('RN_Conversions', Cnt);
				Output;
			End;
		Run;
		Proc Datasets Lib=Work Nolist Nodetails;
	 		Delete Master_Cols Slave_Cols Chk_Cols; 
		Quit;

		**** **** ;
		%If &RN_Conversions. %Then %Do;
			%Put NOTE: Having to convert columns;
	        %Do Conv=1 %To &RN_Conversions.;
				%Put NOTE: &&RN_Convert_Name_&Conv. Type: &&RN_Convert_Type_&Conv. Length: &&RN_Convert_Length_&Conv.;
			%End;
				
			Data rn_Report_Schedule_Upload;
				Set rn_Report_Schedule_Upload;

	            %Do Conv=1 %To &RN_Conversions.;
	                %If &&RN_Convert_Type_&Conv.=2 %Then %Do;
						_&&RN_Convert_Name_&Conv. =Compress(Put(&&RN_Convert_Name_&Conv., 8. -L), '.');
					%End;
					%Else %Do;
						_&&RN_Convert_Name_&Conv. =Input(&&RN_Convert_Name_&Conv., 8.);
					%End;
					Drop &&RN_Convert_Name_&Conv.;
					Rename _&&RN_Convert_Name_&Conv. =&&RN_Convert_Name_&Conv.;
				%End;
			Run;
		%End;

		Proc Contents Data=RN_Report_Schedule_Upload noprint Out=Slave_Cols1(Keep=Name Type Length Format);
		Quit;
		
		Data rn_Report_Schedule_Upload;
			If 0 Then Set rn_Cntl.rn_Report_Schedule_Upload;
			Set rn_Report_Schedule_Upload;
		Run;

		* Control The Data Structures * ;
		Proc SQL Noprint; 
		 	Delete from rn_Cntl.rn_Report_Schedule_Upload; 
		Quit; 
		Proc Append Base=rn_Cntl.rn_Report_Schedule_Upload Data=rn_Report_Schedule_Upload; 
		Quit; 

		Proc Datasets Lib=Work Nolist Nodetails;
	 		Delete rn_Report_Schedule_Upload Slave_Cols1; 
		Quit;
	%End;
	%Else %Put NOTE: No Excel Sheet Found ;

	%rn_unhide_code;

%mend;


/*%rn_import_report_schedule(Excel=&RN_Base_Dir.\Control Table\RN_Report_Schedule.xlsx);*/

