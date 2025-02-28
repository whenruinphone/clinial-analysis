/*************************************************************************************************
File name: m-var-type-v1-0.sas

Study:

SAS version: 9.4

Purpose: return C if a variable type is Character
return N if a variable type is Numberic

Macros called:

Notes:

Parameters:
inds=
Specifies the input data set.
Required.
varname=
Specifies the variable name.
Required.

Sample: %m_var_type(data,var_length);

Date started: 27SEP2011
Date completed: 27SEP2011

**Per QA request, please update the modification history follow the format in the 1st line.**

Mod Date Name Description
--- ----------- ------------ -----------------------------------------------
1.0 24AUG2023 Hao.Guo Create

************************************ Prepared by GCP Highthinkmed ************************************/

%macro m_var_type(inds /** dataset name **/
,varname /** variable name need get the type **/
) / store;

%local errnum errmsg;
%let errnum = 0;
/**-----------------------------------------
verify macro paramerers
------------------------------------------**/
%if %length(&inds) eq 0 or %length(&varname) eq 0 %then %do;
%let errnum = 1;
%let errmsg = macro parameters(inds varname) can not be null;
%goto mexit;
%end;

%if %sysfunc(exist(&inds)) %then %do;
%let dsid = %sysfunc(open(&inds, i));
%let varnum = %sysfunc(varnum(&dsid, &varname));
%if &varnum %then %do;
%sysfunc(vartype(&dsid, &varnum))
%end;
%else %do;
%let errnum = 1;
%let errmsg = variable (&varname) does not exist in the dataset(&inds);
%let rc = %sysfunc(close(&dsid));
%goto mexit;
%end;
%let rc = %sysfunc(close(&dsid));
%end;
%else %do;
%let errnum = 1;
%let errmsg = data set (&inds) does not exist;
%goto mexit;
%end;

%mexit:
%if &errnum %then %do;
%put ERROR: &errmsg;
%put ERROR: exit macro(m_var_type) because of error;
%end;

%mend m_var_type;