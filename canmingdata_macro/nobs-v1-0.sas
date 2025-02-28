/*************************************************************************************************
File name: nobs-v1-0.sas

Study:

SAS version: 9.4

Purpose: return the number of records in dataset

Macros called:

Notes:

Parameters: ds

Sample: %nobs(class);

Date started: 13JUL2023
Date completed: 13JUL2023

**Per QA request, please update the modification history follow the format in the 1st line.**

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 13JUL2023 hao.guo create
************************************ Prepared by Highthinkmed ************************************/
%macro nobs(ds) / store;
%local nobs dsid rc err;
%let err=ERR%str(OR);
%let dsid=%sysfunc(open(&ds));
%if &dsid EQ 0 %then %do;
%put &err: (nobs) Dataset &ds not opened due to the following reason:;
%put %sysfunc(sysmsg());
%end;
%else %do;
%if %sysfunc(attrn(&dsid,WHSTMT)) or %sysfunc(attrc(&dsid,MTYPE)) EQ VIEW %then %let nobs=%sysfunc(attrn(&dsid,NLOBSF));
%else %let nobs=%sysfunc(attrn(&dsid,NOBS));
%let rc=%sysfunc(close(&dsid));
%if &nobs LT 0 %then %do; %let nobs=0;%end;
&nobs
%end;
%mend;
