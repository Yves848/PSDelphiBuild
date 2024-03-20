using namespace System.Management.Automation

class ValidFilesGenerator : IValidateSetValuesGenerator {
  [string[]] GetValidValues() {
    $Values = Get-ChildItem -Path * -Filter *.dproj -Recurse | Where-Object { ($_.FullName -cmatch "Composants") -eq $false } | Select-Object { $_.BaseName }
    return $Values
  }
}

class delphiProject {
  [boolean]$Selected
  [string]$Name
  [string]$path
  [string]$FullName
  [Boolean]$group
  [boolean]$checked
}
$include = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 

. "$include\visuals.ps1"

function Get-ProjectList(
  [switch]$Groups,
  [string]$path = "*"
) {
  if ($Groups) {
    $filter = "*.groupproj"
  }
  else {
    $filter = "*.dproj"
  }

  $Values = Get-ChildItem -Path $path -Filter $filter -Recurse | Where-Object { ($_.FullName -cmatch "Composants") -eq $false }
  return $Values
}
function makeBlanks {
  param(
    $nblines,
    $win
  )
  if ($iscoreclr) {
    $esc = "`e"
  }
  else {
    $esc = $([char]0x1b)
  }
  $blanks = 1..$nblines | ForEach-Object {
    "$esc[38;5;15m$($Single.LEFT)", "".PadRight($Win.W - 2, " "), "$esc[38;5;15m$($Single.RIGHT)" -join ""
  }
  $blanks | Out-String
}

