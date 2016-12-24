<#
Privision Teamsites with Script ...


Author: Florian Warncke, Florian Warncke IT-Consulting
References to:
- http://surya20p.blogspot.de/2012/11/remove-webpart-from-sharepoint-pages.html
- http://basementjack.com/sharepoint-2/powershell-script-to-add-a-list-of-users-to-the-site-collection-administrators-group-of-every-site-on-your-sharepoint-2010-farm/
Version 2.0
#>

#region Start SharePoint Powershell and get config from XML 

Add-PSSnapin *share*

#$Path = "D:\Service\FWITC.AdminCenter"
$path = split-path -parent $MyInvocation.MyCommand.Definition

Set-Location $path

$XML = New-Object XML
$XML.Load("$Pwd\config.xml")

$PMSConfig = new-object XML
$PMSConfig.Load("$Pwd\PMS_Config.xml")

& ($PWD.Path + "\FWITC.Admincenter.Functions.ps1")

#endregion Start SharePoint Powershell and get config from XML 

#region get list items from AntragslisteTeamsite View Offene Anträge
$PMSConfig.config.Templates.RemoveAll()
$PMSConfig.save("$Pwd\PMS_Config.xml")
Modify-PMSXMLConfigfile -Pmsconfigfile ("$Pwd\PMS_Config.xml") -ConfigListSite $xml.config.createSiteCollection.Antragsseite -Configlistname "PMSSiteconfig"


$Site = $Xml.config.createSiteCollection.Antragsseite

$Site = get-spweb $Site

$List = $site.Lists[$xml.config.createSiteCollection.SpListconfig.SPList.Name] 
$view = $List.Views["Neu"] 
$SPItems = $List.GetItems($view) | select @{n="Title"; e={$_["Title"]}},  
                                    @{n="URL"; e={$_["URL"]}},
                                    @{n="WebappName"; e={$_["WebappName"]}},
                                    @{n="Admins"; e={$_["Admins"]}},
                                    @{n="Member"; e={$_["Member"]}},
                                    @{n="Visitor"; e={$_["Visitor"]}},
                                    @{n="Bearbeitungsstatus"; e={$_["Bearbeitungsstatus"]}},
                                    @{n="ID"; e={$_["ID"]}} | ?{$_.Bearbeitungsstatus -match "Neu"}



