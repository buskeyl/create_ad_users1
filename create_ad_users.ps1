



###########################################################
# AUTHOR  : Lee H Buskey.   
# AUTHOR  : Based off script made by Marius / Hican - http://www.hican.nl - @hicannl 
# DATE    : 26-04-2012 
# EDIT    : 02-29-2016
# COMMENT : This script creates new Active Directory users,
#           including different kind of properties, based
#           on an input_create_ad_users.csv.
# VERSION : 1.5
###########################################################

# CHANGELOG
# Version 1.5: 2-28-2016
# - Corrected several things that just did not work.  
# - Removed some unnecessary features for the CDF2
# - moved password feature from the CSV file to a random password generator function
# - Removed account attributes that we don't use, which were causing errors if enpty.  
# - Modified fomr the initial use of a logon name based on first and last name to an EmployeeID SamAccountNAme. 
# - Added user email notification 
# - Replaced Write-Host commands with Write-Output commands


# Version 1.2: 15-04-2014 - Changed the code for better
# - Added better Error Handling and Reporting.
# - Changed input file with more logical headers.
# - Added functionality for account Enable
#   PasswordNeverExpires, ProfilePath, ScriptPath,
#   HomeDirectory and HomeDrive
# - Added the option to move every user to a different OU.
# Version 1.3: 08-07-2014
# - Added functionality for ProxyAddresses

# ERROR REPORTING ALL
Set-StrictMode -Version latest

#----------------------------------------------------------
# LOAD ASSEMBLIES AND MODULES
#----------------------------------------------------------
Try
{
  Import-Module ActiveDirectory -ErrorAction Stop
}
Catch
{
  Write-Output "[ERROR]`t ActiveDirectory Module couldn't be loaded. Script will stop!"
  Exit 1
}

#----------------------------------------------------------
#STATIC VARIABLES
#----------------------------------------------------------
$path     = Split-Path -parent $MyInvocation.MyCommand.Definition
$newpath  = $path + "\import_create_ad_users.csv"
$log      = $path + "\create_ad_users.log"
$profile  = "\\cdf2-netapp\homedir\UserProfiles\"
$homedir  = "\\cdf2-netapp\homedir\User_data\"
$date     = Get-Date
$addn     = (Get-ADDomain).DistinguishedName
$dnsroot  = (Get-ADDomain).DNSRoot
$i        = 1
$PSEmailServer = "mail.csn.internal"								
$from = "noreply@cdf2.usae.bah.com"									 





#----------------------------------------------------------
#START FUNCTIONS
#----------------------------------------------------------

Function Get-RandomString

