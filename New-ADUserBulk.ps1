# Author:		Michael Nye
# Date:         09-09-2013
# Script Name:  New-ADUserBulk
# Version:      1.0
# Description:  Script to create new user objects in Active Directory.
# Change Log:	v1.0:	Initial Release

# ------------------- NOTES -----------------------------------------------
# SAMPLE INPUTFILE
# --- First row is the column headers and must match below!
# --- Values with commas or space must be in quotes " ".
# --- Inputfile name should match script name and be located in same directory as script.
# -------------------------------------------------------------------------
# sAMAccountName,FirstName,LastName,DisplayName,Description,UPN,OU,Password,ChangePass,Enabled
# TestUser1,Test,User1,TestUser1,TestUser1,TestUser1@mydomain.com,"OU=Users,DC=mydomain,DC=com",Password123,TRUE,TRUE
#
# INPUTFILE HEADER		VALUES							MAPPING
# ----------------		------							-------
# sAMAccountName		TestUser1						sAMAccountName
# FirstName				Test							givenName
# LastName				User							sn
# DisplayName			"TestUser1"						displayName
# Description			"TestUser1"						description
# UPN					TestUser1@mydomain.com			userPrincipalName
# OU					OU=Users,DC=mydomain,DC=com		(location to create user object)
# Password				TestPassword1							
# ChangePass			TRUE/FALSE						Force user to change password at next logon/or not
# Enabled				TRUE/FALSE						Enable/Disable account
# -------------------------------------------------------------------------

# ------------------- IMPORT AD MODULE (IF NEEDED) ------------------------
Import-Module ActiveDirectory


# ------------------- BEGIN USER DEFINED VARIABLES ------------------------
$SCRIPTNAME    	= "New-ADUserBulk"
$SCRIPTVERSION 	= "1.0"

# Server attribute to set which domain to create users
$domainFQDN     = "mydomain.com"

# ------------------- END OF USER DEFINED VARIABLES -----------------------


# ------------------- BEGIN MAIN SCRIPT VARIABLES -------------------------
# Establish variable with date/time of script start
$Scriptstart = Get-Date -Format G

$strCurrDir 	= split-path $MyInvocation.MyCommand.Path
$strLogFolder 	= "$SCRIPTNAME -{0} {1}" -f ($_.name -replace ", ","-"),($Scriptstart -replace ":","-" -replace "/","-")
$strLogPath 	= "$strCurrDir\logs"
$INPUTFILE 		= "$strCurrDir\$SCRIPTNAME.csv"

# Create log folder for run and logfile name
New-Item -Path $strLogPath -name $strLogFolder -itemtype "directory" -Force > $NULL
$LOGFILE 		= "$strLogPath\$strLogFolder\$SCRIPTNAME.log"

# ------------------- END MAIN SCRIPT VARIABLES ---------------------------


# ------------------- DEFINE FUNCTIONS - DO NOT MODIFY --------------------

Function Writelog ($LogText)
{
	$date = Get-Date -format G
	
    write-host "$date $LogText"
	write-host ""
	
    "$date $LogText" >> $LOGFILE
	"" >> $LOGFILE
}

Function GetString ($obj)
{
	if($null -eq $obj)
	{
		return ''
	}
	
	$string = $obj.ToString()
	return $string.Trim()
}

Function BeginScript () {
    Writelog "-------------------------------------------------------------------------------------"
    Writelog "**** BEGIN SCRIPT AT $Scriptstart ****"
    Writelog "**** Script Name:     $SCRIPTNAME"
    Writelog "**** Script Version:  $SCRIPTVERSION"
    Writelog "**** Input File:      $INPUTFILE"
    Writelog "-------------------------------------------------------------------------------------"

    $error.clear()
}

Function EndScript () {
    Writelog "-------------------------------------------------------------------------------------"
    Writelog "**** SCRIPT RESULTS ****"
    Writelog "**** SUCCESS Count = $CountSuccess"
    Writelog "**** ERROR Count   = $CountError"
    Writelog "-------------------------------------------------------------------------------------"

	$Scriptfinish = Get-Date -Format G
	$span = New-TimeSpan $Scriptstart $Scriptfinish
	
  	Writelog "-------------------------------------------------------------------------------------"
  	Writelog "**** $SCRIPTNAME script COMPLETED at $Scriptfinish ****"
	Writelog $("**** Total Runtime: {0:00} hours, {1:00} minutes, and {2:00} seconds ****" -f $span.Hours,$span.Minutes,$span.Seconds)
	Writelog "-------------------------------------------------------------------------------------"
}

# ------------------- END OF FUNCTION DEFINITIONS -------------------------


# ------------------- SCRIPT MAIN - DO NOT MODIFY -------------------------

BeginScript

$CountError = 0
$CountSuccess = 0


Import-Csv $INPUTFILE | ForEach-Object -Process {

	# Check to see if the user already exists before trying to create
	Try
	{
		$exists = Get-ADUser -Server $domainFQDN -LDAPFilter "(sAMAccountName=$($_.sAMAccountName))"
	}
	Catch { }
	
	If (!$exists)
	{
		$samName 		= GetString($_.sAMAccountName)
		$givenName 		= GetString($_.FirstName)
		$surname 		= GetString($_.LastName)
		$displayName 	= GetString($_.DisplayName)
		$description 	= GetString($_.Description)
		$upn 			= GetString($_.UPN)
		$ou 			= GetString($_.OU)
		$pass 			= ConvertTo-SecureString -AsPlainText $_.Password -Force
		$changePass 	= GetString($_.ChangePass)
		$isEnabled 		= GetString($_.Enabled)
		$name 			= GetString($_.sAMAccountName)
		
		# Check if account should be enabled and convert
		If ($isEnabled.ToUpper() -eq "TRUE")
		{
			$Enabled = $true
		}
		Else
		{
			$Enabled = $false
		}
		
		# Check if user must change password at logon
		If ($changePass.ToUpper() -eq "TRUE")
		{
			$ChangePW = $true
		}
		Else
		{
			$ChangePW = $false
		}
		
		# Create user object and populate attributes based off the input CSV.
		$user = New-ADUser -Server $domainFQDN -SamAccountName $samName -Name $name -GivenName $givenName -Surname $surname -DisplayName $displayName -Description $description -UserPrincipalName $upn -Path $ou -Enabled $Enabled -AccountPassword $pass -ChangePasswordAtLogon $ChangePW
		
		Writelog $("SUCCESS	Account created: " + $samName)
		$CountSuccess++
	}
	
	Else
	{
		Writelog $("ERROR	Account already exists.  sAMAccountName: " + $_.sAMAccountName)
		$CountError++
	}
}


# ------------------- END OF SCRIPT MAIN ----------------------------------


# ------------------- CLEANUP ---------------------------------------------


# ------------------- SCRIPT END ------------------------------------------
$error.clear()

EndScript
