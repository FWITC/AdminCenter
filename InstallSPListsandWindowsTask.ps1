Add-PSSnapin *share*

#$path = split-path -parent $MyInvocation.MyCommand.Definition

$Path = "D:\Service\FWITC.AdminCenter"
Set-Location $path

$XML = New-Object XML
$XML.Load("$PWD\config.xml")

#Install List

function Create-CSCList
{	
    Param([String]$listName)
        
	$spWeb = Get-SPWeb -Identity $XML.config.createSiteCollection.Antragsseite
	$spTemplate = $spWeb.ListTemplates["Custom List"] 
	$spListCollection = $spWeb.Lists 
    $spListCollection.Add($listName, $listName, $spTemplate) 
	$path = $spWeb.url.trim() 
	$newspList = $spWeb.GetList("$path/Lists/$listName")
	#foreach ($node in $templateXml.Template.Field) 
    foreach ($node in $xml.config.createSiteCollection.SpListconfig.ListFields.Field) 
    {
	
		    $Node.OuterXml
            $newspList.Fields.AddFieldAsXml($node.OuterXml, $true,[Microsoft.SharePoint.SPAddFieldOptions]::AddFieldToDefaultView)
	}
    $newspList.OnQuickLaunch = $true
	$newspList.EnableVersioning = $true
    $newspList.Update()
}

function Create-MonitorList
{	
    Param([String]$listName)
        
	$spWeb = Get-SPWeb -Identity $XML.config.createSiteCollection.Antragsseite
	$spTemplate = $spWeb.ListTemplates["Custom List"] 
	$spListCollection = $spWeb.Lists 
    $spListCollection.Add($listName, $listName, $spTemplate) 
	$path = $spWeb.url.trim() 
	$newspList = $spWeb.GetList("$path/Lists/$listName")
	#foreach ($node in $templateXml.Template.Field) 
    foreach ($node in $xml.config.MonitorSiteCollections.SpListconfig.ListFields.Field) 
    {
	
		    $Node.OuterXml
            $newspList.Fields.AddFieldAsXml($node.OuterXml, $true,[Microsoft.SharePoint.SPAddFieldOptions]::AddFieldToDefaultView)
	}
    $newspList.OnQuickLaunch = $true
	$newspList.EnableVersioning = $true
    $newspList.Update()
}

Function Create-NewSPTeamsiteTask
{
    #Install Task

    [Array]$Days = $XML.config.createSiteCollection.Taskconfig.RunningDays.Value.Split(",")
    #$Days = $DAYOFWEEKTORUN | ForEach-Object {[System.DayOfWeek] $_}
    $Scriptpath = $PWD.Path + "\FWITC.Create_Teamsites-Admincenter.ps1"
    $CMD = "-ExecutionPolicy Bypass -noprofile $Scriptpath"
    $TaskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek ($Days | ForEach-Object {[System.DayOfWeek] $_}) -At $XML.config.createSiteCollection.Taskconfig.Taskruntime.Value
    $TaskCommand = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument $CMD 
    Register-ScheduledTask -TaskName $xml.config.createSiteCollection.Taskconfig.Taskname.Value `
                           -RunLevel Highest `
                           -User $XML.config.createSiteCollection.Taskconfig.TaskUser.Username `
                           -Password $XML.config.createSiteCollection.Taskconfig.TaskUser.TaskPW `
                           -Trigger $TaskTrigger -AsJob -Action $TaskCommand
                           Write-Host "  [OK]" -ForegroundColor Green 
                           $XML.config.createSiteCollection.Taskconfig.TaskUser.TaskPW = "cleared"
                           $XML.save("$PWD\config.xml")
}

Function Create-MonitorSPSitesTask
{
    #Install Task

    [Array]$Days = $XML.config.MonitorSiteCollections.Taskconfig.RunningDays.Value.Split(",")
    #$Days = $DAYOFWEEKTORUN | ForEach-Object {[System.DayOfWeek] $_}
    $Scriptpath = $PWD.Path + "\FWITC.MonitorSharePointSites.ps1"
    $CMD = "-ExecutionPolicy Bypass -noprofile $Scriptpath"
    $TaskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek ($Days | ForEach-Object {[System.DayOfWeek] $_}) -At $XML.config.MonitorSiteCollections.Taskconfig.Taskruntime.Value
    $TaskCommand = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument $CMD 
    Register-ScheduledTask -TaskName $xml.config.MonitorSiteCollections.Taskconfig.Taskname.Value `
                           -RunLevel Highest `
                           -User $XML.config.MonitorSiteCollections.Taskconfig.TaskUser.Username `
                           -Password $XML.config.MonitorSiteCollections.Taskconfig.TaskUser.TaskPW `
                           -Trigger $TaskTrigger -AsJob -Action $TaskCommand
                           Write-Host "  [OK]" -ForegroundColor Green 
                           $XML.config.MonitorSiteCollections.Taskconfig.TaskUser.TaskPW = "cleared"
                            $XML.save("$PWD\config.xml")
}

Function Create-ControlContenDBTask
{
    #Install Task

    [Array]$Days = $XML.config.MonitorSiteCollections.Taskconfig.RunningDays.Value.Split(",")
    #$Days = $DAYOFWEEKTORUN | ForEach-Object {[System.DayOfWeek] $_}
    $Scriptpath = $PWD.Path + "\FWITC.ControlContentDBs"
    $CMD = "-ExecutionPolicy Bypass -noprofile $Scriptpath"
    $TaskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek ($Days | ForEach-Object {[System.DayOfWeek] $_}) -At $XML.config.controlContendDBs.Taskconfig.Taskruntime.Value
    $TaskCommand = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument $CMD 
    Register-ScheduledTask -TaskName $xml.config.controlContendDBs.Taskconfig.Taskname.Value `
                           -RunLevel Highest `
                           -User $XML.config.controlContendDBs.Taskconfig.TaskUser.Username `
                           -Password $XML.config.controlContendDBs.Taskconfig.TaskUser.TaskPW `
                           -Trigger $TaskTrigger -AsJob -Action $TaskCommand
                           Write-Host "  [OK]" -ForegroundColor Green 
                           $XML.config.controlContendDBs.Taskconfig.TaskUser.TaskPW = "cleared"
                            $XML.save("$PWD\config.xml")
}

<#
Create-CSCList -listName $XML.config.createSiteCollection.SpListconfig.SPLists.SPList.Name
Create-NewSPTeamsiteTask


Foreach ($Splist in $XML.config.MonitorSiteCollections.SpListconfig.SPLists.ChildNodes) {Create-MonitorList -Listname $Splist.Name}
Create-MonitorSPSitesTask


Create-ControlContenDBTask
#>