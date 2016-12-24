Add-PSSnapin *share*

function global:transfer-ListTemplateFiles
{
    Param 
    (
    [String]$SourceURL,
    [String]$DestURL
    )
      # Set the variables        
        
        $SPsourcesite= get-spsite $SourceURL
        $SPdestsite = get-spsite $DestURL
        
        $spsourceFolder = $SPsourcesite.RootWeb.Lists["Listenvorlagenkatalog"]
        $spdestFolder = $SPdestsite.RootWeb.getfolder("Listenvorlagenkatalog")
        $spfilecollection = $spdestFolder.files
        foreach ($SpTFile in $spsourceFolder.Items)
        {
            $openBin = $SpTFile.File.OpenBinary()
            $spfilecollection.Add($SpTFile.File.Url, $openBin, $true)
        }
        
}

function global:add-PMSConfigListelement
{
    Param([String]$Listtitle,[String]$TemplateFileName)
    $NewListNode = $PMSConfig.CreateElement("List")
    $NewListNode.SetAttribute("Title", $Listtitle)
    $NewListNode.setAttribute("TemplateFileName",$TemplateFileName)
    $Subnode = $PMSConfig.config.SelectSingleNode("Templates")
    $Subnode.AppendChild($NewListNode)   
}

function global:add-PMSConfigDocumentelement
{
    Param([String]$Documenttitle,[String]$DocumentFilename, [String]$AssociatedList)
    $NewListNode = $PMSConfig.CreateElement("Document")
    $NewListNode.SetAttribute("Title", $Listtitle)
    $NewListNode.setAttribute("TemplateFileName",$Documentppath)
    $NewListNode.setAttribute("AssociatedList",$AssociatedList)
    $Subnode = $PMSConfig.config.SelectSingleNode("Templates")
    $Subnode.AppendChild($NewListNode)   
}

function global:add-SpCustomListfromTemplate
{ 
    Param([String]$DestURL) 
    $Spsite = Get-SPSite $DestURL
    $SPList = $Spsite.RootWeb.Lists["Listenvorlagenkatalog"]
    foreach ($XMLList in $PMSConfig.config.Templates.List)
    {
        $Templates = $Spsite.GetCustomListTemplates($Spsite.RootWeb)
        $Template = $Templates | ?{$_.InternalName -match $XMLList.TemplateFileName}
        $Spsite.RootWeb.Lists.Add($XMLList.Title, "", $Templates[$Template.Name])
        $NewList = $Spsite.RootWeb.Lists[$XMLList.Title]
        $NewList.OnQuickLaunch = $true
        $NewList.Update()

    }
    $SpStandardDoclib = $Spsite.Rootweb.Lists["Dokumente"]
    $SpStandardDoclib.OnQuickLaunch = $false
    $SpStandardDoclib.update()
}

function global:Modify-PMSXMLConfigfile
{
    Param([String]$Pmsconfigfile, [String]$ConfigListSite, [String]$Configlistname)
    $SPConfigList = (get-spsite $ConfigListSite).rootweb.lists[$Configlistname]
    $PMSConfig.Load($Pmsconfigfile)
    foreach ($SPconfigListitem in ($SPConfigList.Items |?{$_["Vorlagen_x0020_Kategorie"] -match "LIST_LIB_Vorlage"}))
    {
        add-PMSConfigListelement -Listtitle $SPconfigListitem.title -TemplateFileName $SPconfigListitem["TemplateDateiname"] 
    }
    foreach ($SPconfigListitem in ($SPConfigList.Items |?{$_["Vorlagen_x0020_Kategorie"] -match "Dokument_Vorlage"}))
    {
        add-PMSConfigDocumentelement -Documenttitle $SPconfigListitem.title -$DocumentFilename $SPconfigListitem["TemplateDateiname"] -AssociatedList $SPconfigListitem["Assoziierte_x0020_Bibliothek"]
    }
    $PMSConfig.save($Pmsconfigfile)
}

Function global:send-informmail
{
    Param(
        [String]$Receipient,
        [String]$Sender,
        [String]$Subject,
        [String]$Body,
        [Switch]$IsBodyHtml
        )
    $SmtpServer = new-object system.net.mail.smtpClient
    $SmtpServer.Host = $xml.config.controlContendDBs.Mailconfig.mailserver                                     # FQDN des SMTP-Servers
    $MailMessage = New-Object system.net.mail.mailmessage
    $MailMessage.from = "$($Sender)"
    $MailMessage.To.add($($Receipient))
    $MailMessage.Subject = "$subjectstring"
    if ($IsBodyHtml -eq $true){$MailMessage.IsBodyHtml = $true}
    else {$MailMessage.IsBodyHtml = $false}       
    $MailMessage.Body = $Bodytstring
    $SmtpServer.Send($MailMessage)
}