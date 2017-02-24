This is a powershell script I wrote to manage moving large numbers of Chromebooks amongst my organization's Google Apps Domain structure. 

It requires the Dito GAM tool be installed, it is available from http://www.ditoweb.com/dito-gam. 

It requires a formatted CSV file and an understanding of your organization's Google Apps Domain structure. 

usage .\chromebookmoveou.ps1 -csv .\school-dept.csv -destinationOU "/Destination/Path/To/Container"

use in conjunction with the dito GAM tool from http://www.ditoweb.com/dito-gam

csv must have header with a "Serial Number" column and no trailing empty column, either google or samsung serials.
csv may have header with a "Destination OU" column and no trailing empty column.
csv may have header with a "Asset Tag" column and no trailing empty column.
csv may have header with a "Oracle ID" column and no trailing empty column.

Added log of actions to timestamped csv_log-yyyyMMddHHmmss.txt; parse destination OU from additional column.
Append record information for asset tag as note, owning department as location.
Improved to ensure samsung serial extra character truncated.
Capture additional information on processed devices and flag devices not enrolled.

Current logic prevents moving device NOT in root - should make this a switch

   gam update cros <device id> [user <user info>] [location <location info>]
                           	[notes <notes info>] [ou <new org unit>]
