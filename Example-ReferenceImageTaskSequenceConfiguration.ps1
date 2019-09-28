#Configure the Reference Image Task Sequence 
$MDTPath = "$((get-volume -FileSystemLabel MDT).DriveLetter):\"
$deploymentshare = "ImageFactory$"
$deploymentfolder = join-path -path $MDTPath -childpath $deploymentshare
$networkPath = "\\$($env:computername)\$($deploymentshare)"
Add-PSSnapin -Name Microsoft.BDD.PSSnapIn  
New-PSDrive -Name "DS002" -PSProvider "MDTProvider" -Root $deploymentfolder -Description "ImageFactory" -NetworkPath $networkPath -Verbose

#Connect to the task sequence XML
$TaskID = "REFW10-X64-001"
$sequencepath = "DS002:\Task Sequences\REF\Windows 10 Pro x64 v1903"
$ControlFolder = join-path -path $DeploymentFolder -childpath "Control"
$TSFolder = join-path -path $ControlFolder -childpath $TaskID
$TSXMLPath = join-path -path $TSFolder -childpath "ts.xml"
$TSXML = [xml](Get-Content -Path $TSXMLPath)

#1. Postinstall. After the Configure action, add a Run Command Line action with the following settings:Name: Disable Windows Store Updates
[System.XML.XMLElement]$DWSU = $TSXML.CreateElement("step")
$DWSU.SetAttribute("name","Disable Windows Store Updates")
$DWSU.SetAttribute("disable","false")
$DWSU.SetAttribute("continueOnError","false")
$DWSU.SetAttribute("successCodeList","0 3010")
$DWSU.SetAttribute("description","")
$DWSU.SetAttribute("startIn","")
$DWSU.SetAttribute("type","SMS_TaskSequence_RunCommandLineAction")
$action = $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\Config-DisableWindowsStoreUpdates.wsf"'
$DWSU.AppendChild($action)
$Configure = $TSXML.sequence.group.Where({$_.name -eq "PostInstall"}).step.where({$_.name -eq "Configure"})[0]
($TSXML.sequence.group.Where({$_.name -eq "PostInstall"}))[0].InsertAfter($DWSU,$Configure)

#2. State Restore. After the Tattoo action, add a new Group action with the following setting:Name: Custom Tasks (Pre-Windows Update)
[System.XML.XMLElement]$CTPWU = $TSXML.CreateElement("group")
$CTPWU.SetAttribute("name","Custom Tasks (Pre-Windows Update)")
$CTPWU.SetAttribute("disable","false")
$CTPWU.SetAttribute("continueOnError","false")
$CTPWU.SetAttribute("description","")
$CTPWU.SetAttribute("expand","true")
$action = $TSXML.CreateElement("action")
$CTPWU.AppendChild($action)
$Tattoo = $TSXML.sequence.group.Where({$_.name -eq "State Restore"}).step.where({$_.name -eq "Tattoo"})[0]
($TSXML.sequence.group.Where({$_.name -eq "State Restore"}))[0].InsertAfter($CTPWU,$Tattoo)

#3. State Restore. Enable the Windows Update (Pre-Application Installation) action.
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).step.where({$_.name -eq "Windows Update (Pre-Application Installation)"}).setAttribute("disable","false")

#4. State Restore. Enable the Windows Update (Post-Application Installation) action.
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).step.where({$_.name -eq "Windows Update (Post-Application Installation)"}).setAttribute("disable","false")

#5. State Restore. After the Windows Update (Post-Application Installation) action, rename the existing Custom Tasks group to Custom Tasks (Post-Windows Update).
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks"}).setAttribute("name","Custom Tasks (Post-Windows Update)")

#6. State Restore / Custom Tasks (Pre-Windows Update). Add a new Install Roles and Features action with the following settings:Name: Install – Microsoft NET Framework 3.5.1
[System.XML.XMLElement]$NET35 = $TSXML.CreateElement("step")
$NET35.SetAttribute("type","BDD_InstallRoles")
$NET35.SetAttribute("name","Install - Microsoft NET Framework 3.5.1")
$NET35.SetAttribute("description","")
$NET35.SetAttribute("disable","false")
$NET35.SetAttribute("continueOnError","false")
$NET35.SetAttribute("runIn","WinPEandFullOS")
$NET35.SetAttribute("successCodeList","0 3010")
$varList = $TSXML.CreateElement("defaultVarList")
$var1 = $TSXML.CreateElement("variable")
$var1.setAttribute("name","OSRoleIndex")
$var1.setAttribute("property","OSRoleIndex")
$var1.InnerText = "13"
$varlist.AppendChild($var1)
$var2 = $TSXML.CreateElement("variable")
$var2.setAttribute("name","OSRoles")
$var2.setAttribute("property","OSRoles")
$varlist.AppendChild($var2)
$var3 = $TSXML.CreateElement("variable")
$var3.setAttribute("name","OSRoleServices")
$var3.setAttribute("property","OSRoleServices")
$varlist.AppendChild($var3)
$var4 = $TSXML.CreateElement("variable")
$var4.setAttribute("name","OSFeatures")
$var4.setAttribute("property","OSFeatures")
$var4.innerText = "NetFx3"
$varlist.AppendChild($var4)
$NET35.AppendChild($varlist)
$action = $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf"'
$NET35.AppendChild($action)
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks (Pre-Windows Update)"})[0].appendchild($NET35)

