# usage .\chromebookmoveou.ps1 -csv .\school-dept.csv -destinationOU "/Destination/Path/To/Container"
#
# use in conjunction with the dito GAM tool from http://www.ditoweb.com/dito-gam
#
# csv must have header with a "Serial Number" column and no trailing empty column, either google or samsung serials
# csv may have header with a "Destination OU" column and no trailing empty column
# csv may have header with a "Asset Tag" column and no trailing empty column
# csv may have header with a "Oracle ID" column and no trailing empty column
#
# updated to log actions to timestamped csv_log-yyyyMMddHHmmss.txt
# updated to parse destination OU from additional column
# updated to append record information for asset tag as note, owning department as location
# updated to ensure samsung serial extra character truncated
# updated to capture additional information on processed devices and flag devices not enrolled
#
# Current logic prevents moving device NOT in root - should make this a switch
#
#   gam update cros <device id> [user <user info>] [location <location info>]
#                           	[notes <notes info>] [ou <new org unit>]
#

#uncomment the next line to validate parameters 
#Write-Host "Running gam tool moving devices from file " $csv " to ou " $destionationOU | Out-File "c:\gam\csv_log_$(get-date -Format yyyyMMddHHmmss).txt"

param(
	[string]$csv,
	[string]$destinationOU
)

# Provide the path where the gam tool is installed

$gamfilepath="c:\gam\gam.exe"

# Define alias used to call Dito GAM tool; add directory containing GAM tool to path

$gampath="Alias:\gam"

If(!(Test-Path -Path $gampath)) { New-Alias -Name gam -Value $gamfilepath }
	else { "Alias $gampath exists" }

$datestamp = $(get-date -Format yyyyMMddHHmmss)

