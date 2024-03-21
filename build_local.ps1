using namespace System.Management.Automation

# class ValidFilesGenerator : IValidateSetValuesGenerator {
#   [string[]] GetValidValues() {
#       $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | where-object {($_.FullName -cmatch "Composants") -eq $false} | Select-Object {$_.BaseName}
#       return $Values
#   }
# }

param(
  [string]$Projet,
  [switch]$Verbose,
  [string]$SVN,
  [string]$BDSCOMMONDIR
) 


<#
  Déclarations des variables globales et "visuelles"
#>

$sourcedir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 

$Script:report = @()

if (([string]$env:USERNAME).ToLower().Contains("jenkins")) {
  <#
     Passage de paramètres pour gradle
  #>
  $env:BDS = `""C:\Program Files (x86)\Embarcadero\RAD Studio\7.0`""
  $env:BDSCOMMONDIR = "$($BDSCOMMONDIR)"
  $env:SVN = "$($SVN)"
  $env:COMMIT = "$($SVN)"
  $env:COMP = "$($env:SVN)\composants"
}
else {
  <#
     Fixer les variables d'environnement. (Version Desktop)
  #>
  $env:BDS = "C:\Program Files (x86)\Embarcadero\RAD Studio\7.0"
  $env:BDSCOMMONDIR = "$($env:USERPROFILE)\Documents\RAD Studio\7.0"
  $env:SVN = "$sourcedir"
  $env:COMMIT = "$($env:SVN)"
  $env:COMP = "$($env:SVN)\composants"
}

<#
  Construire la variable d'environnement "DCC_UnitSearchPath"
  Elle est séparée des autres car (uniquement sous Win11), Delphi ne la construit pas correctement, ce qui empêche le build.
  Elle contient les chemins de recherches nécessaires pour trouver les dépendances des différents projets.

  TODO : Trouver pourquoi ça ne pose problème QU'EN Win10.

  Tests sur Win10 et Win11 = OK
#>
$searchPath = @()

$searchPath += "C:\Program Files (x86)\Devart\ODAC for RAD Studio 2010\Bin"
$searchPath += "C:\Program Files (x86)\Devart\ODAC for RAD Studio 2010\Lib"
$searchPath += "$($env:BDS)\Imports"
$searchPath += "$($env:BDS)\include"
$searchPath += "$($env:BDS)\lib"
$searchPath += "$($env:BDS)\Lib\Indy10"
$searchPath += "$($env:COMMIT)\bin"
$searchPath += "$($env:COMP)\Autres\PerlRegex"
$searchPath += "$($env:COMP)\zlib"
$searchPath += "$($env:COMMIT)\Lib"
$searchPath += "$($env:COMP)\AccesBD\DISQLite\D2010"
$searchPath += "$($env:COMP)\Bin"
$searchPath += "$($env:COMP)\Lib"
$searchPath += "$($env:COMP)\Librairies\jcl\lib\d14"
$searchPath += "$($env:COMP)\Librairies\jcl\source\include"
$searchPath += "$($env:COMP)\Librairies\jvcl\common"
$searchPath += "$($env:COMP)\Librairies\jvcl\lib\D14"
$searchPath += "$($env:COMP)\Librairies\jvcl\Resources"
$searchPath += "$($env:COMP)\Librairies\jwa\Common"
$searchPath += "$($env:COMP)\Librairies\jwa\Includes"
$searchPath += "$($env:COMP)\Librairies\jwa\Packages\bds10"
$searchPath += "$($env:COMP)\pi\PIClasses"
$searchPath += "$($env:COMP)\pi\PIDB"
$searchPath += "$($env:COMP)\pi\PILGPI"
$searchPath += "$($env:COMP)\Librairies\jwa\Win32API"
$searchPath += "$($env:COMP)\Librairies\Imaging"
$searchPath += "$($env:COMP)\Librairies\Imaging\JpegLib"
$searchPath += "$($env:COMP)\Librairies\Imaging\Zlib"
#$searchPath | ConvertTo-Json | Out-File -FilePath "searchpath.json" 
$env:DCC_UnitSearchPath = $searchPath -join ";"
<#
  Indiquer l'emblacement du framework .Net spécifique à notre MSBuild.