#7. State Restore – Custom Tasks (Pre-Windows Update) - Install – Microsoft Visual C++ – x86-x64
$APPVCGUID = Get-ItemProperty ds002:\applications\VCRedistBundle -Name GUID | Select-Object -ExpandProperty GUID
$APPVC = $TSXML.CreateElement("step")
$APPVC.SetAttribute("type","BDD_InstallApplication")
$APPVC.SetAttribute("name","Install - Microsoft Visual C++ Runtimes")
$APPVC.SetAttribute("description","")
$APPVC.SetAttribute("disable","false")
$APPVC.SetAttribute("continueOnError","false")
$APPVC.SetAttribute("runIn","WinPEandFullOS")
$APPVC.SetAttribute("successCodeList","0 3010")
$varList = $TSXML.CreateElement("defaultVarList")
$var1 = $TSXML.CreateElement("variable")
$var1.setAttribute("name","ApplicationGUID")
$var1.setAttribute("property","ApplicationGUID")
$var1.innerText = $APPVCGUID
$varList.appendchild($var1)
$var2 = $TSXML.CreateElement("variable")
$var2.setAttribute("name","ApplicationSuccessCodes")
$var2.setAttribute("property","ApplicationSuccessCodes")
$var2.innerText = '0 3010'
$varList.appendchild($var2)
$APPVC.AppendChild($varList)
$action =  $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"'
$APPVC.appendchild($action)
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks (Pre-Windows Update)"})[0].appendchild($APPVC)

#7. State Restore – Custom Tasks (Pre-Windows Update) - Install – Microsoft LAPS
$APPLAPSGUID = Get-ItemProperty ds002:\applications\LAPS -Name GUID | Select-Object -ExpandProperty GUID
$APPLAPS = $TSXML.CreateElement("step")
$APPLAPS.SetAttribute("type","BDD_InstallApplication")
$APPLAPS.SetAttribute("name","Install - Microsoft LAPS")
$APPLAPS.SetAttribute("description","")
$APPLAPS.SetAttribute("disable","false")
$APPLAPS.SetAttribute("continueOnError","false")
$APPLAPS.SetAttribute("runIn","WinPEandFullOS")
$APPLAPS.SetAttribute("successCodeList","0 3010")
$varList = $TSXML.CreateElement("defaultVarList")
$var1 = $TSXML.CreateElement("variable")
$var1.setAttribute("name","ApplicationGUID")
$var1.setAttribute("property","ApplicationGUID")
$var1.innerText = $APPLAPSGUID
$varList.appendchild($var1)
$var2 = $TSXML.CreateElement("variable")
$var2.setAttribute("name","ApplicationSuccessCodes")
$var2.setAttribute("property","ApplicationSuccessCodes")
$var2.innerText = '0 3010'
$varList.appendchild($var2)
$APPLAPS.AppendChild($varList)
$action =  $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"'
$APPLAPS.appendchild($action)
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks (Pre-Windows Update)"})[0].appendchild($APPLAPS)

#8. State Restore – Custom Tasks (Pre-Windows Update) add a Computer Restart action.
$Reboot = $TSXML.CreateElement("step")
$Reboot.SetAttribute("type","SMS_TaskSequence_RebootAction")
$Reboot.SetAttribute("name","Restart Computer")
$Reboot.SetAttribute("description","")
$Reboot.SetAttribute("disable","false")
$Reboot.SetAttribute("continueOnError","false")
$Reboot.SetAttribute("runIn","WinPEandFullOS")
$Reboot.SetAttribute("successCodeList","0 3010")
$varList = $TSXML.CreateElement("defaultVarList")
$var1 = $TSXML.CreateElement("variable")
$var1.setAttribute("name","SMSRebootMessage")
$var1.setAttribute("property","Message")
$varList.appendchild($var1)
$var2 = $TSXML.CreateElement("variable")
$var2.setAttribute("name","SMSRebootTimeout")
$var2.setAttribute("property","MessageTimeout")
$var2.innerText = "60"
$varList.appendchild($var2)
$var3 = $TSXML.CreateElement("variable")
$var3.setAttribute("name","SMSRebootTarget")
$var3.setAttribute("property","Target")
$varList.appendchild($var3)
$Reboot.appendchild($varlist)
$action =  $TSXML.CreateElement("action")
$action.innerText = "smsboot.exe /target:WinPE"
$Reboot.appendchild($action)
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks (Pre-Windows Update)"})[0].appendchild($Reboot)