{
# Get-RandomString.ps1
# Written by Bill Stewart (bstewart@iname.com)

#requires -version 2

<#
.SYNOPSIS
Outputs random strings.

.DESCRIPTION
Outputs one or more random strings containing specified types of characters.

.PARAMETER Length
Specifies the length of the output string(s). The default value is 8. You cannot specify a value less than 4.

.PARAMETER LowerCase
Specifies that the string must contain lowercase ASCII characters (default). Specify -LowerCase:$false if you do not want the random string(s) to contain lowercase ASCII characters.

.PARAMETER UpperCase
Specifies that the string must contain upercase ASCII characters.

.PARAMETER Numbers
Specifies that the string must contain number characters (0 through 9).

.PARAMETER Symbols
Specifies that the string must contain typewriter symbol characters.

.PARAMETER Count
Specifies the number of random strings to output.

.EXAMPLE
PS C:\> Get-RandomString
Outputs a string containing 8 random lowercase ASCII characters.

.EXAMPLE
PS C:\> Get-RandomString -Length 14 -Count 5
Outputs 5 random strings containing 14 lowercase ASCII characters each.

.EXAMPLE
PS C:\> Get-RandomString -UpperCase -LowerCase -Numbers -Count 10
Outputs 10 random 8-character strings containing uppercase, lowercase, and numbers.

.EXAMPLE
PS C:\> Get-RandomString -Length 32 -LowerCase:$false -Numbers -Symbols -Count 20
Outputs 20 random 32-character strings containing numbers and typewriter symbols.

.EXAMPLE
PS C:\> Get-RandomString -Length 4 -LowerCase:$false -Numbers -Count 15
Outputs 15 random 4-character strings containing only numbers.
#>

param(
  [UInt32] $Length=8,
  [Switch] $LowerCase=$TRUE,
  [Switch] $UpperCase=$FALSE,
  [Switch] $Numbers=$FALSE,
  [Switch] $Symbols=$FALSE,
  [Uint32] $Count=1
)

if ($Length -lt 4) {
  throw "-Length must specify a value greater than 3"
}

if (-not ($LowerCase -or $UpperCase -or $Numbers -or $Symbols)) {
  throw "You must specify one of: -LowerCase -UpperCase -Numbers -Symbols"
}

# Specifies bitmap values for character sets selected.
$CHARSET_LOWER = 1
$CHARSET_UPPER = 2
$CHARSET_NUMBER = 4
$CHARSET_SYMBOL = 8

# Creates character arrays for the different character classes,
# based on ASCII character values.
$charsLower = 97..122 | foreach-object { [Char] $_ }
$charsUpper = 65..90 | foreach-object { [Char] $_ }
$charsNumber = 48..57 | foreach-object { [Char] $_ }
$charsSymbol = 35,36,42,43,44,45,46,47,58,59,61,63,64,
  91,92,93,95,123,125,126 | foreach-object { [Char] $_ }

# Contains the array of characters to use.
$charList = @()
# Contains bitmap of the character sets selected.
$charSets = 0
if ($LowerCase) {
  $charList += $charsLower
  $charSets = $charSets -bor $CHARSET_LOWER
}
if ($UpperCase) {
  $charList += $charsUpper
  $charSets = $charSets -bor $CHARSET_UPPER
}
if ($Numbers) {
  $charList += $charsNumber
  $charSets = $charSets -bor $CHARSET_NUMBER
}
if ($Symbols) {
  $charList += $charsSymbol
  $charSets = $charSets -bor $CHARSET_SYMBOL
}

# Returns True if the string contains at least one character
# from the array, or False otherwise.
function test-stringcontents([String] $test, [Char[]] $chars) {
  foreach ($char in $test.ToCharArray()) {
    if ($chars -ccontains $char) { return $TRUE }
  }
  return $FALSE
}

1..$Count | foreach-object {
  # Loops until the string contains at least
  # one character from each character class.
  do {
    # No character classes matched yet.
    $flags = 0
    $output = ""
    # Create output string containing random characters.
    1..$Length | foreach-object {
      $output += $charList[(get-random -maximum $charList.Length)]
    }
    # Check if character classes match.
    if ($LowerCase) {
      if (test-stringcontents $output $charsLower) {
        $flags = $flags -bor $CHARSET_LOWER
      }
    }
    if ($UpperCase) {
      if (test-stringcontents $output $charsUpper) {
        $flags = $flags -bor $CHARSET_UPPER
      }
    }
    if ($Numbers) {
      if (test-stringcontents $output $charsNumber) {
        $flags = $flags -bor $CHARSET_NUMBER
      }
    }
    if ($Symbols) {
      if (test-stringcontents $output $charsSymbol) {
        $flags = $flags -bor $CHARSET_SYMBOL
      }
    }
  }
  until ($flags -eq $charSets)
  # Output the string.
  $output
}




}




Function Start-Commands
{
  Create-Users
}

