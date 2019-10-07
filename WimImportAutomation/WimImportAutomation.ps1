param(
    $ProdPath = "X:\Production$",
    $ProdDesc = "Production",
    $ProdPSDrive = "DS003",
    $RefPath = "X:\ImageFactory$",
    $RefDesc = "ImageFactory",
    $RefPSDrive = "DS002",
    $LogPathRoot = "X:\ScriptLogs"
)
<#
This script will do the following
1. Find all the WIM files in the Capures folder of the ImageFactory
2. Examine the WIM file to pull the information about the 
    Installation: Client or Server
    Version: 10.0.18362
    Created Date
    The wiminfo class has methods to get other parameters as well
3. Create the Operating System folder structure in the Production MDT deployment share
4. Import the WIM files, if they are already not imported, you can run this script over and over again, nightly even.
5. Rename the WIM files to change the default MDT name, and make them more "calculable" for automating Task Sequence Updates
#>

#region wiminfo class

class WimInfo {
    [string]$WimFile
    [byte]$Index
    hidden [string[]]$DismResult
    WimInfo([String]$WimFile,[Byte]$Index) {
        $this.WimFile = $WimFile
        $this.Index = $Index
    }
    [void]ProcessInfo() {
        $DISM = "c:\windows\system32\Dism.exe"
    	$ArgList = "/Get-WimInfo /WimFile:$($this.WimFile) /index:$($this.Index)"
    	$tempfile = New-TemporaryFile
    	remove-item -path $tempfile.fullname
    	new-item -itemType file -path $tempfile.fullname	
    	Start-Process -FilePath $DISM -ArgumentList $ArgList -NoNewWindow -Wait -RedirectStandardOutput $tempfile.FullName | out-null
    	$this.DismResult = get-content $tempfile.FullName
    }
    hidden [string]Parse($ParseTest) {
        $text = ($this.DismResult | Select-String -Pattern $ParseTest | Select-Object -first 1).tostring().replace($ParseTest,"")
        return $text
    }
    [string]GetVersion() {
        return $this.Parse("Version : ")
    }
    [string]GetArchitecture() {
        return $this.Parse("Architecture : ")
    }
    [string]GetInstallation() {
        return $this.Parse("Installation : ")
    }
    [string]GetEdition() {
        return $this.Parse("Edition : ")
    }
    [string]GetServicePack() {
        return $this.Parse("ServicePack Build : ") 
    }
    [string]GetName() {
        return $this.Parse("Name : ") 
    }
    [string]GetCreated() {
        return $this.Parse("Created : ")
    }
    [datetime]GetDismCreatedDateTime(){
        $stamp = $this.GetCreated()
        $date = $stamp.split("-")[0].trim()
        $time = $stamp.split("-")[1].trim()
        $month = $date.split("/")[0]
        $day = $date.split("/")[1]
        $year = $date.split("/")[2]
        $timepart = $time.split(" ")[0]
        $ampm = $time.split(" ")[1]
        $timepart.split(":")
        $hour = $timepart.split(":")[0]
        $min =  $timepart.split(":")[1]
        $sec =  $timepart.split(":")[2]
        if ($ampm.ToUpper() -eq "PM")  { $hour += 12 }
        return [datetime]::new($year,$month,$day,$hour,$min,$sec)
    }
}

#endregion wiminfo

#region logging class 

    class Log {
        [string]$LogFolderRoot
        [string]$LogName
        [string]$LogFolder
        [boolean]$EchoConsole
        hidden [string] $LogFileName
        Log ([string]$LogFolderRoot,[string]$LogName,[boolean]$EchoConsole) {
            $this.LogFolderRoot = $LogFolderRoot
            $this.LogName = $LogName
            $this.EchoConsole = $EchoConsole
            $this.LogFolder = join-path -path $LogFolderRoot -ChildPath $LogName
            #Check if root folder exists, if not create it
            if (-not(test-path $this.LogFolderRoot -ErrorAction SilentlyContinue)) {
                new-item -ItemType Directory -Path $this.LogFolderRoot | out-null
            }
            #Check if this log's folder exists, if not create it
            if (-not(test-path $this.LogFolder -ErrorAction SilentlyContinue)) {
                new-item -ItemType Directory -Path $this.LogFolder | out-null
            }
            #Create this log file
            $this.LogFileName = join-path -Path $this.LogFolder -ChildPath $("$($this.LogName)-{0:yyyyMMddHHmmss}.log" -f (get-date))
            "Intializing Log $($this.LogName) on $(get-date)" | Set-Content -Path $this.LogFileName -Force
        }
        [void]Write($message){
            $formatOutput = "[{0:yyyy/MM/dd-HH:mm:ss}]: $message" -f (get-date)
            if ($this.EchoConsole) { write-host $formatOutput }
            $formatOutput | Add-Content -Path $this.LogFileName
        }
    }
