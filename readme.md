# Powershell Delphi Build helper

Powershell module helping to build Delphi Projects (2010, 11 & 12) directly from the command line

## Functions

### Get-ProjectList [-Groups]
Get the list of the dproj(s) ro groupproj(s) in the current directory, recursively
Usage
```
Get-ProjectList 
```
**or**
```
Get-ProjectList -Groups
```
---
### Get-DelphiEnv -Delphi [Delphi2010,Delphi11,Delphi12]
Usage
```
Get-DelphiEnv -Delphi Delphi2010
```
---
### Build-SearchPath
Usage
```
Build-SearchPath
```
---
### Show-ProjectList [-Groups]
Usage
```
Show-ProjectList
```