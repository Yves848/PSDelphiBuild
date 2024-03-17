using namespace System.Management.Automation

class ValidFilesGenerator : IValidateSetValuesGenerator {
  [string[]] GetValidValues() {
      $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | where-object {($_.FullName -cmatch "Composants") -eq $false} | Select-Object {$_.BaseName}
      return $Values
  }
}
$include = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 

. "$include\visuals.ps1"

function Get-ProjectList{
  $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | where-object {($_.FullName -cmatch "Composants") -eq $false} | Select-Object {$_.BaseName}
      return $Values
}