function DisplayGrid(
  $list,
  [ref]$data

) {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 
  if ($iscoreclr) {
    $esc = "`e"
  }
  else {
    $esc = $([char]0x1b)
  }
  $totalAvailableSpace = $Host.UI.RawUI.WindowSize.Width - 10
  function  drawHeader {
    [System.Console]::setcursorposition($win.X + 1, $win.Y + 1)
    $H = " "
    
    $header = $H.PadRight($win.w - 2, ' ')
    [System.Console]::write("$esc[4m$esc[38;5;11m$($header)$esc[0m")
  }

  function drawFooter {

    [System.Console]::setcursorposition($win.X + 1, $win.H - 1)
    
    $s = ""
    $footerL = " Selected : $nbChecked"
    $footerR = "Source : [ $s ] "
    $fill = $win.w - 2 - $footerL.Length - $footerR.Length
    $f = $footerL, "".PadRight($fill, ' '), $footerR -join ""
    [System.Console]::write("$esc[48;5;19m$esc[38;5;15m$($f)$esc[0m")
  }

  function makelines {
    param (
      $list,
      $checked,
      $Deleted,
      $Updated,
      $row,
      $selected
    ) 
    
    [string]$line = ""
    
    $check = "✓ "
    $update = "↺ "
    $delete = "Ⅹ "
    
    $line = $list.Name.PadRight($totalAvailableSpace, " ")

    if ($deleted -or $Updated -or $checked) {
      if ($deleted) {
        $line = "$esc[38;5;46m$delete", $line -join ""
      }

      if ($Updated) {
        $line = "$esc[38;5;46m$Update", $line -join ""
      }
      
      if (-not $deleted -and -not $Updated) {
        if ($checked) {
          $line = "$esc[38;5;46m$check", $line -join ""
        }
      }
    }
    else {
      $line = "  ", $line -join ""
    }

    if ($row -eq $selected) {
      $line = "$esc[48;5;33m$esc[38;5;15m$($line)"
    }
    if ($row % 2 -eq 0) {
      $line = "$esc[38;5;252m$($line)"
    }
    else {
      $line = "$esc[38;5;244m$($line)"
    }
    
    "$esc[38;5;15m$($Single.LEFT)$($line)$esc[0m"
  }

  $WinWidth = [System.Console]::WindowWidth
  $X = 0
  $Y = 0
  $WinHeigt = [System.Console]::WindowHeight - 1
  $win = [window]::new($X, $Y, $WinWidth, $WinHeigt, $false, "White");
  $win.title = "Project List"
  $Win.titleColor = "Green"
  $win.footer = "$(color "[?]" "red") Help $(color "[F2]" "red") Source $(color "[Space]" "red") Select/Unselect $(color "[Enter]" "red") Accept $(color "[Esc]" "red") Quit"
  $win.drawWindow();
  $win.drawVersion();
  $nbLines = $Win.h - 3
  $blanks = makeBlanks $nblines $win
  $displayList = $list
  $skip = 0
  $nbPages = [math]::Ceiling($displayList.count / $nbLines)
  $win.nbpages = $nbPages
  $page = 1
  $selected = 0
  $nbChecked = 0
  [System.Console]::CursorVisible = $false
  $redraw = $true
  while (-not $stop) {
    $win.page = $page
    [System.Console]::setcursorposition($win.X, $win.Y + 2)
    $row = 0
    if ($displayList.length -eq 1) {
      $checked = $displayList.Selected
      $Deleted = $displayList.Deleted
      $Updated = $displayList.Updated
      $partdisplayList = makelines $displayList $checked $Deleted $Updated $row $selected
    }
    else {
      $partdisplayList = $displayList | Select-Object -First $nblines -Skip $skip | ForEach-Object {
        $index = (($page - 1) * $nbLines) + $row
        $checked = $displayList[$index].Selected
        $deleted = $displayList[$index].Deleted
        $Updated = $displayList[$index].Updated
        makelines $displayList[$index] $checked $deleted $Updated $row $selected
        $row++
      }
    }
    $nbDisplay = $partdisplayList.Length
    $sText = $partdisplayList | Out-String 
    if ($redraw) {
      [System.Console]::setcursorposition($win.X, $win.Y + 2)
      [system.console]::write($blanks)
      $redraw = $false
    }
    [System.Console]::setcursorposition($win.X, $win.Y + 2)
    [system.console]::write($sText.Substring(0, $sText.Length - 2))
    drawHeader
    drawFooter
    $win.drawPagination()
    while (-not $stop) {
      if ($global:Host.UI.RawUI.KeyAvailable) { 
        [System.Management.Automation.Host.KeyInfo]$key = $($global:host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'))
        if ($key.Character -eq '?') {
          # Help
          displayHelp $allowSearch
          $redraw = $true
        }
        if ($key.character -eq 'q' -or $key.VirtualKeyCode -eq 27) {
          # Quit
          $stop = $true
        }
        if ($key.VirtualKeyCode -eq 38) {
          # key up
          if ($selected -gt 0) {
            $selected --
          }
        }
        if ($key.VirtualKeyCode -eq 40) {
          # key Down
          if ($selected -lt $nbDisplay - 1) {
            $selected ++
          }
        }
        if ($key.VirtualKeyCode -eq 37) {
          # key Left
          if ($page -gt 1) {
            $skip -= $nbLines
            $page -= 1
            $selected = 0
            $redraw = $true     
          }
        }
        if ($key.VirtualKeyCode -eq 39) {
          # key Right
          if ($page -lt $nbPages) {
            $skip += $nbLines
            $page += 1
            $selected = 0
            $redraw = $true
          }
        }
        if ($key.VirtualKeyCode -eq 32) {
          # key Space
          if ($displayList.length -eq 1) {
            $checked = $displayList.Selected
            $displayList.Selected = -not $checked
          }
          else {
            $index = (($page - 1) * $nbLines) + $selected
            $checked = $displayList[$index].Selected
            $displayList[$index].Selected = -not $checked
          }
          if ($checked) { $nbChecked-- } else { $nbChecked++ }
        }

        if ($key.VirtualKeyCode -eq 46) {
          # delete key
          if ($allowModifications -and -not $build) {
            if ($displayList.length -eq 1) {
              $deleted = $displayList.Deleted
              $displayList.deleted = -not $deleted
            }
            else {
              $index = (($page - 1) * $nbLines) + $selected
              $Deleted = $displayList[$index].Deleted
              $displayList[$index].Deleted = -not $Deleted
            }
          }
        }

        if ($key.VirtualKeyCode -eq 85) {
          # "u" key (update)
          if ($allowModifications -and -not $build) {
            if ($displayList.length -eq 1) {
              if ($displayList.Available) {
                $Updated = $displayList.Updated
                $displayList.Updated = -not $deleted
              }
            }
            else {
              $index = (($page - 1) * $nbLines) + $selected
              if ($displayList[$index].Available -and ($displayList[$index].Available.trim() -ne "")) {
                $Updated = $displayList[$index].Updated
                $displayList[$index].Updated = -not $Updated
              }
            }
          }
        }
        if ($key.VirtualKeyCode -eq 85) {
          # "Ctrl-u" key (update)
          if ($allowModifications) {
            if (($key.ControlKeyState -band 8) -ne 0) {
              $displayList | ForEach-Object { 
                $Updated = $_.Updated
                if ($_.Available -and ($_.Available.trim() -ne "")) {
                  $_.Updated = -not $Updated
                }
              }
            }
          }
        }

        if ($key.VirtualKeyCode -eq 13) {
          # key Enter
          Clear-Host
          $data.value = $data.value = $displayList | Where-Object { $_.Selected -or $_.Deleted -or $_.Updated }
          $stop = $true
        }
        if ($key.VirtualKeyCode -eq 114) {
          # key F3
          if ($allowSearch) {
            $term = getSearchTerms
            [System.Console]::CursorVisible = $false
            $term = '"', $term, '"' -join ''
            # Todo : re-run original search
            $sb = { Invoke-Winget "winget search --name $term" | Where-Object { $_.source -eq "winget" } }
            $displayList = Invoke-Command -ScriptBlock $sb
            $skip = 0
            $nbPages = [math]::Ceiling($displayList.count / $nbLines)
            $win.nbpages = $nbPages
            $page = 1
            $selected = 0
            $redraw = $true
          }
        }
        if ($key.VirtualKeyCode -eq 113) {
          # key F2
          $sourceIdx ++
          if ($sourceIdx -gt $sources.count - 1) {
            $displayList = $list
            $sourceIdx = -1
          }
          else {
            $src = @()
            if ($sources[$sourceIdx].trim() -in ("none", "msstore")) {
              $src += ""
              $src += "msstore"
            }
            else {
              $src += $sources[$sourceIdx]
            }
            $displayList = $list | Where-Object { $src.Contains($_.source.trim()) }
            if ($displayList.count -eq 0) {
              $displayList = $list
            }
          }
          $skip = 0
          $nbPages = [math]::Ceiling($displayList.count / $nbLines)
          $win.nbpages = $nbPages
          $page = 1
          $selected = 0
          $redraw = $true
        }
        if ($key.character -eq "+") {
          # key +
          $checked = $true
          $nbChecked = 0
          $displayList | ForEach-Object { $_.Selected = $checked; $nbChecked++ }
        }
        if ($key.character -eq "-") {
          # key -
          $checked = $false
          $displayList | ForEach-Object { $_.Selected = $checked }
          $nbChecked = 0
        }
        break
      }
      Start-Sleep -Milliseconds 20
    }    
  }
  [System.Console]::CursorVisible = $true
  Clear-Host
}

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
      $log | Out-File -FilePath $global:logfile -Append
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

function Build-Selection(
  [delphiProject[]]$data
) {
  $datelog = Get-Date -UFormat "%Y-%m-%d_%H-%M"
  $global:logfile = "log_$($datelog)"
  
  Get-DelphiEnv -Delphi Delphi2010
  Build-SearchPath
  Write-Host "DCC_UnitSearchPath => $env:DCC_UnitSearchPath"

  $data | ForEach-Object {
    Build-Project $_.FullName
  }

}

function Show-ProjectList(
  [switch]$Groups
) {
  
  [delphiProject[]]$list = @()

  Get-ProjectList -path "C:\Git\commit_legacy\*" | ForEach-Object {
    [delphiProject]$dp = [delphiProject]::new()
    $dp.Name = $_.BaseName
    $dp.path = $_.DirectoryName
    $dp.FullName = $_.FullName
    $dp.checked = $false
    $dp.Selected = $false
    $dp.group = $false
    $list += $dp
  }
  $data = @()
  displayGrid -list $list -data ([ref]$data) 

  if ($data.length -gt 0) {
    Build-Selection  $data
  }
}


function Build-SearchPath (
) {
  $path = Get-Location 
  $UnitSearch = Get-Content -Path "$($path.path)\\searchpath.json" | Out-String | ConvertFrom-Json
  $searchPath = @()
  $UnitSearch | ForEach-Object {
    $searchPath += $_
  }
  [Environment]::SetEnvironmentVariable("DCC_UnitSearchPath", $searchPath -join ";")
}

function Get-DelphiEnv(
  [ValidateSet('Delphi2010', 'Delphi11', 'Delphi12')]
  [String]$Delphi
) {
  switch ($Delphi) {
    'Delphi2010' {  
      $dpath = "C:\Program Files (x86)\Embarcadero\RAD Studio\7.0"
      $env:SVN = "$(Get-Location)"
      $env:COMMIT = "$($env:SVN)"
      $env:COMP = "$($env:SVN)\composants"
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
) {
  [string[]]$rsvars = Get-Content -Path "$dpath\bin\rsvars.bat" -ErrorAction Stop
  ##Write-Host $rsvars
  $rsvars | ForEach-Object {
    if ($_.trim() -ne "") {
      $path = $_ -creplace "@SET", ""
      $var, $value = $path -split "="
      if ($var.trim() -cne 'PATH') {
        Write-Host "$var => $value"
        [Environment]::SetEnvironmentVariable($var.trim(), $value.trim())
      }
    }
  }
  $path = [regex]::Escape($env:FrameworkDir)
  if (-not ($arrPath -match $env:FrameworkVersion)) {
    $arrPath = $env:Path -split ';'
    $env:Path = ($arrPath + $env:FrameworkDir) -join ';'
  }
}
