using namespace System.Management.Automation

class ValidFilesGenerator : IValidateSetValuesGenerator {
  [string[]] GetValidValues() {
    $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | Where-Object { ($_.FullName -cmatch "Composants") -eq $false } | Select-Object { $_.BaseName }
    return $Values
  }
}
$include = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 

. "$include\visuals.ps1"

function Get-ProjectList {
  $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | Where-Object { ($_.FullName -cmatch "Composants") -eq $false }
  return $Values
}

function Build-SearchPath (
) {
  $UnitSearch = Get-Content -Path "$($include)\\searchpath.json" | Out-String | ConvertFrom-Json
  return $UnitSearch
}

function Get-DelphiEnv(
  [ValidateSet('Delphi2010','Delphi11','Delphi12')]
  [String]$Delphi
) {
  switch ($Delphi) {
    'Delphi2010' {  
      $dpath = "C:\Program Files (x86)\Embarcadero\RAD Studio\7.0"
    }
    'Delphi11' {  
      $dpath = "C:\Program Files (x86)\Embarcadero\Studio\22.0"
      
    }
    'Delphi12' {  
      $dpath = "C:\Program Files (x86)\Embarcadero\Studio\23.0"
    }
    Default {
      Write-Host "This Module ONLY supports Delphi 2010, Delphi 11 and Delphi 12 "
    }
  }
  Build-DelphiEnv -dpath $dpath
}

function Build-DelphiEnv(
  [String]$dpath
){
  $rsvars = Get-Content -Path "$dpath\bin\rsvars.bat"
  Write-Host $rsvars
  return $rsvars
}

Get-DelphiEnv -Delphi Delphi2010