/***************************************************************************************/
/***************************************************************************************/
/****  Program Name   *   RN Send email                                             ****/
/****                 *                                                             ****/
/***************************************************************************************/
/****  Purpose of     *   Sends email for report completion status                  ****/
/****  Program        *                                                             ****/
/****                 *                                                             ****/
/***************************************************************************************/
/****   Date          *                       *Original  * 04JAN2016                ****/
/****                 *                       *Developer * Patrick Cuba             ****/
/***************************************************************************************/
/****                    Maintenance and Code changes                               ****/
/***************************************************************************************/
/****             Begin: Copy this section for each code change                     ****/
/***************************************************************************************/
/****   Date          *                       *Developer *                          ****/
/****                 *                       *          *                          ****/
/***************************************************************************************/
/****                    Maintenance or Code change details                         ****/
/***************************************************************************************/
/****                                                                               ****/
/****                                                                               ****/
/****                                                                               ****/
/****                                                                               ****/
/***************************************************************************************/
/****               End: Copy this section for each code change                     ****/
/***************************************************************************************/
/***************************************************************************************/

%Macro rn_report_end_status;
	%Let Email_Address_Max=0;

	%RN_LockDS(DS=RN_CNTL.RN_REPORT_SCHEDULE);

	*** Build Unique List of Emails we need to send to for reports that ran today *** ;
	* Each email will get a unique set of reports *;
	Data _Null_;
	    Length Email_Address $255. ;
	    If _N_ = 1 Then Do;
	       Declare Hash EmailList(Multidata: 'Yes', Ordered: 'Yes'); 
	        EmailList.DefineKey('Email_Address'); 
	        EmailList.DefineData('Email_Address', 'Report_ID', 'Report_Name', 'Report_Status', 'Log_Location', 'Log_Message', 'Flow_End_Dtm', 'Flow_Start_Dtm');             
	        EmailList.DefineDone();                               
	        
	        Call Missing(Email_Address);
	    End;
	    Set RN_Cntl.RN_Report_Schedule;
	    
	    If Email_Notification > '' Then Do;
	        Email_Num=Sum(Count(Strip(Email_Notification),' '), 1);
	        Do __Iter = 1 To Email_Num;
	             Email_Address=Compress(Compress(Scan(Strip(Email_Notification), __Iter, ' ')),'"');
	                        
	             /* Check for email in list - new then add, old then update report id list*/
	             Add_RC=EmailList.Add();
	        End;
	        RC_Out=EmailList.Output(dataset: 'Work.Email_Addresses'); ;
	    End;
	Run;

	%RN_UnLockDS(DS=RN_CNTL.RN_REPORT_SCHEDULE);

	%Let RN_Emails=%Sysfunc(Exist(Work.Email_Addresses));

	%If &RN_Emails. %Then %Do;

		Data _Null_;
		    Set Email_Addresses;
		    By Email_Address;

		    If Last.Email_Address Then Do;
		        Cnt+1;
		        Call Symput(Compress('Email_Address_'||Cnt), Email_Address);
		        Call Symput('Email_Address_Max', Cnt);
		    End;
		Run;

		%Do E=1 %To &Email_Address_Max.;
			%Let Stripped_Email=&&Email_Address_&E.;

			ods listing close;

			ODS PATH work.templat(update) sasuser.templat(read)
               sashelp.tmplmst(read);

			Proc Template;
			   Define Style MyCustom;
			   Parent=Styles.Default;
			      Class Body  /
			            Background=cxffffff;
				  Class Systemfooter /
				        Background=cxffffff; 
				  Class Systemfooter2 /
				        Background=cxffffff; 
				  Class Systemfooter3 /
				        Background=cxffffff; 
				  Class Systemfooter4 /
				        Background=cxffffff; 
				  Class Systemfooter5 /
				        Background=cxffffff; 
				  Class Systemtitle /
				        Background=cxffffff;
				  Class Header /
				        Background=cxffffff; 
				End;
			Run;

			%Let SendMail=N;
			Data Send_Email_Addresses;
				Set Email_Addresses End=End;

				If Report_Status in ('Failed' 'Did not run' 'Ended with Warnings' 'Success') Then K+1; 

				If End Then Do;
	                If K=_N_ Then Call Symput('SendMail', 'Y');
					Else Call Symput('SendMail', 'N');
				End;

				Run_time = Flow_End_Dtm - Flow_Start_Dtm;
				Where Email_Address=%nrquote("&Stripped_Email.");
				Drop Email_Address;

				Format Run_time Time8.;
			Run;

			%Let RN_SentEmails=%Sysfunc(Exist(Rn_Cntl.Sent_Emails));
			%Put NOTE: RN_SentEmails=&RN_SentEmails.;

			** Reset to N if we have already sent the email per user ;
			%If &RN_SentEmails.=0 %Then %Do;
				Data Rn_Cntl.Sent_Emails;
					length Email_Address $255.; 
					Email_Address="&Stripped_Email.";
				Run;
			%End;
			%Else %Do;
				Data _Null_;
					Set Rn_Cntl.Sent_Emails;
					If Email_Address="&Stripped_Email." Then Call Symput('SendMail', 'N');
				Run;
			%End;
			** DI Job will delete this sent table at the start of the run ** ;

			%If &SendMail.=Y %Then %Do;
				Data AddToSendEmails;
					If _N_=0 Then Set Rn_Cntl.Sent_Emails;
					
					Email_Address="&Stripped_Email.";
				Run;
				Proc Append Base=Rn_Cntl.Sent_Emails Data=AddToSendEmails;
				Quit;

				Filename Outf Email
				To=%nrquote("&Stripped_Email.")
				Type='text/html'
				Subject='Report Schedule Completion Status'
				;
				ODS HTML
				File="Report_&sysdate9..html" Style=MyCustom
				Body=Outf 
				RS=None;


				Title1 color=blue font='Times New Roman' underlin=1 height=20pt "Run status for your scheduled jobs";
				Proc Report Data=Send_Email_Addresses Nowindows Missing Headline
		                         style(header column)=[background=white] Nocenter;
				    Column Report_ID Report_Name Report_Status Log_Location Log_Message Run_time;
					Compute Report_Status;
					If Report_Status='Failed' Then
					Call Define(_col_, 'style', 'style=[foreground=red]');

					If Report_Status='Success' Then
					Call Define(_col_, 'style', 'style=[foreground=green]');

					If Report_Status='Ended with Warnings' Then
					Call Define(_col_, 'style', 'style=[foreground=purple]');

					Endcomp;
					Footnote1 Color=black bold font='Times New Roman' height=10pt "Status Key: ";
				    Footnote2 Color=red height=9pt "Failed"
		                      Color=black " - Check the log for the reason the job failed";
				    Footnote3 Color=red height=9pt "Did not run"
		                      Color=black " - a dependant SAS Report Package did not run or failed";
				    Footnote4 Color=purple height=9pt "Ended with warnings"
		                      Color=black " - you should probably check the log for warnings";
				    Footnote5 Color=green height=9pt "Success"
		                      Color=black "- Job ended sucessfully";
					 ;
				Run;

				ODS HTML Close;
			%End;
		%End;
	%End;
	%Else %Do;
		%Put NOTE: Nothing to Send...;
	%End;
%Mend;
