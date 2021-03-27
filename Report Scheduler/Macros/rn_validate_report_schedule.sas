/***************************************************************************************/
/***************************************************************************************/
/****  Program Name   *   RN Validate Report Schedule                               ****/
/****                 *                                                             ****/
/***************************************************************************************/
/****  Purpose of     *   Utility to validate Report Schedule                       ****/
/****  Program        *                                                             ****/
/****                 *                                                             ****/
/***************************************************************************************/
/****   Date          *                       *Original  * 04SEP2016                ****/
/****                 *                       *Developer * Patrick Cuba             ****/
/***************************************************************************************/
/****                    Maintenance and Code changes                               ****/
/***************************************************************************************/
/****             Begin: Copy this section for each code change                     ****/
/***************************************************************************************/
/****   Date          *   23/11/2016          *Developer *                          ****/
/****                 *   Run Group Change    *          *                          ****/
/***************************************************************************************/
/****                    Maintenance or Code change details                         ****/
/***************************************************************************************/
/**** Rewritten Run Group to function with more guarantee                           ****/
/****                                                                               ****/
/****                                                                               ****/
/****                                                                               ****/
/***************************************************************************************/
/****               End: Copy this section for each code change                     ****/
/***************************************************************************************/
/***************************************************************************************/
%Macro rn_validate_report_schedule(debug=);

	%rn_hide_code;
	*** Preperation Step *** ;
	* --- Fetch Holidays --- * ;
    * --- Add Weekends   --- * ;
	%Let RN_Report_Schedule_Delay=%Sysfunc(IFC(%Sysfunc(Exist(RN_Cntl.RN_Report_Schedule_Delay)), RN_Cntl.RN_Report_Schedule_Delay, ));

	Proc Sort Data = RN_Cntl.Public_Holiday Out = Public_Holiday;
 	   By Date;
	Run;
	Data Public_Holiday;
		Set Public_Holiday End=End;
		
		*** Generate Weekends - based on public holiday table *** ;
		Previous_Date=Lag1(Date);
		Output;
		If _N_ ^= 1 Then Do;
			Do Date_increment=Previous_Date To Date;
				If Strip(Put(Date_increment, DowName.)) in ('Saturday' 'Sunday') Then Do;
					Date=Date_increment;
					Holiday='Weekend';
					Output;			
				End;
			End;
		End;
		
		/* If the public holiday table has not been update we still want to create weekends */
		If End Then Do;
			Do Date_increment=Today() To Intnx('Month', Today(), 2, 'E');
				If Strip(Put(Date_increment, DowName.)) in ('Saturday' 'Sunday') Then Do;
					Date=Date_increment;
					Holiday='Weekend';
					Output;			
				End;
			End;
		End;
		Drop Previous_Date Date_increment;
	Run;
	Proc Sort Data=Public_Holiday Nodupkey;
		By Date;
	Run;

	*** Schedule Validation Process *** ;
	**** Step 1: Check what will run today **** ;

	*** Program Logic *** ;
	* We asssign a Run_Date if it is NOT populated based on what has been loaded to Run_Day * ;
	Data RN_Report_Schedule(Drop=Holiday)
         RN_Report_Schedule_Delay
         RN_Report_Schedule_Stopped;

        If 0 Then Do;
			Set RN_Cntl.RN_Report_Schedule;
			Set Public_Holiday;
		End;

		/* Hash for Public Holidays and Weekends */
		If _N_ = 1 Then Do;
	 		Declare Hash PublicHoliday(Dataset: 'Public_Holiday', Ordered:'Descending'); 
	  		PublicHoliday.DefineKey('date'); 
	  		PublicHoliday.DefineData('date', 'Holiday');	  
	 		PublicHoliday.DefineDone();

			Call Missing(date);
		End;

		Set RN_Cntl.RN_Report_Schedule_Upload 
            &RN_Report_Schedule_Delay.
            ;

		By Report_ID Run_Date;
		Run_Layer=0;
		Run_Today='N';
		Depends_on=Compress(Depends_on);
 
		******************************* ;
		* Grab Increments (if any)      ;
		******************************* ;
		Run_Increment=Sum(Max(Input(Scan(Run_Day, -1, ':'),?? 8.),1), 0);
		Run_Day=Strip(Scan(Run_Day, 1, ':'));

		******************************* ;
		* Calculate What Will Run Today ;
		******************************* ;
		* If the frequency is a single Day, Daily, Date or Day of the Month - Validate what we got ;
		* Prepopulate Array with Days of Week ;
		Array __DoW{7} $10. _Temporary_ ;
		Do a1=1 To Dim(__DoW);
			__DoW{a1}=Put(a1, downame.);
		End;
		* Does our input match any of the Days of the week? If yes then do we run today? ;
		Do a1=1 To Dim(__DoW); 
			If Strip(PropCase(Run_Day))=Strip(__DoW{a1}) Then 
				If Strip(PropCase(Run_Day))=Strip(Put(Today(), DowName.)) Then Do;
						Run_Date=Today();
				End;
		End;

		* Daily ;
		If Strip(Propcase(Run_Day))='Daily' Then Do;
			Run_Date=Today();
		End;

		* Was it a date in the month ? ;
	    If Strip(Propcase(Run_Day)) in ('End' 'Beginning' 'Middle') Then
	        if Sum(IntNX('Month', Today(),  0, Run_Day), Run_Increment, -1) = Today() Then Do;
				Run_Date=Today();
		End;

	    If Prxmatch("/\d\d$|\d$/", Strip(Run_Day)) Then 
	            If MDY(Month(Today()), Run_Day, Year(Today()))=Today() Then Do;
				Run_Date=Today();
		End;

		* Was it Quarterly ? ;
		If Strip(Propcase(Run_Day)) in ('Quarterly') Then
        	if Sum(IntNX('Qtr', Today(),  0), Run_Increment, -1)  = Today() Then Do;
				Run_Date=Today();
		End;

		********************************************************* ;
		* Check Run_Date against the public holidays and weekends ;
		********************************************************* ;
		If Upcase(Work_Days_Only)='Y' and Propcase(Run_Day) ne 'Daily' Then Do;
			Rc=0;
			Delayed='N';
			/* If we find a match it means the job will not run today but by whatever date we set */
			/* Output into a Delay table to be checked against at a later date */
			Do Until(Rc ne 0);
				Rc=PublicHoliday.Find(Key: Run_Date);
				If Rc=0 Then Do;
					Delayed='Y';
					Run_Date=Run_date+1;
				End;
			End;
		End;
		If Upcase(Work_Days_Only)='X' or (Upcase(Work_Days_Only)='Y' and Propcase(Run_Day) eq 'Daily') Then Do;
			Rc=0;
			Delayed='N';
			/* If we find a match it means the job will not run today and we will not delay the run */
			Rc=PublicHoliday.Find(Key: Run_Date);
			If Rc=0 Then Do;
				Run_Date=.;
				Delayed='X';
			End;
		End;
		*** Output to RN_Report_Schedule (to run today) *** ;
        *** Output to RN_Report_Schedule_Delay (to run in the future) *** ;
		If Run_Date=Today() Then Do;
			Run_Today='Y';
			Output RN_Report_Schedule;
		End;
		Else If Run_Date > Today() and Delayed='Y' and Propcase(Run_Day) ne 'Daily' Then Output RN_Report_Schedule_Delay;
		Else If Run_Date=. and Delayed='X' Then Output RN_Report_Schedule_Stopped;

		Drop A1 Run_Increment RC date Delayed;
		Format Run_Date Date9.;
	Run;
	*** A note about testing the above *** ;
	* If you wish to add more public holidays as test days and you already have records in _Delay table
	then you will have duplicates in Delay - adding more holidays means clearing _Delay table
	because _Delay table dates are cast in stone ;

	**** Add Delay Table to Permanent Table to be included in the next days run **** ;
	Proc Sort Data=RN_Report_Schedule_Delay Nodupkey;
		By Report_ID Run_Date;
	Run;
	Data Email_Delay;
		Keep Report_ID Email_Notification1 Report_Name Msg;
		Length Msg Email_Notification1 $256.;
		Set RN_Report_Schedule_Delay;
		Msg=CompBl("Delayed due to "||Holiday);

		If Email_Notification > '' Then Do;
			Email_Num=Sum(Count(Email_Notification ,'|'), 1);
			Do __Iter = 1 To Email_Num;
				Find_Email=Scan(Email_Notification , __Iter, '|');
				If Prxmatch("/[^@]+@[^@]+\.[^@]+/", Find_Email) Then Do;
					Find_Email=Compress('"'||Find_Email||'"');
					Email_Notification1=Compbl(Email_Notification1||" "||Find_Email);
				End;
			End;
		End;
		Rename Email_Notification1=Email_Notification;
	Run;
	Data RN_Cntl.RN_Report_Schedule_Delay;
		Set &RN_Report_Schedule_Delay.
            RN_Report_Schedule_Delay;
		By Report_ID Run_Date;

		/* Only future dated delays we are interested in  */
		If Run_Date > Today();
		Drop Holiday;
	Run;

	/* Notify user if their report is stopped - i.e. it is not allowed to run today */
	Data Email_Stopped;
		Keep Report_ID Email_Notification1 Report_Name Msg;
		Length Msg Email_Notification1 $256.;
		Set RN_Report_Schedule_Stopped;
		Msg=CompBl("Stopped due to "||Holiday);

		If Email_Notification > '' Then Do;
			Email_Num=Sum(Count(Email_Notification ,'|'), 1);
			Do __Iter = 1 To Email_Num;
				Find_Email=Scan(Email_Notification , __Iter, '|');
				If Prxmatch("/[^@]+@[^@]+\.[^@]+/", Find_Email) Then Do;
					Find_Email=Compress('"'||Find_Email||'"');
					Email_Notification1=Compbl(Email_Notification1||" "||Find_Email);
				End;
			End;
		End;
		Rename Email_Notification1=Email_Notification;
	Run;


	/* If the same Report_ID and Run_Date Then We need to keep just one Last.Rundate may keep two records here */
	Proc Sort Data=RN_Cntl.RN_Report_Schedule_Delay Nodupkey;
		By Report_ID Run_Date;
	Run;	

    **** Step 2: From what can run today build Valid Report_ID Format **** ;
	Data Fmt;
		Start=.;
		Label='';
		HLO='O';
		Output;
	Run;
	Data Fmt;
		Keep Start Label FMTNAME HLO;
		Set RN_Report_Schedule FMT;
		Retain Fmtname 'Valid_ID';
		Start = Report_ID;
		Label='V';
	Run;
	Proc Format Cntlin=Fmt;
	Quit;
	%If &Debug.^=Y %Then %Do;
		Proc Datasets Lib=Work Nolist Nodetails;
	 		Delete FMT RN_Report_Schedule_Delay Public_Holiday; 
		Quit;
	%End;

    **** Step 3: Validate data entries in report - result needs report_id index **** ;
	Data RN_Report_Schedule(Index=(Report_ID) Drop=MSG) 
	     Email_Message(Keep=Report_ID Email_Notification Report_Name Msg);

		Length Email_Notification1 SAS_Program_Package Log_Location Msg Find_Dep $256.; 

        If 0 Then Set RN_Cntl.RN_Report_Schedule;

		Set RN_Report_Schedule;
		By Report_ID;
		Retain Run_Layer 0;
		
		**************************************** ;
		* Calculate Dependency on other reports - Only on Reports running Today ;
		**************************************** ;
		Dependency_Num=Sum(Count(Depends_on,'|'), Anydigit(Depends_on));
		Do __Iter = 1 To Dependency_Num;
			Find_Dep=Scan(Depends_on, __Iter, '|');
			/* Check if a dependency is valid */
			If Put(Input(Find_Dep, 8.), Valid_ID.) ne 'V' Then Do;
				Run_Today='N';
				Msg=Compbl(Msg||"Invalid Dependency: "||Find_Dep); 
			End;
		End;

		******************************* ;
		* Check for missing values      ;
		******************************* ;
		If Report_Name='' Then Do;
			Run_Today='N';
			Msg=Compbl(Msg||"Missing Report_Name"); 
		End;
		If Report_ID=. Then Do;
			Run_Today='N';
			Msg=Compbl(Msg||"Missing Report_ID "); 
		End;

		********************************* ;
		* Validate Email and Log Location ;
		********************************* ;
		/* if these do not validate we still run the report - default the log location */
		/* do not send email */ 
		If Email_Notification > '' Then Do;
			Email_Num=Sum(Count(Email_Notification ,'|'), 1);
			Do __Iter = 1 To Email_Num;
				Find_Email=Scan(Email_Notification , __Iter, '|');
				If Prxmatch("/[^@]+@[^@]+\.[^@]+/", Find_Email) Then Do;
					Find_Email=Compress('"'||Find_Email||'"');
					Email_Notification1=Compbl(Email_Notification1||" "||Find_Email);
				End;
			End;
		End;
		
		If Log_Location > '' then Log_Location=Cat("&RN_Base_Dir.", Log_Location);

		Rc=Filename("MyDir", Log_Location);
		D_ID=DOpen("MyDir");
		If D_ID=0 Then Log_Location="&Default_Log_Location.";
		Rc=DClose(D_ID);
		
		********************************* ;
		* Validate SAS Package File       ;
		********************************* ;

		*** Change: SAS Program Packages may be in a different directory to Base ;
        * SAS_Program_Package=Cat("&RN_Base_Dir.", SAS_Program_Package);
		Rc=Filename("MyPgm", SAS_Program_Package);
		F_ID=FOpen("MyPgm");
		If F_ID=0 Then Do;
		    Run_Today='N';
			Msg=Compbl(Msg||"Unable to find SAS Package File "||SAS_Program_Package);
		End;
		Rc=FClose(F_ID); 

		** Count the number of directory seperators ;	
		Num_Slashes=Count(Tranwrd(SAS_Program_Package, "&RN__SysType.&RN__SysType.", "&RN__SysType."),"&RN__SysType.");

		Len=Length(SAS_Program_Package);
		If Num_Slashes Then Do;
			Call Scan(SAS_Program_Package,Num_Slashes, SubstrTo, Len,"&RN__SysType.");
			Chk_SAS_Program_Package=Substr(SAS_Program_Package, SubstrTo);
		End;
		Else Chk_SAS_Program_Package=SAS_Program_Package;

		Chk_for_Blanks=Count(Strip(Chk_SAS_Program_Package), ' ');
		If Chk_for_Blanks Then Do;
		    Run_Today='N';
			Msg=Compbl(Msg||"SAS Package File contains a Blank in the name, cannot run '"||SAS_Program_Package||"'");
		End;

		********************************* ;
		* Duplicate Report_ID             ;
		********************************* ;
		If ^(First.Report_ID And Last.Report_ID) Then Do;
			Msg=Compbl(Msg||"Duplicate Report_ID "||Report_ID);
			Run_Today='N';
		End;
		
	 	If Run_Today='N' and Msg ne '' Then Output Email_Message; 
	 	Else Output RN_Report_Schedule;
	 	
	 	Call Missing(Report_Status, Flow_Start_Dtm, Flow_End_Dtm );
			
		Drop __Iter Dependency_Num Find_Dep Run_Today  
		     Find_Email Email_Num Email_Notification 
		     Rc D_ID F_ID
             Num_Slashes Len SubstrTo Chk_SAS_Program_Package Chk_for_Blanks;
		Rename Email_Notification1=Email_Notification;
	Run;

	** Assigning Layers and Groups is not necessary ;
	%Let Email_SelfDep=;
	%Let DSID=%Sysfunc(Open(Work.RN_Report_Schedule));
	%Let MyNobs=%Sysfunc(Attrn(&DSID., NOBS));
	%Let RC=%Sysfunc(Close(&DSID.));

	%If &MyNOBS. %Then %Do;
	%Let Email_SelfDep=Email_SelfDep;
	
	**** Step 4: Calculate Layers - what can run in parallel **** ;
	****         Calculate Groups - what must be run together ****;
	Data _Null_;
		* Part 1 of Dynamic Assignments - Run_Layers ;
		Length Run_Layer Run_Group Parent Child Reassigned_Run_Group 8. __Depends_on $32.;
		If 0 Then Set Work.RN_Report_Schedule;
		* Declare Has to Read in Source Data ;
 		Declare Hash ReadData(Dataset: 'Work.RN_Report_Schedule', Ordered:'Yes'); 
  		ReadData.DefineKey('Report_ID'); 
  		ReadData.DefineData('Report_ID', 'Depends_on', 'Run_Layer');	  
 		ReadData.DefineDone();		 
 		 		
 		* Declare Iterator to Move through data until every report is assigned a layer ;
  		Declare Hiter AssignLayer('ReadData');
  		
  		* Declare Hash to Write out Updates to Layers ;
        Declare Hash WriteData(Ordered: 'Descending'); 
   		WriteData.Definekey('Run_Layer', 'Report_ID'); 
   		WriteData.DefineData('Report_ID', 'Run_Layer', 'Depends_On'); 
   		WriteData.DefineDone();	 
   		
   		Declare Hiter ReadLayer('WriteData');
   		
   		Call Missing(of _ALL_);
	 	
	 	** Here we will build a matrix of Report_IDs based on Report_IDs and their dependencies           ;
	 	** Starting from Layer 1 (Sequence) we assign those that have no dependencies                     ;
	 	** Thereafter we check that each Report_IDs dependencies have been assigned a Run_Layer (sequence);
	 	** If all of a Reports dependencies have been assigned a sequence then the Report_ID must be the  ;
	 	** highest dependency sequence + 1, example 
	 	Report_ID: 1, Depends_On: 2|3 --- Cannot run until 2 & 3 have completed
	 	Report_ID: 2, Depends_On:     --- Can run first, no dependencies
	 	Report_ID: 3, Depends_On: 2   --- Cannot run until 2 has completed
	 	Will output as
	 	Run_Layer: 3, Report_ID: 1
	 	Run_Layer: 2, Report_ID: 3
	 	Run_Layer: 1, Report_ID: 2 
	 	;
	 	** Word of warning, circular dependencies will not be assigned a Run_Layer ;
	  
		Num_UnAssignedItems=ReadData.Num_Items; * Number of unique Report_IDs to work with ;
		Assign_Run_Layer=1;                     * The start value to assign ;
		
	 	Do Assign_Run_Layer=1 to Num_UnAssignedItems; * We could potentially assign unique Run_Layers to all Report_IDS ;
	 		AL_RC=AssignLayer.First();                * First Round will be assigned Run_Layer 1, second 2, third...    ;
		
			Do Until(AL_RC ne 0); 
				If Depends_on='' And Run_Layer eq 0 Then Do; * $$ ;
				    *** Only Layer 1 will ever be assigned here - Other items will have a dependency *** ;
	 				Run_Layer=Assign_Run_Layer; 
					RP_RC=ReadData.Replace(); 
				End;
				Else If Run_Layer eq 0 Then Do; * Does not have a an assigned Run_Layer yet ;
	 				Dependency_Num=Sum(Count(Depends_on,'|'), Anydigit(Depends_on));
	                * If the Can Assign number Equals Number of Dependency then we can give this a Layer number ;
	 			    Can_Assign_Layer=0; 
	 				Do Scan_DepIter = 1 To Dependency_Num; 
						CheckThisDep=Input(Scan(Depends_on, Scan_DepIter , '|'), 8.);  * Depends_On is split by pipe |;
					
						* Keep Original Values while we scan each dependency ;
						__Report_ID=Report_ID; 
	 					__Run_Layer=Run_Layer;
	 					__Depends_on=Depends_on; 
	 					
						*** Dependency Logic *** ; 
						* an assigned Run_Layer ^0 means we can use the dependency ;
						CK_RC=ReadData.Find(Key: CheckThisDep);
						
						* Not already assigned a layer & dependancy assignment cannot be in current same layer ;
						If Run_Layer ne 0 and Run_Layer ne Assign_Run_Layer Then Can_Assign_Layer+1;
										
						Report_id=__Report_ID;
						Run_Layer=__Run_Layer; 
						Depends_on=__Depends_on;
						
	 					If Can_Assign_Layer=Dependency_Num Then Do;  * Same as $$ ;
	 						Run_Layer=Assign_Run_Layer; 
	 						RP_RC=ReadData.Replace(); 
	 					End; 
	 				End; 
	 			End; 
				AL_RC=AssignLayer.Next();
			End;
	 	End; 
		
		/* Created a Decending list of Reports to Assign to Groups */
		/* Why descending by Run_Layer? Because it is the most efficient route to calculate what reports run together */
		AL_RC=AssignLayer.First();
		Do Until(AL_RC ne 0);
			If Run_Layer^=0 Then Write_RC=WriteData.Add(); * Those that we could not assign we do not Group ;
			AL_RC=AssignLayer.Next();
		End;
		** COMPLETED ** List of Report_IDs with their Run_Layers ;
		Rc_CleanUp=ReadData.Delete();
		
		* Part two of dynamic assignment - Run_Groups ;
		* Step 1 Build multiple hierarchies through each layer from the top ;
		* Each instance will be a string of related Report_ID + Sequencially assigned Run_Groups ;
		* Why split Report_IDs into Run_Groups? We groups together sequences that must run together ;
		* to avoid indirect dependecnies between Report_IDs ; 
		* Example:(build from previous example 
		Report_ID: 4, Depends_On: 5
		Report_ID: 5, Depends_On:
		Output (with previous example:
		Run_Layer: 3, Report_ID: 1
	 	Run_Layer: 2, Report_ID: 3 & 4
	 	Run_Layer: 1, Report_ID: 2 & 5
	 	In this scenario we can only run Reports 3 & 4 when BOTH Reports 2 & 5 have completed 
	 	Report 1 can only run when BOTH 3 & 4 have completed, but if split them by groups the problem is gone
		Run_Group: 1
		Run_Layer: 3, Report_ID: 1
	 	Run_Layer: 2, Report_ID: 3
	 	Run_Layer: 1, Report_ID: 2
		Run_Group: 2
	 	Run_Layer: 2, Report_ID: 4
	 	Run_Layer: 1, Report_ID: 5
		* Word of Warning Avoid Run_Layer=0 - means it could not be assigned a layer ;

		* A) Create a Hash of Hashes - we store each group of related Report_IDs in their own hash table      ;
		* B) Create a Temporary Parent Child Hash to map related Report_IDs                                   ;
		* C) Create Final Hash table that will contain consolidated list of Report_ID + Run_Layer + Run_Group ;
		Declare Hash HashofHashes(Ordered: 'Yes');     ** (A) ** ;
		Declare Hiter HOHIter('HashofHashes');
		HashofHashes.DefineKey('Run_Group');
		HashofHashes.DefineData('Run_Group', 'ReportList', 'ReportListIter');
		HashofHashes.DefineDone();
		
		Declare Hash ReportList(); ** Belongs to HOH ;
 		Declare Hiter ReportListIter('ReportList');
 		
 		Declare Hash TempParentChild(Ordered: 'Yes');  ** (B) ** ;
 		TempParentChild.DefineKey('RowCount', 'Parent', 'Child'); * RowCount is used to maintain a order        ;
 		TempParentChild.DefineData('RowCount', 'Parent', 'Child'); * So we do not miss record building the tree ;
 		TempParentChild.DefineDone();	
 		Declare HIter TempParentIter('TempParentChild');
 		Declare HIter TempChildIter('TempParentChild');
 		
 		Declare Hash Cloud(); * We may encounter top Report_ID of a tree already given a Run_Group ;
 		Cloud.DefineKey('Report_ID'); * For those we do not need to give a Run_Group ;
 		Cloud.DefineData('Report_ID'); * Because they already have a parent they must have been assigned a Run_Group elsewhere ;
 		Cloud.DefineDone(); * This is simply to reduce the number of String table instances we have ; 
 		
 		Declare Hash FinalUpdateTable(Ordered: 'Yes'); ** (C) ** ;
 		FinalUpdateTable.DefineKey('Run_Group', 'Run_Layer', 'Report_ID');
 		FinalUpdateTable.DefineData('Run_Group', 'Run_Layer', 'Report_ID');
 		FinalUpdateTable.DefineDone();
 		
 		** We begin by processing Report_ID & Run_Layer from the Top ;
 		** That is descending by Run_Layer 
 		- moving down a sequence (tree) allows us to assign bigger Run_Groups at a time ;
 		
 		Run_Group=0;
		RL_RC=ReadLayer.First();                                         ** First one on the Assign Run_Layer List; 
		MaxRun_Layer=Run_Layer;                                          ** Hash is sorted on descending Run_Layer ;
 		Do Until(RL_RC ne 0); 
 			* Does the Top entry already Exist in the Cloud ? ;
 			CloudFind_RC=Cloud.Find();
 			If CloudFind_RC ne 0 Then Do;
				Clear_RC=TempParentChild.Clear();
				RowCount=0;
		
				** Load to Temporary Parent Child table ** Logic Code: ## Hash: (B) ;
				If Depends_on='' Then Depends_on='0';                            ** Hash does not allow blank keys ;
				Dependency_Num=Sum(Count(Depends_on,'|'), Anydigit(Depends_on)); ** Pipe delimited, loop through each ;
				Do __Iter = 1 To Dependency_Num;
					Find_Dep=Input(Scan(Depends_on, __Iter, '|'), 8.);           ** Each Dependency is pipe delimited ;
					RowCount+1;
					Rc=TempParentChild.Add(Key: RowCount, Key: Report_ID, Key: Find_Dep
		                                , Data: RowCount, Data: Report_ID, Data: Find_Dep);
		            Rc_Cloud=Cloud.Add(Key: Report_ID, Data: Report_ID);
		            Rc_Cloud=Cloud.Add(Key: Find_Dep, Data: Find_Dep);
				End;
				** Now add the related record to build a dependency tree ;
				P_RC=TempParentIter.First();
				C_RC=TempChildIter.First();
				
				Do Until(P_RC ne 0);
					FindChild=Child;
					Found=0;
					Do Until(C_RC ne 0); * Loop child through Parent to see if the child has already been rolled out and assigned ;
						If FindChild=Parent Then Do;
							Found=1;
							C_RC=1;
						End;
						C_RC=TempChildIter.Next();
					End;
					If Found=0 Then Do; * if the Child record is not found then we add it;
						* We do not know which layer in this context so we check them all ;
						Do Descending_Run_Layer = MaxRun_Layer to 0 By -1; 
							FindChild_RC=WriteData.Find(Key: Descending_Run_Layer, Key: FindChild);
							If FindChild_RC eq 0 Then Do;
								Descending_Run_Layer=0; * We found the child - exit loop clause ;
								
								** Same as ## ** ;
								If Depends_on='' Then Depends_on='0'; 
								Dependency_Num=Sum(Count(Depends_on,'|'), Anydigit(Depends_on));
								Do __Iter = 1 To Dependency_Num;
									Find_Dep=Input(Scan(Depends_on, __Iter, '|'), 8.); 
									RowCount+1;			
									Rc=TempParentChild.Add(Key: RowCount, Key: Report_ID, Key: Find_Dep
						                                , Data: RowCount, Data: Report_ID, Data: Find_Dep);
						            Rc_Cloud=Cloud.Add(Key: Report_ID, Data: Report_ID);
						            Rc_Cloud=Cloud.Add(Key: Find_Dep, Data: Find_Dep);					                                
								End;
							End;
						End;
					End;
					P_RC=TempParentIter.Next();
				End;	
				%If &Debug.=Y %Then %Do;
					%Put NOTE: Debug switch was set to &Debug., output temporary Parent Child Tables for viewing ;
					Temp_Cnt+1;
					TempDebug_RC=TempParentChild.Output(Dataset: 'Debug_TempParentChild' || Put(Temp_Cnt, Best. -L));
				%End;
				
				** For Each loaded TempParentChild table populate an instance of HOH ;			
				ReportList= _new_ Hash(ordered: 'Yes'); * must use this method to instantiate Hash of Hash ;
				ReportList.DefineKey('Report_ID', 'Run_Group');
				ReportList.DefineData('Report_ID', 'Run_Group', 'Reassigned_Run_Group');
				ReportList.DefineDone();
		
				ReportListIter= _new_ HIter('ReportList'); * Slowly builds PC table ;
				Run_Group+1;
				RC=HashofHashes.Add(); * Add new instance to HOH ;
				
				RCP=TempParentIter.First();
				Do Until(RCP ne 0);
					If Parent ne 0 Then RCF=ReportList.Add(Key: Parent, Key: Run_Group,
					                                      Data: Parent, Data: Run_Group, Data: 0);
					If Child ne 0 Then RCF=ReportList.Add(Key: Child, Key: Run_Group, 
					                                     Data: Child, Data: Run_Group, Data: 0);
					RCP=TempParentIter.Next();                 
				End;
				End;	
			RL_RC=ReadLayer.Next(); * Next descending by Run_Layer item ; 
		End;
		** We now have Multiple instances of String Tables, EG: Report_IDs: 14-13-12-11-4-0  ;
		** Drop the Cloud ;
		Rc_Delete=Cloud.Delete();
				
		** Now starting from the Left we run a comparison of the left against the next right ;
		* Populate Reassign_Run_Group if there are matches & Reassign_Run_Group eq 0         ;
		* If Reassign_Run_Group has a value then use that as the Run_Group                   ;	
		* Back populate all instances if reassigned already                                  ;
		* Create Temp Hash - easier to manage variables this way                             ;	

		Declare Hash TempReportList(ordered: 'Yes');
		TempReportList.DefineKey('Report_ID', 'Run_Group'); * Use Run_Group as a placeholder ;
		TempReportList.DefineData('Report_ID', 'Run_Group', 'Reassigned_Run_Group');
		TempReportList.DefineDone();
		Declare HIter TempReportListIter('TempReportList');
	
		HOH_RC=HOHIter.First(); ** Starting on the Left ;
  		Do Until(HOH_RC ne 0);  
			** Load to Temp Structure ;
			Load_RC=ReportListIter.First();
			Do Until(Load_RC ne 0);
				Load_RC=TempReportList.Add();
				Load_RC=ReportListIter.Next();
			End; * At completion we want to grab the current Run_Group ;
			Placeholder_Run_Group=Run_Group; * This tracks where we are in HOH ;
			If Reassigned_Run_Group=0 Then Current_Run_Group=Run_Group; * This helps assign the correct Run_Group ;
			Else Current_Run_Group=Reassigned_Run_Group;
			HOH2_RC=HOHIter.Next(); ** Next String Table to Check ;
			Do Until(HOH2_RC ne 0);
				** Go to top of Temp table and check against each entry in the String Table ;
				RC_Temp=TempReportListIter.First();
				Found=0;
				Do Until(RC_Temp ne 0 or Found);
					Check_Report_ID=Report_ID;
					RC_InstanceList=ReportListIter.First();
					Do Until(RC_InstanceList ne 0 or Found);
						If Check_Report_ID= Report_ID Then Found=1;
						RC_InstanceList=ReportListIter.Next();
					End;
					If Found Then Do; * Reassign Run_Groups ;
						RC_Reset=ReportListIter.First();
						Do Until(RC_Reset ne 0);
							Reassigned_Run_Group=Current_Run_Group;
							RC_Replace=ReportList.Replace();
							** Also add them to the temp table so we can reassign more Run_Groups ;
							Load_RC=TempReportList.Add(Key: Report_ID, Key: Reassigned_Run_Group,
							                          Data: Report_ID, Data: Reassigned_Run_Group, Data: Reassigned_Run_Group);
							RC_Reset=ReportListIter.Next();
						End;
						TempReportListIter.Last();
					End;
					RC_Temp=TempReportListIter.Next();
				End;
				HOH2_RC=HOHIter.Next();
			End;
			RC_Clear=TempReportList.Clear();
			
			** Go Back to where we were from the Left ;
			HOH_GoBackRC=HOHIter.First();
			Do While(Placeholder_Run_Group ne Run_Group);
				HOH_GoBackRC=HOHIter.Next();
			End;
			HOH_RC=HOHIter.Next(); ** Going to the Right ;
		End;
		
		** Finally we Consolidate Run_Layer and Run_Group together and load them into a Final Update Table;
		FinalHOH_RC=HOHIter.First();
		Do Until(Final_RC ne 0);
			FinalHOHIter_RC=ReportListIter.First();
			*** Display for Debugging *** ;
			%If &Debug.=Y %Then %Do;
				%Put NOTE: Debug switch was set to &Debug., output each Hash of Hash instance for viewing ;
				Debug_RC=ReportList.Output(dataset: 'Debug_HashofHash' || Put(Run_Group, Best.-L));
			%End;

			Do Until(FinalHOHIter_RC ne 0);
				Do Descending_Run_Layer = MaxRun_Layer to 0 By -1;
					FindChild_RC=WriteData.Find(Key: Descending_Run_Layer, Key: Report_ID);
					If FindChild_RC=0 Then Descending_Run_Layer=0;
				End;

				If Reassigned_Run_Group ne 0 Then Run_Group=Reassigned_Run_Group; * Adjust for reassignment ;
				Update_RC=FinalUpdateTable.Add();
				
				FinalHOHIter_RC=ReportListIter.Next();
			End;
			Final_RC=HOHIter.Next();
		End;
		
		/* Final Solution */
		RC_Out=FinalUpdateTable.Output(dataset: 'Work.Update');		
	Run;

    **** Step 5: Update table with Run_Layers and Run_Groups ;
	data RN_Report_Schedule;
		Set Update(Rename=(Run_Group=__Run_Group Run_Layer=__Run_Layer));
		Modify RN_Report_Schedule Key=Report_ID;
		if _IORC_ = %SYSRC(_SOK) then do;
			Run_Group=__Run_Group;
			Run_Layer=__Run_Layer;
			Replace;
		End;
	Run;

	*** Step 6: *** - if a dependency is on itself then drop it **** ;
	Data RN_Report_Schedule(Drop=Msg) 
         Email_SelfDep(Keep=Report_ID Email_Notification Report_Name Msg Depends_On);
		Length Msg $256.;
		Set RN_Report_Schedule;
		If Run_Layer=0 Then Do;
			Msg=Compbl("Report id dependency problem. Either a Report's dependency cannot run today or there is a circular dependency, Report_ID="|| Report_ID 
                    ||" Report_Name= "|| Report_Name || " Depends_On=" || Depends_On);
			Output Email_SelfDep;
		End;
		Else Output RN_Report_Schedule;
	Run;

	%End;

    **** Step 7: Repopulate Table DI Studio Schedule Table - this will drive what runs ;
	Proc SQL Noprint; 
	 	Delete from RN_Cntl.RN_Report_Schedule; 
	Quit; 
	Proc Append Base=RN_Cntl.RN_Report_Schedule 
                Data=RN_Report_Schedule(Drop=Run_Date Run_Day Work_Days_Only); 
	Quit;
	%If &Debug.^=Y %Then %Do; 
		Proc Datasets Lib=Work NoList NoDetails;
	 	 	Delete RN_Report_Schedule Update FMT Run_Group_Update;  
		Quit;
	%End;

	**** Step 8: Email where we found issues ;
	%Let Send_Max=0;

	** Separate Emails into one per Email Address ** ;
	Data Email_All;
		Set EMAIL_MESSAGE Email_Delay Email_Stopped &Email_SelfDep.;
		Num_Emails=Sum(Count(Strip(Email_Notification), ' '), 1);
		Do F=1 To Num_Emails;
			EmailW=Compress(Scan(Email_Notification, F, ' '), '"');
			Email=Scan(Email_Notification, F, ' ');
			Output;
		End;
		Where Email_Notification ne ' ';
	Run;
	Proc SQl Noprint;
		Select Strip(Put(Count(Unique(Email)), 8.)) Into :Max_Emails
		From Email_All;
		%If &Max_Emails.>0 %Then %Do;
			Select Distinct Email, EmailW 
                      Into :Send_Email_1-:Send_Email_&Max_Emails. 
			             , :Send_EmailW_1-:Send_EmailW_&Max_Emails. 
			From Email_All;
		%End;
	Quit;
	%If &Debug.^=Y %Then %Do;
		Proc Datasets Lib=Work Nolist Nodetails;
	 		Delete EMAIL_MESSAGE Email_Delay Email_SelfDep Email_Stopped; 
		Quit;
	%End;
	%Put Max_Emails = &Max_Emails.;

	%Do S=1 %To &Max_Emails.;
		Filename Outf email to=(&&Send_Email_&S.)
		Subject="RN Unable to Schedule report" 
		type='text/html'
        Importance='HIGH';

		Data _NULL_;
			File Outf;
			Set Email_All End=End;

			If _N_=1 Then Do;
	            Put '<HTML><HEAD>';
	            Put '<STYLE TYPE="TEXT/CSS" MEDIA=SCREEN><!--';
	            Put 'BODY { COLOR: BLACK; FONT-FAMILY: ARIAL; FONT-SIZE: 10PT; }';
	            Put '.ERRORMESSAGE { COLOR: RED; FONT-SIZE: 8PT; }';
	            Put '--></STYLE></HEAD><BODY>';
	            Put "Hi,<BR /><BR /> Please note that the following Scheduled Reports will not run due to invalidations <BR /><BR />";
			End;

    		Put "<BR />Report ID: " Report_ID;
			Put "<BR />Report Name: " Report_Name;
			Put "<BR />Issue: <BR /><font color='red'> " Msg;
            Put '<BR/><BR/><font color="black">';

			If End Then Do;
	            Put "Regards,<BR/><BR/>";
	            Put '</BODY></HTML>';
			End;
			Where EmailW in ("&&Send_EmailW_&S.");
		Run;

	%End;

	%If &Debug.^=Y %Then %Do;
		Proc Datasets Lib=Work Nolist Nodetails;
	 		Delete Email_All ; 
		Quit;
	%End;

	%rn_unhide_code;
%Mend;

