## WIM Import Automation

This script will do the following
1. Find all the WIM files in the Capures folder of the ImageFactory
2. Examine the WIM file to pull the information about the Installation: Client or Server, Version: example 10.0.18362, and the Created Date
3. Create the Operating System folder structure in the Production MDT deployment share
4. Import the WIM files, if they are already not imported, you can run this script over and over again, nightly even.
5. Rename the WIM files to change the default MDT name, and make them more "calculable" for automating Task Sequence Updates

It has these parameters, which I have defaults for, but you should change:

```
$ProdPath    = "X:\Production$",
$ProdDesc    = "Production",
$ProdPSDrive = "DS003",
$RefPath     = "X:\ImageFactory$",
$RefDesc     = "ImageFactory",
$RefPSDrive  = "DS002",
$LogPathRoot = "X:\ScriptLogs"
```    

#Operating System Folder After:
![OSAfter](https://github.com/BronsonMagnan/MDTAutomation/blob/master/WimImportAutomation/OperatingSystemsFolderAfter.png)


## How it Works

1. The WimImportAutomation creates two members of class MDTDeploymentShare, One Production, and One Reference.
2. The WimImportAutomation class asks the Reference instance to send over a collection of class CapturedWim using the GetCapturedWim method. When these CapturedWim objects are instantiated, they contain a composition of the WimInfo class, which is created. When the WimInfo class has ProcessInfo called, it is a wrapper for the DISM executable.
3. The WimImportAutomation class then takes the collection of CapturedWim objects and sends them to Production MDTDeploymentShare using the method ImportOperatingSystem. 
4. The WimImportAutomation class then askes the Production instance to rename the operating system with method RenameOperatingSystem.
5. Inside the MDTDeploymentShare class, there is getting, testing, and setting of the operating system folder structure to make it idempotent, and then the MDT OS Import comamnd is called.

# UML Diagram
![UML](https://github.com/BronsonMagnan/MDTAutomation/blob/master/WimImportAutomation/UML.png)