#endregion

#region MDTDeploymentShare class 
    
class MDTDeploymentShare {
    [string]$PSDriveName
    [string]$DiskPath
    [string]$NetworkPath
    [string]$Description
    MDTDeploymentshare([String]$PSDriveName, [string]$Path, [string]$Description) {
        $this.PSDriveName = $PSDriveName
        $this.DiskPath = $Path
        $this.Description = $Description
        $this.NetworkPath = get-smbshare | Where-Object {$_.Path -eq $this.DiskPath}
        if (-not(Get-PSSnapin | Where-Object {$_.name -eq "Microsoft.BDD.PSSnapIn"})) {
            Add-PSSnapin -Name Microsoft.BDD.PSSnapIn  
        }
        if (-not (Get-PSDrive | Where-Object {$_.name -eq $this.PSDrive} )) {
            New-PSDrive -Name "$($this.PSDriveName)" -PSProvider "MDTProvider" -Root $this.DiskPath -Description $this.Description -NetworkPath $this.networkPath -Verbose
        }
    }
    [string]getCapturesFolder() {
        return (join-path -path $this.DiskPath -ChildPath "Captures")
    }
    [CapturedWim[]]getCapturedWims() {
        $results = @()
        $results += get-childitem -Path $this.getCapturesFolder() | Where-Object {$_.name -like "*.wim"} | Select-Object -ExpandProperty FullName
        [CapturedWim[]]$Wims = @()
        foreach ($result in $results) {
            $Wims += [CapturedWim]::new($result) 
        }
        return $Wims
    }
    [string]GetOperatingSystemsFolder() {
        return (join-path -path "$($this.PSDriveName):" -ChildPath "Operating Systems")
    }
    [string]GetOperatingSystemsFolderStructure([string]$Installation,[string]$Version) {
        return (join-path -path (join-path -path $this.GetOperatingSystemsFolder() -ChildPath $Installation) -ChildPath $Version)
    }
    [string]GetOperatingSystemsFolderStructure([string]$Installation) {
        return (join-path -path $this.GetOperatingSystemsFolder() -ChildPath $Installation)
    }
    [string]GetOperatingSystemsFolderStructure([CapturedWim]$WinObj) {
        return (join-path -path (join-path -path $this.GetOperatingSystemsFolder() -ChildPath $WinObj.WimInfo.GetInstallation()) -ChildPath $Winobj.WimInfo.GetVersion())
    }
    [boolean]TestOperatingSystemsFolderStructure([CapturedWim]$WinObj) {
        return (test-path -path $this.GetOperatingSystemsFolderStructure([CapturedWim]$WinObj) -ErrorAction SilentlyContinue) 
    }
    [boolean]TestOperatingSystemsFolderStructure([string]$Installation,[string]$Version) {
        return (test-path -path $this.GetOperatingSystemsFolderStructure($Installation,$Version) -ErrorAction SilentlyContinue) 
    }
    [boolean]TestOperatingSystemsFolderStructure([string]$Installation) {
        return (test-path -path $this.GetOperatingSystemsFolderStructure($Installation) -ErrorAction SilentlyContinue) 
    }
    [void]SetOperatingSystemsFolderStructure([string]$Installation) {
        if (-not($this.TestOperatingSystemsFolderStructure($Installation))) {
            new-item -ItemType Directory -Path $this.GetOperatingSystemsFolderStructure($Installation)
        }
    }
    [void]SetOperatingSystemsFolderStructure([string]$Installation,[string]$Version) {
        if (-not($this.TestOperatingSystemsFolderStructure($Installation))) {
            new-item -ItemType Directory -Path $this.GetOperatingSystemsFolderStructure($Installation)
        }
        if (-not($this.TestOperatingSystemsFolderStructure($Installation,$Version))) {
            new-item -ItemType Directory -Path $this.GetOperatingSystemsFolderStructure($Installation,$Version)
        }
    }
    [boolean]TestImportOperatingSystem([CapturedWim]$WimObj) {
            #We need the real folder struction, not the PSDrive path.
            #We are checking to see if this WIM has been previously imported.
            $testpath = join-path -path (join-path -path $this.DiskPath -ChildPath "Operating Systems") -ChildPath $WimObj.GetFolderName()
            if (test-path -Path $testpath -ErrorAction SilentlyContinue) {
                return $true
            } else { 
                return $false
            }
    }
    [boolean]ImportOperatingSystem([CapturedWim]$WimObj) {
        [String]$LogMessage=""
        $this.SetOperatingSystemsFolderStructure($WimObj.WimInfo.GetInstallation(),$WimObj.WimInfo.GetVersion())
        $Splat = @{
            "Path" = $this.GetOperatingSystemsFolderStructure($WimObj)
            "SourceFile" = $WimObj.Path
            "DestinationFolder" = $WimObj.getFolderName()
        }
        if ($this.TestImportOperatingSystem($WimObj)) {
            return $false
        } else {
            Import-MDTOperatingSystem -Verbose @Splat
            return $true
        }
    }
    [boolean]TestOperatingSystemName([CapturedWim]$WimObj,[string]$NewName) {
        [string]$WimFile = Get-ChildItem -path $this.GetOperatingSystemsFolderStructure($WimObj) | Select-Object -ExpandProperty Name
        [string]$ReplacePath = join-path -path $this.GetOperatingSystemsFolderStructure($WimObj) -ChildPath $NewName
        if (test-path -path $ReplacePath -ErrorAction SilentlyContinue) {
            return $true 
        } else {
            return $false
        }
    }
    [void]RenameOperatingSystem([CapturedWim]$WimObj,[string]$NewName) {
        if (-not($this.TestOperatingSystemName([CapturedWim]$WimObj,[string]$NewName))) {
            [string]$WimFile = Get-ChildItem -path $this.GetOperatingSystemsFolderStructure($WimObj) | Select-Object -ExpandProperty Name
            [string]$FullPath = join-path -path $this.GetOperatingSystemsFolderStructure($WimObj) -ChildPath $WimFile
            Rename-Item -path $FullPath -NewName $NewName
        }
    }
}

