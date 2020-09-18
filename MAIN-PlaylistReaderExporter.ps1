#requires -version 4
<#
.SYNOPSIS
  Monitors a Padapult xml file for updates to now playing song data. Adds song data to a daily json playlist file.
.DESCRIPTION
  Monitors declared '$watchfolder' for files matching specified '$filter'. 
  When matching files are updated their data is added to a daily json playlist file.
  The daily json playlist file is named with the date in this format: YYYYMMDD.json
  
  The daily json playlist file is stored in three declared locations:
  $outputfolder:        folder mapped to production s3 bucket
  $outputfoldertest:    folder mapped to test s3 bucket
  $outputfolderlocal:   This is where a local copy of the Json playlist data is stored.
                        The local daily playlist json data is read and combined with new now playing data from padapult.
                        The combined daily playlist data is then written back to all three locations.
                        The local output folder should be local and highly available so that play data
                        continues to be stored even if s3 buckets are unavailable.
                        s3 buckets can then be "caught up" with data recorded while they were unavailable.
  
  Description of other declared variables:
  $eventWatcherName:    Name used to identify the File Event watcher created by this script. It should be unique to prevent collision with other watcher scripts.
  $logPath:             Path to where the event log should be stored.
  $logFileNameSuffix:   The filename to be appended to the current date which forms the full log filename. The prepended date (YYYYMMDD) is to facilitate log rotation.
  $songproperties:      A comma seperated list of properties we want imported from the now playing xml data into the json playlist data. example "Title","Artist","Timestamp"
                        IMPORTANT NOTE: "Timestamp" property is REQUIRED. It's used as a unique id for each now playing item, to prevent duplicates in the playlist.

.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        2.0
  Author:         Derek J. Bernard
  Creation Date:  2018-06-01
  Purpose/Change: Initial script development
  
.EXAMPLE
  In TaskManager:
  powershell.exe -ExecutionPolicy Bypass C:\path\to\PlaylistWatcherExporter-HD2.ps1
  From Explorer Manually:
  right click script and cick run in powershell
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# On Dad Master Settings (Uncomment these on Dad)
#$watchfolder = 'C:\MAINXML' # Enter the root path you want to monitor.
#$filter = 'mainXML1.xml'  # You can enter a wildcard filter here.
#$outputfolder = 'P:' # output to prod destination
#$outputfoldertest = 'Z:' # output to test destination
#$outputfolderlocal = 'C:\MAINXML\output' # output to local backup folder
#$logPath = "C:\MAINXML\log"

# Test Settings (Comment # These on Dad)
$watchfolder = 'test\watch'
$filter = 'HD2test.xml'
$outputfolder = 'test\output' # output to prod destination
$outputfoldertest = 'test\output-test' # output to test destination
$outputfolderlocal = 'test\output-local' # output to local backup folder
$logPath = "test\output-local\log"

# Script Config Settings
$logFileNameSuffix = "$eventWatcherName-log.txt"
$songproperties = "Group","CutID","Length","Title","Outcue","Agency","Billboard","Artist","Genre","Album","Producer","URL","Composer","Lyricist","AlbumID","SongID","StationID","StationSlogan","Timestamp"
$path = "$watchfolder\$filter"
$readinterval = 30

#-----------------------------------------------------------[Execution]------------------------------------------------------------

do
{

  $TodaysDate = Get-Date -UFormat "%Y%m%d"

  # Get new data and append to daily json playlist
  $xmldata = [Xml] (Get-Content -Path $path)
  $nowplayingobj = Select-Xml -Xml $xmldata -XPath "//NowPlaying" | Select-Object -ExpandProperty Node | Select-Object -Property $songproperties
  $jsonNowPlaying = $nowplayingobj | ConvertTo-Json
#   Write-Host $jsonNowPlaying
  $dailyplaysobj = Get-Content -Raw -Path $outputfolderlocal\$TodaysDate.json | ConvertFrom-Json
  $jsonNowPlayingobj = $jsonNowPlaying | ConvertFrom-Json
  $strTimeStampImport = $jsonNowPlayingobj.Timestamp
#   Write-Host "Imported Timestamp: " $strTimeStampImport
  $localutcoffset = [System.TimeZone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).Hours.ToString() -replace '^\-(\d)', '-0$1:00'
#   Write-Host "Local utc offset: " $localutcoffset
  $strlocaloffsetTimeStamp = $strTimeStampImport -replace '\-\d\d\:\d\d$', $localutcoffset
#   Write-Host "Timestamp using local offset: " $strlocaloffsetTimeStamp
  $jsonNowPlayingobj.Timestamp = $strlocaloffsetTimeStamp
#   Write-Host "Song data with updated TimeStamp: " 
#   $jsonNowPlayingobj | ConvertTo-Json | Write-Host

  $array = @()
  $array += $dailyplaysobj
  #$countofdailyplays = $array.Count
  $array += $jsonNowPlayingobj
  $updatedDailyPlays = $array | Sort-Object -Property TimeStamp -Unique
  #$countofupdatedDailyPlays = $updatedDailyPlays.Count
  $songTitle = $jsonNowPlayingobj.Title
  
#  If ($countofupdatedDailyPlays -gt $countofdailyplays ) {
    Write-Host "Daily Playlist data: "
    $updatedDailyPlays | ConvertTo-Json -Depth 100 | Write-Host
    $updatedDailyPlays | ConvertTo-Json | Out-File $outputfolderlocal\$TodaysDate.json -Encoding UTF8
    $updatedDailyPlays | ConvertTo-Json -Compress | Out-File $outputfolder\$TodaysDate.json -Encoding UTF8
    $updatedDailyPlays | ConvertTo-Json -Compress | Out-File $outputfoldertest\$TodaysDate.json -Encoding UTF8
    
    # Logging Changes'
    Write-Host "The file '$path' was changed containing song '$songTitle'"
    Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "The file '$path' was changed containing song '$songTitle'"

  Write-Host "Monitoring '$path'... "
  Write-Host "Last read song title: '$songTitle'."
  Start-Sleep $readinterval

} while($true)