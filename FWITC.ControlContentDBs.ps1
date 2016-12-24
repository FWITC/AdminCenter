#region Start SharePoint Powershell and get config from XML 

Add-PSSnapin *share*

$path = split-path -parent $MyInvocation.MyCommand.Definition
#$Path = "E:\Scripts\CBC.CheckContentBs"

Set-Location $Path
$XML = New-Object XML
$XML.Load("$Path\config.xml")

. $("$PWD\FWITC.Sendinformmails.ps1")

#endregion Start SharePoint Powershell and get config from XML 

Function  Checkandcreate-ContentDBs
{
    Param(
        [String]$WebApplication,
        [Int]$Warningcounter,
        [String]$DBPrefix
         )
    $CalculatemaxDB = 0
    $CalculatecurrentDB = 0

    foreach($Db in (Get-SPContentDatabase -WebApplication $WebApplication))
    {

        $CalculatemaxDB =  $Db.MaximumSiteCount + $CalculatemaxDB
        $CalculatecurrentDB = $Db.CurrentSiteCount + $CalculatecurrentDB
    }

    if (($CalculatemaxDB - $CalculatecurrentDB) -le $Warningcounter)
    {
        $DBArray =@() 
        foreach ($KitDB in (Get-SPContentDatabase -WebApplication $WebApplication | ?{$_.name -match $DBPrefix }))
        {
            $Dbname = ([String]$KitDB.Name).replace($DBPrefix,"")
            if ($DBname.Length -le 3)
            {
                $DBArray += $Dbname
            }
        }
        if ((([int]$DBArray[-1]) + 1) -le 10)
        {$NewDBName = ($DBPrefix +"0") + ([int]$DBArray[-1] +1)}
        
        else {$NewDBName = $DBPrefix + (([int]$DBArray[-1]) + 1)}
        $Bodytstring =  "new DB "+$NewDBName+ " on Webapp" +$WebApplication + " was created"
        $subjectstring = "New DB on " + $WebApplication + " created"        send-informmail -Receipient $XML.config.controlContendDBs.Mailconfig.receipient -Sender $XML.config.Mailconfig.sender `                        -Body $Bodytstring  `                        -Subject $subjectstring -IsBodyHtml
        }
    else
    {
    write-host there is enough Place in Content DBs for Sitecollection in $WebApplication
    }
}

foreach ($Webapp in $XML.config.controlContendDBs.Webapplications.Webapplication )
{Checkandcreate-ContentDBs -WebApplication $Webapp.name -Warningcounter $Webapp.Warningcount -DBPrefix $Webapp.ContentDBprefix }