#endregion 

#region CapturedWim class 
class CapturedWim {
    [string]$Path
    [byte]$Index
    [WimInfo]$WimInfo
    [string]$Release 
    CapturedWim([string]$Path) {
        $this.Path = $Path
        $this.Index = Get-WindowsImage -ImagePath $this.path | Select-Object -ExpandProperty ImageIndex
        $this.WimInfo = [WimInfo]::new($this.path, $this.Index)
        $this.WimInfo.ProcessInfo()
    }
    [string]GetFolderName(){
        return "$($this.WimInfo.GetVersion())-{0:yyyyMMddHHmmss}" -f $($this.WimInfo.GetDismCreatedDateTime())
    }
}
#endregion


class WimImportAutomation {
    hidden [log]$Log
    hidden [MDTDeploymentShare] $Production
    hidden [MDTDeploymentShare] $Reference
    hidden [CapturedWim[]] $CapturedWims
    WimImportAutomation([String]$ProdPath,[String]$ProdDesc,[String]$ProdPSDrive,[String]$RefPath,[String]$RefDesc,[String]$RefPSDrive,[String]$LogPathRoot) {
        $this.log = [log]::new($LogPathRoot, "WimImportAutomation", $true) 
        $This.log.Write("Connecting to DeploymentShare $ProdDesc")
        $this.Production = [MDTDeploymentShare]::new($ProdPSDrive,$ProdPath,$ProdDesc)
        $This.log.Write("Connecting to DeploymentShare $RefDesc")
        $this.Reference = [MDTDeploymentShare]::new($RefPSDrive,$RefPath,$RefDesc)
    }
    [void]main(){
        $this.log.Write("Finding Captured Wims")
        $this.CapturedWims = $this.Reference.getCapturedWims()
        $this.CapturedWims.foreach({
            $this.log.write("Found Wim: " + $_.wiminfo.getName() + " Created on: " + $_.wiminfo.getDismCreatedDateTime())
        })
        $this.CapturedWims.foreach({
            $this.log.write("Importing Operating System: " + $_.WimInfo.GetName() + " into folder: " + $this.Production.GetOperatingSystemsFolderStructure($_)) ; 
            $result = $this.Production.ImportOperatingSystem($_) 
            if (!$result) {
                $this.log.write("Already Imported: " + $_.WimInfo.GetName() + " into folder: " + $this.Production.GetOperatingSystemsFolderStructure($_)) ; 
            } else {
                $this.log.write("Renaming Operating System to: " + $_.GetFolderName() + ".wim")
                $this.Production.RenameOperatingSystem($_, $_.GetFolderName() + ".wim")
            }
        })
    }
}

 
$Application = [WimImportAutomation]::new($ProdPath,$ProdDesc,$ProdPSDrive,$RefPath,$RefDesc,$RefPSDrive,$LogPathRoot)
$Application.main()