if ($SPItems -ne $null)
{ 
    foreach ($SPitem in $spitems)
   {
        #region get Parameters from each Item in Antragsliste
        #$SPitem = $spitems[0]
        $SPSiteownerList = $spitem.Admins
        $primaryowneralias = $SPSiteownerList[0].User.LoginName
        if ($SPSiteownerList.count -gt 1)
        {$secondaryowneralias = $SPSiteownerList[1].User.LoginName}
        $SpItemChange = $List.GetItemById($SPitem.ID)

        #endregion get Parameters from each Item in Antragsliste
        
        #endregion get list items from AntragslisteTeamsite View Offene Anträge
        
        #region Start Provisioning Script with parameters  
        $SiteURL =  ("$((Get-SPWebApplication $SPitem.WebappName).URL)$(($SPitem.URL).TrimStart("/"))")
        if ($SPSiteownerList.count -le 1)
        {                        $SpSite = New-SPSite $SiteURL -Name $SPitem.Title -Template STS#0 `                      -Language 1031 -OwnerAlias $primaryowneralias -ErrorAction SilentlyContinue -Verbose
        }
        else
        {            $SpSite = New-SPSite $SiteURL -Name $SPitem.Title -Template STS#0 `                      -Language 1031 -OwnerAlias $primaryowneralias `                      -SecondaryOwnerAlias $secondaryowneralias -ErrorAction SilentlyContinue -Verbose
        }
        #endregion Start Provisioning Script with parameters      

       
        if ((Get-SPWeb $SiteURL) -ne $null)
        {
            foreach ($SPFeature in $xml.config.createSiteCollection.site.Features.ChildNodes)
            {
                if ($SPFeature.EnableorDisable -eq "Disable")
                {
                    Disable-SPFeature -Identity $SPFeature.FeatureID -Url $SPSite.Url -Confirm:$false
                }
                else
                {
                    Enable-SPFeature $SPFeature.FeatureID -Url $SPSite.Url -Confirm:$false
                }
            }
            $ColorFilePartUrl = "/_catalogs/theme/15/";
            $FontFilePartUrl = "/_catalogs/theme/15/";
            $MasterPagePartUrl = "/_catalogs/masterpage/";

            $rootweb = $spsite.RootWeb

            #region Upload theme files to the root web gallery      
            $SIteconfig =  $xml.config.createSiteCollection.site
            $themeName = $SIteconfig.themename;
            $colorfile = $SIteconfig.colorfile;
            $fontfile = $SIteconfig.fontfile;
            $masterpage = $SIteconfig.masterpage;
            $colorshemeFile = get-childitem "$($PWD)\$($SIteconfig.colorfile)";
            $colorfontFile = get-childitem "$($PWD)\$($SIteconfig.fontfile)";
    
            $rootweb.allowunsafeupdates = $true;
            $rootweb.Update()
        
            $themeList = $rootweb.GetCatalog([Microsoft.SharePoint.SPListTemplateType]::ThemeCatalog);
            $folder = $themeList.RootFolder.SubFolders["15"];
        
            $addColorFile = $folder.Files.Add($colorfile,$colorshemeFile.OpenRead(),$true);
            $addfontfile = $folder.Files.Add($fontfile,$colorfontFile.OpenRead(), $true);
    
            $SPlogoFolder = $rootweb.GetFolder("_catalogs/theme/")
            $SPlogoCollection = $SPlogoFolder.Files
            $LogoFile = Get-ChildItem $PWD\($SIteconfig.logofile)
            $SpLogoFile = $SPlogoCollection.Add($LogoFile.Name,$LogoFile.OpenRead(),$false)

            #endregion

            $relativeUrl = $rootweb.ServerRelativeUrl;
            $spList = $rootweb.GetCatalog([Microsoft.SharePoint.SPListTemplateType]::DesignCatalog);
      
            $newThemeItem = $spList.AddItem();
            $newThemeItem["Name"] = $themeName;
            $newThemeItem["Title"] = $themeName;
            $newThemeItem["MasterPageUrl"] =  "$relativeUrl$MasterPagePartUrl$masterpage";#$Web.MasterUrl;
            $newThemeItem["ThemeUrl"] = "$($folder.ServerRelativeUrl)/$($colorfile)";
            $newThemeItem["FontSchemeUrl"] = "$($folder.ServerRelativeUrl)/$($fontfile)";
            $newThemeItem["DisplayOrder"] = 121;
            $newThemeItem.Update();

            $rootweb.Update()
            $rootweb.Dispose()
            #endregion
       
            #region Set the theme
         
            $theme=[Microsoft.SharePoint.Utilities.SPTheme]::Open($themeName, $addcolorfile, $addfontfile);
            Write-Host $theme.Name "to" $rootWeb.Title;
            $theme.ApplyTo($rootWeb, $false);
            $rootweb.Update() 
            $rootweb.Dispose()   
            Sleep 15
        
            $LogoFile = Get-ChildItem "$($PWD)\$($SIteconfig.logofile)" 
            $rootweb.SiteLogoUrl = $SPlogoFolder.ServerRelativeUrl + "/" + $LogoFile.Name
            $rootweb.Update()
            $rootweb.Dispose()   
            sleep 15

            $pagePath= "/SitePages/Homepage.aspx"       
            $pageUrl = $spSite.Url + $pagePath
            $spWebPartManager = $RootWeb.GetLimitedWebPartManager($pageUrl, [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
            $GettingStarted = ($spWebPartManager.WebParts | Where-Object {$_.Title -match "Erste Schritte"})  
            $spWebPartManager.DeleteWebPart($spWebPartManager.WebParts[$GettingStarted.ID])          
            $rootweb.Update()
            $rootweb.Dispose()

            $admuser = ([String](Get-SPUser -Identity $primaryowneralias -Web $Site.Url).UserLogin).Replace("i:0#.w|","")
            $rootweb = (Get-SPSite $SpSite.Url).rootweb
            $RootWeb.CreateDefaultAssociatedGroups($SPSite.Owner.UserLogin,$SPSite.Owner.UserLogin,$SPSite.RootWeb.Title)
            
            
            foreach ($MemberUser in $SPitem.Member)
            {
                if ($MemberUser.User.UserLogin -match "c:0+.w|"){$SpUserforgroup = $SpSite.RootWeb.EnsureUser($MemberUser.User.DisplayName)}
                else {$SpUserforgroup = $SpSite.RootWeb.EnsureUser($MemberUser.User.UserLogin)}
                $EditGroup = $RootWeb.SiteGroups["Mitglieder von $($RootWeb.Title)"]
                $EditGroup.AddUser($SpUserforgroup)
                $rootweb.update()
            }
            if ($SPitem.Visitor -ne $Null)    
            {
                foreach ($VisitorUser in $SPitem.Visitor)
                {
                    if ($VisitorUser.User.UserLogin -match "c:0+.w|"){$SpUserforgroup = $SpSite.RootWeb.EnsureUser($VisitorUser.User.DisplayName)}
                    else {$SpUserforgroup = $SpSite.RootWeb.EnsureUser($VisitorUser.User.UserLogin)}
                    $VisitorGroup = $RootWeb.SiteGroups["Besucher von $($RootWeb.Title)"]
                    $VisitorGroup.AddUser($SpUserforgroup)
                    $rootweb.update()
                }
            }
            $rootweb.allowunsafeupdates = $false
            $rootweb.Dispose()
            if ($Spsite.URL -match "/projects/")
            {
                transfer-ListTemplateFiles -SourceURL $PMSConfig.config.SourceSite -DestURL $SpSite.URL
                add-SpLists -DestURL $SpSite.URL
                $SpSite.RootWeb.Properties["FWITC.Project"] = $true
                $SpSite.RootWeb.Properties.Update()
                $SpSite.RootWeb.Update()

            }

            #endregion
            #region set listitem values if site is created 
            if ((Get-SPSite $SiteURL) -ne $null)
            {
                $SpItemChange["Bearbeitungsstatus"] = "In Bearbeitung"
            }
            $SpItemChange.Update()
            
        }
        #endregion set listitem values if site is created 
    
    }
}
