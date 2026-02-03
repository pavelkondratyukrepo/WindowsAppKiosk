#region Initialization
[string]$SoftwareVendor = 'Microsoft'
[string]$SoftwareDisplayName = 'Visual C++ Redistributables'
[string]$SoftwareName = $SoftwareDisplayName.Replace(' ', '')
[uri]$SoftwareDownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
[string]$ref = 'https://docs.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170#install-the-redistributable-packages'
[string]$InstallArguments = "/install /quiet /norestart"
[string]$Script:DownloadDir = "$env:SystemRoot\SystemTemp"
# Logging Configuration
[String]$Script:LogDir = "$($env:SystemRoot)\Logs\Software"
[string]$Script:LogName = $SoftwareVendor + "_" + $SoftwareName + "_Install.log"
If (-not(Test-Path -Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Dir -Force | Out-Null
}

#endregion

#region Supporting Functions

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputDirectory,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$OutputFileName
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Verbose "Starting ${CmdletName} with the following parameters: $PSBoundParameters"
        $ProgressPreference = 'SilentlyContinue'
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Verbose "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {

                $OutputFileName = split-path -path $url -leaf
                Write-Verbose "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Verbose "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect = $false
                $response = $request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Verbose "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Verbose "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"", "")
                        Write-Verbose "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            Write-Verbose "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Verbose "${CmdletName}: Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Verbose "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    Return $OutputFile
                }
            }
            Catch {
                Write-Error "${CmdletName}: Error downloading file. Please check url."
                Return $Null
            }
        }
        Else {
            Write-Error "${CmdletName}: No OutputFileName specified. Unable to download file."
            Return $Null
        }
    }
    End {
        Write-Verbose "Ending ${CmdletName}"
    }
}

#endregion

## MAIN
Start-Transcript -Path "$Script:LogDir\$Script:LogName" -Force

# Check if EXE file exists in script directory (offline installation)
$LocalExe = Get-ChildItem -Path $PSScriptRoot -Filter *.exe -ErrorAction SilentlyContinue

If ($LocalExe) {
    Write-Output "Visual C++ Redistributables EXE package found in $PSScriptRoot"
    $pathExe = $LocalExe.FullName
    $UseLocal = $true
}
Else {
    Write-Output "Visual C++ Redistributables EXE package not found in $PSScriptRoot"
    Write-Output "Attempting to download from '$SoftwareDownloadUrl'"
    $tempDir = Join-Path -Path $Script:DownloadDir -ChildPath $SoftwareName
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    $pathExe = Get-InternetFile -url $SoftwareDownloadUrl -OutputDirectory $tempDir
    If (-not (Test-Path -Path $pathExe)) {
        Write-Error "Visual C++ Redistributables EXE package could not be downloaded"
        Stop-Transcript
        Exit 1
    }
    Write-Output "Visual C++ Redistributables EXE package downloaded to: $pathExe"
    $UseLocal = $false
}

Write-Output "Starting '$SoftwareDisplayName' installation and configuration in accordance with:"
Write-Output "     '$ref'."      
Write-Output "Installing '$SoftwareDisplayName' via cmdline:"
Write-Output "     '$pathExe $InstallArguments'"
$Installer = Start-Process -FilePath $pathExe -ArgumentList $InstallArguments -Wait -PassThru
If ($($Installer.ExitCode) -eq 0) {
    Write-Output "'$SoftwareDisplayName' installed successfully."
}
Elseif ($($Installer.ExitCode) -eq 3010) {
    Write-Output "The Installer exit code is $($Installer.ExitCode). A reboot is required."
}
Else {
    Write-Error "The Installer exit code is $($Installer.ExitCode)"
}
Write-Output "Completed '$SoftwareDisplayName' Installation."

# Only remove temp directory if file was downloaded (not local)
If (-not $UseLocal -and $tempDir -and (Test-Path -Path $tempDir)) {
    Start-Sleep -Seconds 10
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Stop-Transcript