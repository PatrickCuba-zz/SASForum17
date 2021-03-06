/***************************************************************************************/
/***************************************************************************************/
/****  Program Name   *   BT Send email                                             ****/
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

%Macro rn_report_save_history;

	%RN_LockDS(DS=RN_CNTL.RN_REPORT_SCHEDULE);
		%RN_LockDS(DS=RN_CNTL.RN_Report_Schedule_History);

	Proc Append Base=RN_Cntl.RN_Report_Schedule_History Data=RN_Cntl.RN_Report_Schedule;
	Quit;

		%RN_UnLockDS(DS=RN_CNTL.RN_Report_Schedule_History);
	%RN_UnLockDS(DS=RN_CNTL.RN_REPORT_SCHEDULE);
%Mend;
