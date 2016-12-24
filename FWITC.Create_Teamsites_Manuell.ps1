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

$Path = "D:\Service\FWITC.AdminCenter"
#$path = split-path -parent $MyInvocation.MyCommand.Definition

Set-Location $path

function create-newSitecollection
{

Param(
        [String]$SiteURL,
        [String]$SiteTitle,
        [String]$Primaryowner,
        [String]$Secondaryowner
      )

$XML = New-Object XML
$XML.Load("$Pwd\config.xml")
#endregion Start SharePoint Powershell and get config from XML 

#region get list items from AntragslisteTeamsite View Offene Anträge


$Primaryowneraliasnc = "i:0#.w|" + $Primaryowner
$Secondarayowneraliasnc = "i:0#.w|" + $Secondaryowner

        
        #region Start Provisioning Script with parameters  
        if ($Secondaryowner -eq $Null)
        {                        $SpSite = New-SPSite $SiteURL -Name $SiteTitle -Template STS#0 `                      -Language 1031 -OwnerAlias $Primaryowneraliasnc -ErrorAction SilentlyContinue -Verbose
        }
        else
        {            $SpSite = New-SPSite $SiteURL -Name $SiteTitle -Template STS#0 `                      -Language 1031 -OwnerAlias $Primaryowneraliasnc `                      -SecondaryOwnerAlias $Secondarayowneraliasnc -ErrorAction SilentlyContinue -Verbose
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

            $admuser = ([String](Get-SPUser -Identity $Primaryowneraliasnc -Web $Spsite.WebApplication.Url).UserLogin).Replace("i:0#.w|","")
            $rootweb = (Get-SPSite $SpSite.Url).rootweb
            $RootWeb.CreateDefaultAssociatedGroups($SPSite.Owner.UserLogin,$SPSite.Owner.UserLogin,$SPSite.RootWeb.Title)

            $rootweb.allowunsafeupdates = $false
            $rootweb.Dispose()
            #endregion
            #region set listitem values if site is created 
            
        }
        #endregion set listitem values if site is created 
    
}
