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