#9. State Restore. After the Apply Local GPO Package action, add a new Group action with the following setting:Name: Custom Tasks (Cleanup)
[System.XML.XMLElement]$CTT = $TSXML.CreateElement("group")
$CTT.SetAttribute("name","Custom Tasks (Cleanup)")
$CTT.SetAttribute("disable","false")
$CTT.SetAttribute("continueOnError","false")
$CTT.SetAttribute("description","")
$CTT.SetAttribute("expand","true")
$action = $TSXML.CreateElement("action")
$CTPWU.AppendChild($action)
$ApplyLocalGPO = $TSXML.sequence.group.Where({$_.name -eq "State Restore"}).step.where({$_.name -eq "Apply Local GPO Package"})[0]
($TSXML.sequence.group.Where({$_.name -eq "State Restore"}))[0].InsertAfter($CTT,$ApplyLocalGPO)

#10. State Restore – Custom Tasks (Cleanup). Add a new Install Application action with the following settings
$APPWSUSGUID = Get-ItemProperty ds002:\applications\actions\Action-WSUSFactoryReset -Name GUID | Select-Object -ExpandProperty GUID
$APPWSUS = $TSXML.CreateElement("step")
$APPWSUS.SetAttribute("type","BDD_InstallApplication")
$APPWSUS.SetAttribute("name","Action - Clean Wsus Config")
$APPWSUS.SetAttribute("description","")
$APPWSUS.SetAttribute("disable","false")
$APPWSUS.SetAttribute("continueOnError","false")
$APPWSUS.SetAttribute("runIn","WinPEandFullOS")
$APPWSUS.SetAttribute("successCodeList","0 3010")
$varList = $TSXML.CreateElement("defaultVarList")
$var1 = $TSXML.CreateElement("variable")
$var1.setAttribute("name","ApplicationGUID")
$var1.setAttribute("property","ApplicationGUID")
$var1.innerText = $APPWSUSGUID
$varList.appendchild($var1)
$var2 = $TSXML.CreateElement("variable")
$var2.setAttribute("name","ApplicationSuccessCodes")
$var2.setAttribute("property","ApplicationSuccessCodes")
$var2.innerText = '0 3010'
$varList.appendchild($var2)
$APPWSUS.AppendChild($varList)
$action =  $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"'
$APPWSUS.appendchild($action)
$TSXML.sequence.group.Where({$_.name -eq "State Restore"}).group.where({$_.name -eq "Custom Tasks (Cleanup)"})[0].appendchild($APPWSUS)

#11. State Restore / Imaging / Capture Image. After the Gather local only action, add a Run Command Line action
# Enable Windows Store Updates
[System.XML.XMLElement]$EWSU = $TSXML.CreateElement("step")
$EWSU.SetAttribute("name","Enable Windows Store Updates")
$EWSU.SetAttribute("disable","false")
$EWSU.SetAttribute("continueOnError","false")
$EWSU.SetAttribute("successCodeList","0 3010")
$EWSU.SetAttribute("description","")
$EWSU.SetAttribute("startIn","")
$EWSU.SetAttribute("type","SMS_TaskSequence_RunCommandLineAction")
$action = $TSXML.CreateElement("action")
$action.InnerText = 'cscript.exe "%SCRIPTROOT%\Config-EnableWindowsStoreUpdates.wsf"'
$EWSU.AppendChild($action)
$GatherLocalOnly = ($TSXML.sequence.group.Where({$_.name -eq "State Restore"})).group.where({$_.name -eq "Imaging"}).group.where({$_.name -eq "Capture Image"}).step.where({$_.name -eq "Gather Local Only"})[0]
($TSXML.sequence.group.Where({$_.name -eq "State Restore"})).group.where({$_.name -eq "Imaging"}).group.where({$_.name -eq "Capture Image"})[0].InsertAfter($EWSU,$GatherLocalOnly)

#Save the TS.xml
$TSXML.Save($TSXMLPath)
