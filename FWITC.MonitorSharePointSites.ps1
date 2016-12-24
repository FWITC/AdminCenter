<#
Description: This Script monitor Sitecollections and write values to a SharePoint List. if needed you can change "Quota Templates" in SPList, the script will change the template in SPSite
Author: Florian Warncke, Florian Warncke IT-Consulting
Version2.5
#>

Add-PSSnapin *share*

#$path = split-path -parent $MyInvocation.MyCommand.Definition

$Path = "D:\Service\FWITC.AdminCenter"
Set-Location $path

$XML = New-Object XML
$XML.Load("$PWD\config.xml")

$service = [Microsoft.SharePoint.Administration.SPWebService]::ContentService

Start-Transcript -Path ("$PWD\SiteMonitorLogs\MonitorSitecollections_" + (get-Date -f yyyyMMdd) + ".log")# start Logfile

foreach ($SPWebapp in $XML.config.MonitorSiteCollections.SpMonitoredWebapplications.SpWebapplication)
{
    $SpSites = (Get-SPWebApplication $SPWebapp.Name).Sites
    $Monitoringlist = (get-spweb $XML.config.createSiteCollection.Antragsseite).Lists[($XML.config.MonitorSiteCollections.SpListconfig.SPLists.ChildNodes | ?{$_.AssosiatedWebapp -eq $SPWebapp.name}).Name]
    
    $UsedStorageinMB = ($Monitoringlist.Fields | ?{$_.StaticName -match ($XML.config.MonitorSiteCollections.SpListconfig.ListFields.ChildNodes | ?{$_.Staticname -match "UsedStorage"}).staticname}).Internalname
    $QuotaName = ($Monitoringlist.Fields | ?{$_.StaticName -match ($XML.config.MonitorSiteCollections.SpListconfig.ListFields.ChildNodes  | ?{$_.Staticname -match "QuotaName"}).staticname}).Internalname
    $SiteURL = ($Monitoringlist.Fields | ?{$_.StaticName -match ($XML.config.MonitorSiteCollections.SpListconfig.ListFields.ChildNodes  | ?{$_.Staticname -match "SiteURL"}).staticname}).Internalname
    $ContentDatabase = ($Monitoringlist.Fields | ?{$_.StaticName -match ($XML.config.MonitorSiteCollections.SpListconfig.ListFields.ChildNodes  | ?{$_.Staticname -match "ContentDatabase"}).staticname}).Internalname
    $SiteCollectionAdministrators = ($Monitoringlist.Fields | ?{$_.StaticName -match ($XML.config.MonitorSiteCollections.SpListconfig.ListFields.ChildNodes  | ?{$_.Staticname -match "SCAdmins"}).staticname}).Internalname


    foreach ($SPListItem in $Monitoringlist.Items)
        {
            $Testsite = Get-SPSite $SPListItem[$SiteURL].split(",")[0] -ErrorAction SilentlyContinue
            if ($Testsite -eq $Null)
            {
            [String]$String = "URL " + $SPListItem[$SiteURL] +" ist not in SharePoint Sitestore, remove SPListitem " + $SPListItem["Title"]
            Write-Output URL $String
            $SPListItem.delete()
            $Monitoringlist = (get-spweb $XML.config.createSiteCollection.Antragsseite).Lists[($XML.config.MonitorSiteCollections.SpListconfig.SPLists.ChildNodes | ?{$_.AssosiatedWebapp -eq $SPWebapp.name}).Name]
  
            }
        }

    Foreach ($SPSite in $SpSites)
    {

        [String]$SPshortname = ($Spsite.Url.Split("/"))[-1]
        $UsedSpace= [math]::Round($SpSite.usage.storage/1MB, 1)    
        $MonitoredItem = $Monitoringlist.Items | ?{$_.Title -eq ($Spsite.Url.Split("/"))[-1]}
        $Siteqoutaid = $SpSite.Quota.QuotaID
        $SpSAdminscount = ($SPSite.RootWeb.SiteAdministrators).Displayname.count 
        $SPSiteAdmins = ($SPSite.RootWeb.SiteAdministrators).Displayname |Out-String
        [String]$Lastchangeuser = ($MonitoredItem["Editor"]).Split("#")[1]
        if ($MonitoredItem -ne $Null)
        {
            [String]$List1 = $SPSiteAdmins.replace("`n","").replace(" ","").Length - $SpSAdminscount
            [String]$List2 = $MonitoredItem[$SiteCollectionAdministrators].replace("`n","").replace(" ","").length
            $EnumQuotatemplate = $MonitoredItem[$QuotaName] -ne ($Service.QuotaTemplates| ?{$_.QuotaID -eq $Siteqoutaid}).Name
        }
       
        if ($MonitoredItem -eq $Null)
        {               
            $NewSpSiteItem = $Monitoringlist.AddItem()
            $NewSpSiteItem["Name"] = $SPshortname
            $NewSpSiteItem["Title"] = $SPshortname
            $NewSpSiteItem[$UsedStorageinMB] = $UsedSpace
            $NewSpSiteItem[$QuotaName] = ($Service.QuotaTemplates| ?{$_.QuotaID -eq $Siteqoutaid}).Name
            $NewSpSiteItem[$SiteURL] = $SPSite.URL
            $NewSpSiteItem[$ContentDatabase] = $Spsite.ContentDatabase.Name
            $NewSpSiteItem[$SiteCollectionAdministrators] = $SPSiteAdmins
            $NewSpSiteItem.update()
            [String]$String = " New SPSite Item "+ $NewSpSiteItem["Title"] + " created"
            Write-Output $String          
        }
        
        elseif ($MonitoredItem[$UsedStorageinMB] -ne $UsedSpace -or $List1 -ne $List2 -or $MonitoredItem["ContentDatabase"] -ne $SPSite.ContentDatabase.Name -or $EnumQuotatemplate -eq $True) 
        {
            [String]$String = "Site Item "+ $MonitoredItem["Title"] + " have to modify" 
            Write-Output $String     
            $MonitoredItem[$UsedStorageinMB] = $UsedSpace
            $MonitoredItem[$ContentDatabase] = $SPSite.ContentDatabase.Name
            $MonitoredItem[$SiteCollectionAdministrators] = $SPSiteAdmins
            $MonitoredItem.Update()            
        
            if ($EnumQuotatemplate -eq $True)
            {
                if (($Service.QuotaTemplates| ?{$_.QuotaID -eq $Siteqoutaid}).StorageMaximumLevel -gt $service.QuotaTemplates[$MonitoredItem[$QuotaName]].StorageMaximumLevel)
                {
                    [String]$LogString = "Site Item " + $MonitoredItem["Title"] + " have to modify Quota to " + $MonitoredItem[$QuotaName]
                    Write-Output $LogString
                    [String]$StringItem = "Quota wurde in der CA oder PS am " + (get-date (get-date).AddDays(-1) -Format dd.MM.yyyy) + " auf das Quota " + ($Service.QuotaTemplates| ?{$_.QuotaID -eq $Siteqoutaid}).Name + " angepasst"
                    $MonitoredItem[$QuotaName] = ($Service.QuotaTemplates| ?{$_.QuotaID -eq $Siteqoutaid}).Name
                    $MonitoredItem["Notes"] = $StringItem
                    $MonitoredItem.Update()
                }
                else
                {
                    [String]$LogString = "SpSite QuotaTemplate changed to " + $MonitoredItem[$QuotaName]
                    Write-Output $LogString
                    [String]$StringItem = "Seiten Quota wurde in der Liste am" + (get-date (get-date).AddDays(-1) -Format dd.MM.yyyy) + " auf das Quota " + $MonitoredItem[$QuotaName] + " durch " + $Lastchangeuser + " angepasst"
                    Set-SPSite -Identity $SPSite.Url -QuotaTemplate $MonitoredItem[$QuotaName] -Verbose
                    $MonitoredItem["Notes"] = $StringItem
                    $MonitoredItem.Update()
                } 
             }
         } 

        else {Write-Output "no changes on $SPshortname"}
    }
}
Stop-Transcript # end Logfile