#>

$FrameworkDir = 'C:\Windows\Microsoft.NET\Framework\v2.0.50727'
$env:FrameworkVersion = 'v2.0.50727'
#$env:FrameworkSDKDir = ''
$path = [regex]::Escape($FrameworkDir)
if (-not ($arrPath -match "v2.0.50727")) {
  $arrPath = $env:Path -split ';'
  $env:Path = ($arrPath + $FrameworkDir) -join ';'
}
$env:LANGDIR = 'EN'

function Get-Health {
  Write-Host "USER : $env:USERNAME"
  if (([string]$env:USERNAME).ToLower().Contains("jenkins")) {
    Write-Host "  => Build on Jenkins Slave"
  }
  else {
    Write-Host "  => Build in Dev Environment"
  }

  Write-Host "------------------Environment Variables------------------------"
  Write-Host "`$env:BDS          = $env:BDS"
  Write-Host "`$env:BDSCOMMONDIR = $env:BDSCOMMONDIR"
  Write-Host "`$env:SVN          = $env:SVN"
  Write-Host "`$env:COMP         = $env:COMP"
  Write-Host "`$env:COMMIT       = $env:COMMIT"
  Write-Host "-------------------Environment Path----------------------------"
  $env:path -split ";" | ForEach-Object {
    Write-Host $_
  }
  Write-Host "-----------------------Search  Path----------------------------"
  $env:DCC_UnitSearchPath -split ";" | ForEach-Object {
    Write-Host $_
  }
  Write-Host "-----------------------Version Powershell----------------------"
  $PSVersionTable
}

<#
  Générer un nom unique pour le fichier de log.
#>
$datelog = Get-Date -UFormat "%Y-%m-%d_%H-%M"
$logfile = "log_$($datelog)"

<#
  Fonction : Build-Project
  Paramètre : fichier .dproj à compiler

  Appelle MSBuild pour le projet (.dproj) passé en paramètre.
  Affiche éventuellement un retour écran et écrit dans le log si une erreur est rencontrée.
  En cas d'erreur, stoppe l'exécution du script et renvoit un "LASTEXITCODE" = 5