if(Test-Path -Path $csv) {
	$workingserialcsv = Import-Csv $csv
	$counter = 0
	$enrolledcount = 0
	$notenrolledcount = 0
	$parent=split-path $csv -Parent
	$file=split-path $csv -Leaf
	$filename=[io.path]::GetFileNameWithoutExtension($csv)

	write-host "running file parser within $parent on $file to set $filename"

	$workingfolder = $parent+"\"+$filename
	$unenrolled = $parent+"\"+$filename+"\unenrolled"
	$enrolled = $parent+"\"+$filename+"\enrolled"

	if(!(Test-Path -Path $workingfolder)) { New-Item $workingfolder -type directory }

	$OutputFileLocation = $workingfolder + "\csv_log_" + $filename +"_"+ $datestamp + ".txt"

	"Running gam tool moving devices from file " + $csv + " to ou " + $destinationOU | Out-File $OutputFileLocation

	"___   ___   ___   ___   ___" | Out-File $OutputFileLocation -append    

	#uncomment to move processed file to working folder

	Move-Item $csv $workingfolder

foreach ($line in $workingserialcsv) {

	$counter=$counter+1

	# this would be where to add functions parsing csv headers

	if($line."Serial Number") {

    	$serialnm=$line."Serial Number"
    	$assettag=""
    	$oracleid=""

    	if ($line."Asset Tag") { $assettag = $line."Asset Tag"}
    	if ($line."Oracle ID") { $oracleid = $line."Oracle ID"}
    	if ($line."Destination OU") { $destinationOU = $line."Destination OU" }

    	#correct samsung extra character in serial

    	if ($serialnm.length -eq 15) { $serialnm = $serialnm.substring(0,($serialnm.length)-1) }

    	# this is part of gam print cros query 'id:ABC123' to get GUID from serial.

    	$search = "`"id:" + $serialnm + "`""

    	$myguid = & gam print cros query $search

    	# log collected device info in separate record

    	# define file to id device results with serial and process file and datestamp

    	$deviceinfofile = $workingfolder + "\" + $serialnm + "_" + $filename  + "_" + $datestamp + ".txt"

    	if ($myguid -ne "") { #did we get a result in the search?

        	#$myguid | Out-File $deviceinfofile

        	# make it easy to parse collected device info and compare to needed values...

        	$mydevice = ConvertFrom-CSV $myguid

        	if ($mydevice.serialnumber) { # a valid serial number means it's been enrolled

            	$enrollstate = "enrolled"
            	$enrolledcount = $enrolledcount + 1

            	if ($assettag) { $addnote = "notes" } else { $addnote = "" }
            	if ($oracleid) { $addloc = "location" } else { $addloc = "" }

            	$deviceID = $mydevice.deviceID
            	$curOU = $mydevice.orgUnitPath
            	$setdest = ""
            	$destOU = ""

            	if ($mydevice.orgUnitPath -eq "/") {

            	# Only move devices in root OU

            	# Eventually add logic to check whether is in subOU of intended target.

                	if ($mydevice.orgUnitPath -eq $destinationOU) {
                    	$setdest = ""
                    	$destOU = ""
                	} else {
                    	$setdest = "OU"
                    	$destOU = $destinationOU
                	}
            	}

            	if(!(Test-Path -Path $enrolled)) { New-Item $enrolled -type directory }

            	Write-Host $counter " sn : " $mydevice.serialnumber " guid: " $mydevice.deviceID " curOU: " $mydevice.orgUnitPath "destOU: " $destinationOU

            	$enrolleddevicefile = $workingfolder+"\enrolled\"+$serialnm + "_" + $filename  + "_" + $datestamp + ".txt"

            	$enrollstate + "," + $serialnm +  "," + $assettag + "," + $oracleid + "," + $destinationOU + "," + $counter | Out-File $enrolleddevicefile

            	$myguid | Out-File $enrolleddevicefile -append

            	if ($addnote -Or $addloc -Or $setdest) {
                	# define command parameters
                	#$cmd = gam

                	$function = "update"
                	$cros = "cros"

                	Write-Host " cmd: gam " $function $cros $deviceID $addnote $assettag $addloc $oracleid $setdest $destOU

                	$mydevice.serialnumber + "," + $counter + "," + $mydevice.deviceID + ",ou=" + $mydevice.orgUnitPath + ", cmd: " + $cmd + " "+ $function +" "+ $cros +" "+ $deviceID +" "+ $addnote +" "+ $assettag +" "+ $addloc +" "+ $oracleid +" "+ $setdest +" "+ $destOU | Out-File $OutputFileLocation -append

                	& gam $function $cros $deviceID $addnote $assettag $addloc $oracleid $setdest $destOU

                	} else { "No changes for " + $mydevice.serialnumber | Out-File $OutputFileLocation -append }
            	}
        	} else { # no serial number found, device not enrolled
            	$enrollstate = "noenroll"
            	$notenrolledcount = $notenrolledcount + 1

            	if(!(Test-Path -Path $unenrolled)) { New-Item $unenrolled -type directory }

            	Write-Host $counter " NOTENROLLED : " $serialnm " tag: " $assettag "destOU: " $destinationOU

            	$unenrolleddevicefile = $workingfolder+"\unenrolled\"+$serialnm + "_" + $filename  + "_" + $datestamp + ".txt"
            	$enrollstate + "," + $serialnm  + "," + $assettag + "," + $oracleid + "," + $destinationOU + "," + $counter | Out-File $unenrolleddevicefile
        	}

    	$enrollstate + "," + $serialnm  + "," + $assettag + "," + $oracleid + "," + $curOU + "," + $destinationOU + "," + $counter | Out-File $OutputFileLocation -append

    	} else { Write-Host "file $csv didn't have valid Serial Number header!" }

	}

$totalcount = $enrolledcount + $notenrolledcount

Write-Host "Total " $counter " devices counted. " $enrolledcount " and " $notenrolledcount " equals " $totalcount

"___   ___   ___   ___   ___" | Out-File $OutputFileLocation -append

"Counted " + $counter + " devices: " + $enrolledcount + " enrolled and " + $notenrolledcount + " not found equals total " + $totalcount | Out-File $OutputFileLocation -append

} else { Write-Host "File $csv not found" } # file didn't exist


#Retrieving All Chrome OS Devices for organization (may take some time for large accounts)...
#Got 0 Chrome devices...
	#failed
#Got 1 Chrome devices...
	#succeeded
# fails if invalid OU ouput:
#  	Error 400: Invalid Input: INVALID_OU_ID - invalid
# Need to trap error (it doesn't move the device)
# Parse first line of csv for headers
# parameter to process non-root devices
