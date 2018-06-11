#requirements

#This script uses the .NET FileSystemWatcher class to monitor file events in folder(s).
#The advantage of this method over using WMI eventing is that this can monitor sub-folders.
#The -Action parameter can contain any valid Powershell commands.  I have just included two for example.
#The script can be set to a wildcard filter, and IncludeSubdirectories can be changed to $true.
#You need not subscribe to all three types of event.  All three are shown for example.
# Version 1.1



$watchfolder = 'C:\Path\to\watch' # Enter the root path you want to monitor.
$filter = 'test.xml'  # You can enter a wildcard filter here.
$eventWatcherName = 'TestFileChanged' # This is an ID for the watcher, it should be unique.
$outputfolder = 'C:\Path\to\output' # output to prod destination
$outputfoldertest = 'C:\Path\to\output-test' # output to test destination
$outputfolderlocal = 'C:\Path\to\output-local' # output to local backup folder
$logPath = "C:\Path\to\output-local\log"
$logFileNameSuffix = "$eventWatcherName-log.txt"
$songproperties = "Group","CutID","Length","Title","Outcue","Agency","Billboard","Artist","Genre","Album","Producer","URL","Composer","Lyricist","AlbumID","SongID","StationID","StationSlogan","Timestamp"

# remove any currently running 
Try {
    Unregister-Event $eventWatcherName -ErrorAction SilentlyContinue
}
Catch {
    $logtimestamp = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    $TodaysDate = Get-Date -UFormat "%Y%m%d"
    Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "$logtimestamp EventWatcher '$eventWatcherName' Not Running"
}
Finally {
    $logtimestamp = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    $TodaysDate = Get-Date -UFormat "%Y%m%d"
    Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "$logtimestamp Stopped existing EventWatcher '$eventWatcherName'"
}
    
Try {
    # In the following line, you can change 'IncludeSubdirectories to $true if required.                          
    $fsw = New-Object IO.FileSystemWatcher $watchfolder, $filter -Property @{IncludeSubdirectories = $false;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'}

    Register-ObjectEvent $fsw Changed -SourceIdentifier $eventWatcherName -Action {
        $TodaysDate = Get-Date -UFormat "%Y%m%d"
        Write-Host "triggered"
        $name = $Event.SourceEventArgs.Name
        $path = $Event.SourceEventArgs.FullPath
        Write-Host $path
        $changeType = $Event.SourceEventArgs.ChangeType
        $eventTimeStamp = $Event.TimeGenerated
    

        # Get new data and append to daily json playlist
        $xmldata = [Xml] (Get-Content -Path $path)
        $nowplayingobj = Select-Xml -Xml $xmldata -XPath "//NowPlaying" | Select-Object -ExpandProperty Node | Select-Object -Property $songproperties
        Write-Host $nowplayingobj | Format-List
        $jsonNowPlaying = $nowplayingobj | ConvertTo-Json
        Write-Host $jsonNowPlaying
        $dailyplaysobj = Get-Content -Raw -Path $outputfolderlocal\$TodaysDate.json | ConvertFrom-Json
        $jsonNowPlayingobj = $jsonNowPlaying | ConvertFrom-Json
        $array = @()
        $array += $dailyplaysobj
        $array += $jsonNowPlayingobj
        $updatedDailyPlays = $array | Sort-Object -Property TimeStamp -Unique
        $updatedDailyPlays | Write-Host
        $updatedDailyPlays | ConvertTo-Json | Out-File $outputfolderlocal\$TodaysDate.json
        $updatedDailyPlays | ConvertTo-Json -Compress | Out-File $outputfolder\$TodaysDate.json
        $updatedDailyPlays | ConvertTo-Json -Compress | Out-File $outputfoldertest\$TodaysDate.json
        $songTitle = $jsonNowPlayingobj.Title

        # Logging Changes'
        Write-Host "$eventTimeStamp The file '$path' was $changeType containing song '$songTitle'"
        Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "$eventTimeStamp The file '$path' was $changeType containing song '$songTitle'"
    }
}
Catch {
    $logtimestamp = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    $TodaysDate = Get-Date -UFormat "%Y%m%d"
    Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "$logtimestamp EventWatcher $eventWatcherName failed to start due to error"
}
Finally {
    $logtimestamp = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    $TodaysDate = Get-Date -UFormat "%Y%m%d"
    Out-File -FilePath $logpath\$TodaysDate-$logFileNameSuffix -Append -InputObject "$logtimestamp Started EventWatcher $eventWatcherName for $watchfolder\$filter"
}
#while($true) { sleep 5 }