#>
function Build-Project(
  [string]$comp
) {
  $global:LASTEXITCODE = 0
  Write-Host ">>> Build Project"
  Write-Host "  >>> `$comp : $($comp)"
  if (Test-Path -Path $comp) {
    $project = $(Split-Path $comp -Leaf).PadLeft(25, " ")
    $log = Invoke-Expression "msbuild `"$($comp)`" /p:config=Release"
  
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Build of $($project) Successfull"
    }
    else {
      Write-Host "Build of $($project) Failed"
      $log | Out-File -FilePath $logfile -Append
      Write-Host "      >>> Project $project not built"
      Write-Host "      >>> Details in $logfile"
      Exit 5
    }
  }
  else {
    Write-Host "      >>> ERROR.  $($comp) not found"
    Write-Host "      >>> Project $project not built"
    EXIT 10
  }
}

<#
  Fonction : Build-Components
  Paramètre : Aucun

  Appelle Build-Project pour chaque jeu de composants nécessaire à COMMIT
  La Gestion des erreurs est réalisée dans Build-Project
#>
function Build-Components {
  Build-Project "$($env:COMP)\Librairies\jcl\packages\JclPackagesD140.groupproj"
  Build-Project "$($env:COMP)\Librairies\jcl\packages\JclPackagesD140std.groupproj"
  Build-Project "$($env:COMP)\Librairies\jvcl\packages\D14 Packages.groupproj"   
  Build-Project "$($env:COMP)\Librairies\jvcl\packages\D14 Packages Std.groupproj"   
  Build-Project "$($env:COMP)\pi\PI.groupproj"   
  Build-Project "$($env:COMP)\pi\PIStd.groupproj"   
  Build-Project "$($env:COMP)\Autres\Autres.groupproj"   
  Build-Project "$($env:COMP)\Autres\AutresStd.groupproj"   
  Build-Project "$($env:COMP)\Librairies\Mustangpeak\MP.groupproj"   
  Build-Project "$($env:COMP)\Librairies\Mustangpeak\MPStd.groupproj"   
  Build-Project "$($env:COMP)\AccesBD\zeosdbo\packages\Delphi2010\ZeosDbo.groupproj"   
  # Build-Project "$($env:COMP)\AccesBD\zeosdbo\packages\Delphi2010\ZComponentDesign.groupproj"   
  Build-Project "$($env:COMP)\AccesBD\BD.groupproj" 
  Build-Project "$($env:COMP)\AccesBD\BDStd.groupproj" 
  Build-Project "$($env:COMP)\Autres\Abbrevia 5.0\packages\Delphi 2010\Abbrevia.dproj"   
  Build-Project "$($env:COMP)\Autres\Abbrevia 5.0\packages\Delphi 2010\AbbreviaVCL.dproj"   
  Build-Project "$($env:COMP)\Autres\Abbrevia 5.0\packages\Delphi 2010\AbbreviaVCLDesign.dproj"   
}

<#
  Fonction : Build-Commit
  Paramètre : Aucun

  Se base sur le fichier commit.groupproj avin de réaliser un build COMPLET de l'application.
  REMARQUE : L'ancienne fonction appelait MSBUILD sur le .groupproj. Cependant, afin d'avoir un contrôle plus fin sur les éventuelles erreurs de build, 
  le XML (.groupproj) est parsé et les .dproj sont compilés un par un (dans le bon ordre).
  Mais avec cette méthode, on peut stopper le build dès qu'une erreur est rencontrée => gain de temps.
#>
function Build-Commit {
  Remove-Item -Path "$($env:COMMIT)\bin" -Recurse -Force -Confirm:$false -ErrorAction Ignore
  $group = ([XML](Get-Content "$($env:COMMIT)\COMMIT.groupproj"))
  $group.Project.ItemGroup.Projects | ForEach-Object {
    Build-Project "$($env:COMMIT)\$($_.Include)" 
  }
}

<#
  Fonction : Build-Dependencies
  Paramètre : Aucun

  !!!!! A n'exécuter que sur une machine de dev officielle !!!!!

  Génère un .zip contenant les bpl "runtime" de Delphi qui ne sont pas présente sur la machine de build
  du fait qu'on n'a pas utilisé l'ISO pour installer;
#>

function Build-Dependencies {
  $files = @(
    @{
      path  = "$env:BDS\bin"
      files = @("designide140.*")
    }
    @{
      path  = "$env:SystemRoot\sysWOW64"
      files = @("Indy*140.bpl", "adortl140.bpl", "bdertl140.bpl", "dbrtl140.bpl", "rtl140.bpl", "dsnap*140.bpl", "tee*140.bpl", "vcl140.bpl", "vclactnband140.bpl",
        "vcldb140.bpl", "vclimg140.bpl", "vclsmp140.bpl", "vclx140.bpl", "xmlrtl140.bpl")
    }
  )
  Write-Host "Dependecies"
  $files | ForEach-Object {
    $path = $_.path
    $_.files | ForEach-Object {
      Write-Host "$path\$_"
      Compress-Archive -DestinationPath "dependencies.zip" -Path "$path\$_" -Update
    }
  }
}

<#
  Fonction : Copy-Dependencies
  Paramètre : Aucun

  A exécuter à la fin du build, copie tous les bpl supplémentaires issus de la compilation des composants.

#>
function Copy-Dependencies {
  Write-Host "Copy dependencies ....."
  $files = @(
    @{
      path  = "C:\Program Files (x86)\Devart\ODAC for RAD Studio 2010\Bin"
      files = @("?dac*140.bpl")
    }
    @{
      path  = "$($env:COMP)\Bin"
      files = @("*.bpl")
    }
  )
  $files | ForEach-Object {
    $path = $_.path
    $_.files | ForEach-Object {
      Copy-Item -Path "$path\$_" -Destination "$($env:COMMIT)\bin\"
      Write-Host "+++ Copy $($_)"
    }
  }
}

<#
  Fonction : Expand-ThirdParties
  Paramètre : Aucun

  Décompresse les dépendances externes à commit (Third Party).
#>
function Expand-ThirdParties {
  $old = $global:ProgressPreference
  $global:ProgressPreference = 'SilentlyContinue';
  [xml]$build = Get-Content $env:SVN\commit.build
  $zip = $build | Select-Xml -XPath "//target[@name='dist']/unzip" | Select-Object -ExpandProperty node
  $zip | ForEach-Object {
    [string]$from = ([string]$_.src).replace('${env.SVN}\commit_legacy\', "$($env:COMMIT)\").replace('}', "") 
    [string]$to = ([string]$_.dest).replace('${rep_dest}', "$($env:COMMIT)").replace('}', "") 
    Write-Host "Expand From $($from) To $($to)"
    Expand-Archive -Path $from -DestinationPath $to -Force
   
  }
  $global:ProgressPreference = $old
}

function Get-DprojVersions {
  $group = ([XML](Get-Content "$($env:COMMIT)\COMMIT.groupproj"))
  $group.Project.ItemGroup.Projects | ForEach-Object {
    [XML]$project = ([XML](Get-Content "$($env:COMMIT)\$($_.Include)"))  
    $nodes = ($project.Project.ProjectExtensions.BorlandProject.'Delphi.Personality'.VersionInfoKeys).GetEnumerator()
    while ($nodes.movenext()) {
        $node = $nodes.current
        if ($node.name -eq "FileVersion"){
          Write-Host "$($env:COMMIT)\$($_.Include) => Version : $($node."#text")" 
        }
        
    }
  }
}


<#
  Switch principal => décide de ce qui est compilé sur base du paramètre $projet
#>
#Get-Health

switch ($projet) {
  # 'commit' { Build-Project "$($env:SVN)\commit_legacy\Modules\Commit\commit.dproj" }
  # 'lgo2' { Build-Project "$($env:SVN)\commit_legacy\Modules\Import\lgo2\lgo2.dproj" }
  # 'infosoft' { Build-Project "$($env:SVN)\commit_legacy\Modules\Import\infosoft\infosoft.dproj" }
  # 'groupementmenu' { Build-Project "$($env:SVN)\groupementmenu\groupementmenu.dproj" }
  # 'cession' { Build-Project "$($env:SVN)\projetcession\projetcession.dproj" }
  # 'moduleimport' { Build-Project "$($env:SVN)\commit_legacy\Modules\Commit\moduleimport.dproj" }
  # 'projet' { Build-Project "$($env:SVN)\commit_legacy\Modules\Commit\Projet.dproj" }
  'importlgpi' { Build-Project "$($env:SVN)\Modules\Import\importlgpi\importlgpi.dproj" }
  'Dependencies' {
    Build-Dependencies
    Copy-Dependencies
  }
  'composants' {
    Build-Components
  }
  'dist' {
    Build-Components
    Build-Commit
    Copy-Dependencies
    Expand-ThirdParties
  }
  'Expand' {
    Expand-ThirdParties
  }
  'all' {
    Build-Components
    Build-Commit
  }
  'check-versions' {
    Get-DprojVersions
  }
  Default {}
}