Function Create-Users
{
  "Processing started (on " + $date + "): " | Out-File $log -append
  "--------------------------------------------" | Out-File $log -append
  Import-CSV $newpath | ForEach-Object {
    If (($_.Implement.ToLower()) -eq "yes")
    {
      If (($_.GivenName -eq "") -Or ($_.LastName -eq "") -Or ($_.EmployeeID -eq ""))
      {
        Write-Output "[ERROR]`t Please provide valid GivenName, LastName and EmployeeID. Processing skipped for line $($i)`r`n"
        "[ERROR]`t Please provide valid GivenName, LastName and Initials. Processing skipped for line $($i)`r`n" | Out-File $log -append
      }
      Else
      {
        # Set the target OU
        $location = $_.TargetOU + ",$($addn)"

        # Set the Enabled and PasswordNeverExpires properties
        If (($_.Enabled.ToLower()) -eq "true") { $enabled = $True } Else { $enabled = $False }
        If (($_.PasswordNeverExpires.ToLower()) -eq "true") { $expires = $True } Else { $expires = $False }
        
             
        # Create sAMAccountName according to this 'naming convention':
        # <FirstLetterInitials><FirstFourLettersLastName> for example
        # htehp
        #$sam = $_.Initials.substring(0,1).ToLower() + $lastname.ToLower()
        $Sam = $_.EmployeeID
        Try   { $exists = Get-ADUser -Filter 'sAMAccountName -eq $sam'}
        Catch { }
        If($exists -eq $null)
        {
          # Set all variables according to the table names in the Excel 
          # sheet / import CSV. The names can differ in every project, but 
          # if the names change, make sure to change it below as well.
          $password = Get-RandomString -length 15 -UpperCase -LowerCase -Numbers 
          $setpass = ConvertTo-SecureString -AsPlainText $password -force
              
          Try
          {
            Write-Output "[INFO]`t Generating user password: $password"
             "[INFO]`t Generating user password: $password" | Out-File $log -append
            Write-Output "[INFO]`t Creating user : $($sam)"
            "[INFO]`t Creating user : $($sam)" | Out-File $log -append
            New-ADUser $sam -GivenName $_.GivenName -Initials $_.Initials `
            -Surname $_.LastName -DisplayName ($_.LastName + "," + $_.Initials + " " + $_.GivenName) `
            -Office $_.OfficeName -Description $_.Description -EmailAddress $_.Mail `
            -UserPrincipalName ($sam + "@" + $dnsroot) `
            -Company $_.Company -Department $_.Department -EmployeeID $_.EmployeeID `
            -OfficePhone $_.Phone -AccountPassword $setpass `
            -profilePath $Profile$sam  -homeDirectory $homedir$sam `
            -homeDrive $_.homeDrive -Enabled $enabled -PasswordNeverExpires $expires
            Write-Output "[INFO]`t Created new user : $($sam)"
            "[INFO]`t Created new user : $($sam)" | Out-File $log -append

            # Set account to require a password change on next logon..

            Set-ADUser -Identity $sam  -ChangePasswordAtLogon $true 
     
            $dn = (Get-ADUser $sam).DistinguishedName

            

           
            If ([adsi]::Exists("LDAP://$($location)"))
            {
              Move-ADObject -Identity $dn -TargetPath $location
              Write-Output "[INFO]`t User $sam moved to target OU : $($location)"
              "[INFO]`t User $sam moved to target OU : $($location)" | Out-File $log -append


            }
            Else
            {
              Write-Output "[ERROR]`t Targeted OU couldn't be found. Newly created user wasn't moved!"
              "[ERROR]`t Targeted OU couldn't be found. Newly created user wasn't moved!" | Out-File $log -append
            }
       
            # Rename the object to a good looking name (otherwise you see
            # the 'ugly' shortened sAMAccountNames as a name in AD. This
            # can't be set right away (as sAMAccountName) due to the 20
            # character restriction
            $newdn = (Get-ADUser $sam).DistinguishedName
            Rename-ADObject -Identity $newdn -NewName ($_.GivenName + " " + $_.LastName)
            Write-Output "[INFO]`t Renamed $($sam) to $($_.GivenName) $($_.LastName)`r`n"
            "[INFO]`t Renamed $($sam) to $($_.GivenName) $($_.LastName)`r`n" | Out-File $log -append



                  Try { $subject = "[CDF2] Your account has been created / recreated "	
                        $body = "Hello $($_.GivenName) $($_.Lastname),  `r`n`n Your CDF2 account has been created or modified.  Your login name is your Booz Allen employee ID ($($_.EmployeeID)), and your current password is $password.  You are required to change your password before you can log in.  Pleaee browse out to https://ts.cdf2.usae.bah.com and attempt to login there.  You will be presented with an opportuniuty to change your password at that time.`
                         `r`n`n Passwords must meet the following minimum requirements:`
                            `r Not contain the user's account name or parts of the user's full name that exceed two consecutive characters`
                            `r Be at least 14 characters in length`
                            `r Contain characters from three of the following four categories:`
                            `r`t    English uppercase characters (A through Z)`
                            `r`t    English lowercase characters (a through z)`
                            `r`t    Base 10 digits (0 through 9)`
                            `r`t    Non-alphabetic characters (for example, !, $, #, %)`
                            `r Complexity requirements are enforced when passwords are changed or created.`
                            `r `n `n This message was sent from an unmonitored email address.  Messages sent to this address including return replies to this message will not be received.  The regular Booz Allen Service Desk cannot assist you with matters regarding the CDF2.  For questions or support with regard to the CDF2, please contact cdf2-helpdesk@bah.com."
                  
                  Send-MailMessage -From $from -To "$($_.mail)" -cc "OF_Norfolk_IT_-_CDF2_Help_Desk@bah.com"  -Subject $subject -Body $body -ErrorAction Stop
                      }

                 Catch {Write-output "SMTP error sending: The error message is: $_.  Skipping"}  

          }
          Catch
          {
            Write-Output "[ERROR]`t Oops, something went wrong: $($_.Exception.Message)`r`n"
          }
        }
        Else
        {
          Write-Output "[SKIP]`t User $($sam) ($($_.GivenName) $($_.LastName)) already exists or returned an error!`r`n"
          "[SKIP]`t User $($sam) ($($_.GivenName) $($_.LastName)) already exists or returned an error!" | Out-File $log -append
        }
      }
    }
    Else
    {
      Write-Output "[SKIP]`t User ($($_.GivenName) $($_.LastName)) will be skipped for processing!`r`n"
      "[SKIP]`t User ($($_.GivenName) $($_.LastName)) will be skipped for processing!" | Out-File $log -append
    }
    $i++
  }
  "--------------------------------------------" + "`r`n" | Out-File $log -append
}




Write-Output "STARTED SCRIPT`r`n"
Start-Commands
Write-Output "STOPPED SCRIPT"