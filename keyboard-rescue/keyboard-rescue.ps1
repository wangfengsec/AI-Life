<#
.SYNOPSIS
  KeyboardRescue - 键盘急救工具
  当某个按键损坏（卡键、连发、失灵）时，用软件方式替代或屏蔽它。

.DESCRIPTION
  所有操作默认安全检查，修改注册表前会备份，可随时 restore 还原。
  无需安装任何依赖，Windows 10/11 自带 PowerShell 即可运行。

.EXAMPLE
  .\keyboard-rescue.ps1 detect
  检测当前有哪些键处于 "按住不放" 的状态。

.EXAMPLE
  .\keyboard-rescue.ps1 guard -Key I
  后台吞掉 I 键的连发（Ctrl+C 停止）。

.EXAMPLE
  .\keyboard-rescue.ps1 remap -Key I -To RCTRL -Apply
  把坏掉的 I 键功能搬到右 Ctrl 上（需重启生效）。

.EXAMPLE
  .\keyboard-rescue.ps1 disable -Key I -Apply
  彻底禁用 I 键（需重启生效）。

.EXAMPLE
  .\keyboard-rescue.ps1 restore -Apply
  还原所有扫描码映射。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('detect', 'guard', 'remap', 'disable', 'restore', 'status')]
    [string]$Action,

    [string]$Key,
    [string]$To,
    [int]$Seconds = 10,
    [switch]$Apply,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$DataDir = Join-Path $env:LOCALAPPDATA 'KeyboardRescue'
$BackupFile = Join-Path $DataDir 'scancode-backup.json'
$RegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$TaskName = 'KeyboardRescue-Guard'

# ---------------------------------------------------------------- 键位表

$Scancodes = @{
    'ESC' = 0x01; '1' = 0x02; '2' = 0x03; '3' = 0x04; '4' = 0x05; '5' = 0x06
    '6' = 0x07; '7' = 0x08; '8' = 0x09; '9' = 0x0A; '0' = 0x0B; 'MINUS' = 0x0C
    'EQUAL' = 0x0D; 'BACKSPACE' = 0x0E; 'TAB' = 0x0F
    'Q' = 0x10; 'W' = 0x11; 'E' = 0x12; 'R' = 0x13; 'T' = 0x14; 'Y' = 0x15
    'U' = 0x16; 'I' = 0x17; 'O' = 0x18; 'P' = 0x19
    'LBRACKET' = 0x1A; 'RBRACKET' = 0x1B; 'ENTER' = 0x1C; 'LCTRL' = 0x1D
    'A' = 0x1E; 'S' = 0x1F; 'D' = 0x20; 'F' = 0x21; 'G' = 0x22; 'H' = 0x23
    'J' = 0x24; 'K' = 0x25; 'L' = 0x26; 'SEMICOLON' = 0x27; 'QUOTE' = 0x28
    'BACKQUOTE' = 0x29; 'LSHIFT' = 0x2A; 'BACKSLASH' = 0x2B
    'Z' = 0x2C; 'X' = 0x2D; 'C' = 0x2E; 'V' = 0x2F; 'B' = 0x30; 'N' = 0x31
    'M' = 0x32; 'COMMA' = 0x33; 'PERIOD' = 0x34; 'SLASH' = 0x35; 'RSHIFT' = 0x36
    'MULTIPLY' = 0x37; 'LALT' = 0x38; 'SPACE' = 0x39; 'CAPSLOCK' = 0x3A
    'RCTRL' = 0xE01D; 'RALT' = 0xE038; 'LWIN' = 0xE05B; 'RWIN' = 0xE05C
    'APPS' = 0xE05D; 'INSERT' = 0xE052; 'DELETE' = 0xE053; 'HOME' = 0xE047
    'END' = 0xE04F; 'PGUP' = 0xE049; 'PGDN' = 0xE051
    'UP' = 0xE048; 'DOWN' = 0xE050; 'LEFT' = 0xE04B; 'RIGHT' = 0xE04D
}

$VkNames = @{
    0x08 = 'BACKSPACE'; 0x09 = 'TAB'; 0x0D = 'ENTER'; 0x10 = 'SHIFT'; 0x11 = 'CTRL'
    0x12 = 'ALT'; 0x14 = 'CAPSLOCK'; 0x1B = 'ESC'; 0x20 = 'SPACE'
    0x25 = 'LEFT'; 0x26 = 'UP'; 0x27 = 'RIGHT'; 0x28 = 'DOWN'
    0x2D = 'INSERT'; 0x2E = 'DELETE'; 0x5B = 'LWIN'; 0x5C = 'RWIN'; 0x5D = 'APPS'
    0xA0 = 'LSHIFT'; 0xA1 = 'RSHIFT'; 0xA2 = 'LCTRL'; 0xA3 = 'RCTRL'
    0xA4 = 'LALT'; 0xA5 = 'RALT'
}

function Get-KeyName([int]$vk) {
    if ($VkNames.ContainsKey($vk)) { return $VkNames[$vk] }
    if ($vk -ge 0x30 -and $vk -le 0x39) { return [string][char]$vk }
    if ($vk -ge 0x41 -and $vk -le 0x5A) { return [string][char]$vk }
    return ('VK{0:X2}' -f $vk)
}

$VkCodes = @{
    'ESC' = 0x1B; '1' = 0x31; '2' = 0x32; '3' = 0x33; '4' = 0x34; '5' = 0x35
    '6' = 0x36; '7' = 0x37; '8' = 0x38; '9' = 0x39; '0' = 0x30
    'MINUS' = 0xBD; 'EQUAL' = 0xBB; 'BACKSPACE' = 0x08; 'TAB' = 0x09
    'Q' = 0x51; 'W' = 0x57; 'E' = 0x45; 'R' = 0x52; 'T' = 0x54; 'Y' = 0x59
    'U' = 0x55; 'I' = 0x49; 'O' = 0x4F; 'P' = 0x50
    'LBRACKET' = 0xDB; 'RBRACKET' = 0xDD; 'ENTER' = 0x0D; 'LCTRL' = 0xA2
    'A' = 0x41; 'S' = 0x53; 'D' = 0x44; 'F' = 0x46; 'G' = 0x47; 'H' = 0x48
    'J' = 0x4A; 'K' = 0x4B; 'L' = 0x4C; 'SEMICOLON' = 0xBA; 'QUOTE' = 0xDE
    'BACKQUOTE' = 0xC0; 'LSHIFT' = 0xA0; 'BACKSLASH' = 0xDC
    'Z' = 0x5A; 'X' = 0x58; 'C' = 0x43; 'V' = 0x56; 'B' = 0x42; 'N' = 0x4E
    'M' = 0x4D; 'COMMA' = 0xBC; 'PERIOD' = 0xBE; 'SLASH' = 0xBF; 'RSHIFT' = 0xA1
    'MULTIPLY' = 0x6A; 'LALT' = 0xA4; 'SPACE' = 0x20; 'CAPSLOCK' = 0x14
    'RCTRL' = 0xA3; 'RALT' = 0xA5; 'LWIN' = 0x5B; 'RWIN' = 0x5C; 'APPS' = 0x5D
    'INSERT' = 0x2D; 'DELETE' = 0x2E; 'HOME' = 0x24; 'END' = 0x23
    'PGUP' = 0x21; 'PGDN' = 0x22; 'UP' = 0x26; 'DOWN' = 0x28
    'LEFT' = 0x25; 'RIGHT' = 0x27
}

function Get-Vk([string]$name) {
    $n = $name.Trim().ToUpper()
    if ($VkCodes.ContainsKey($n)) { return $VkCodes[$n] }
    throw "无法识别按键 '$name'。"
}

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-ScancodeMap {
    $v = (Get-ItemProperty $RegPath -Name 'Scancode Map' -ErrorAction SilentlyContinue).'Scancode Map'
    if ($null -eq $v) { return $null }
    return [byte[]]$v
}

function Write-ScancodeMap([byte[]]$map) {
    New-Item -Path $RegPath -Force | Out-Null
    Set-ItemProperty -Path $RegPath -Name 'Scancode Map' -Value $map -Type Binary
}

function Backup-ScancodeMap {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    $cur = Read-ScancodeMap
    $obj = @{
        timestamp = (Get-Date).ToString('o')
        existed   = ($null -ne $cur)
        data      = if ($null -ne $cur) { ($cur | ForEach-Object { $_.ToString('X2') }) -join ' ' } else { $null }
    }
    $obj | ConvertTo-Json | Set-Content -Path $BackupFile -Encoding UTF8
}

function Build-ScancodeMap([object[]]$entries) {
    # entries: @{ New = 0x0017; Old = 0x0017 }
    $count = $entries.Count + 1
    $bytes = New-Object System.Collections.Generic.List[byte]
    $bytes.AddRange([byte[]]@(0, 0, 0, 0, 0, 0, 0, 0))
    $bytes.AddRange([BitConverter]::GetBytes([int]$count))
    foreach ($e in $entries) {
        $bytes.Add([byte]([int]$e.New -band 0xFF))
        $bytes.Add([byte](([int]$e.New -shr 8) -band 0xFF))
        $bytes.Add([byte]([int]$e.Old -band 0xFF))
        $bytes.Add([byte](([int]$e.Old -shr 8) -band 0xFF))
    }
    $bytes.AddRange([byte[]]@(0, 0, 0, 0))
    return $bytes.ToArray()
}

# ---------------------------------------------------------------- detect

function Invoke-Detect {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class KRKeys {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);
    public static bool Down(int v) { return (GetAsyncKeyState(v) & 0x8000) != 0; }
}
'@ -ErrorAction SilentlyContinue

    Write-Host "采样 ${Seconds} 秒，请正常使用键盘……" -ForegroundColor Cyan
    $since = @{}
    $stuck = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        for ($v = 1; $v -le 254; $v++) {
            if ([KRKeys]::Down($v)) {
                if (-not $since.ContainsKey($v)) { $since[$v] = $sw.ElapsedMilliseconds }
                elseif (($sw.ElapsedMilliseconds - $since[$v]) -gt 1000) {
                    $stuck[$v] = ($sw.ElapsedMilliseconds - $since[$v])
                }
            }
            else { $since.Remove($v) | Out-Null }
        }
        Start-Sleep -Milliseconds 8
    }

    if ($stuck.Count -eq 0) {
        Write-Host "未检测到卡键（所有按键都能正常松开）。" -ForegroundColor Green
    }
    else {
        Write-Host "检测到以下按键持续按下：" -ForegroundColor Yellow
        foreach ($v in ($stuck.Keys | Sort-Object)) {
            Write-Host ("  {0,-12} 0x{1:X2}  持续约 {2} ms" -f (Get-KeyName $v), $v, $stuck[$v]) -ForegroundColor Red
        }
        Write-Host "`n建议：先反复按压该键 20-30 次；若仍复发，用 guard 吞掉连发，或用 disable/remap 处理。" -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------- guard

function Invoke-Guard {
    $names = if ($Key) { $Key.Split(',') | ForEach-Object { $_.Trim() } } else { @('I', 'LWIN') }
    $vks = @($names | ForEach-Object { Get-Vk $_ })
    $vkList = ($vks | ForEach-Object { "0x{0:X}" -f $_ }) -join ','

    if ($Install) {
        if (-not (Test-Admin)) { throw '安装开机自启需要管理员权限，请右键“以管理员身份运行”。' }
        $self = $PSCommandPath
        $arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" guard -Key {1}' -f $self, ($names -join ',')
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName
        Write-Host "已安装开机自启：$TaskName" -ForegroundColor Green
        return
    }

    $code = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class KRGuard
{
    delegate IntPtr Proc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    static extern IntPtr SetWindowsHookEx(int idHook, Proc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);

    [StructLayout(LayoutKind.Sequential)]
    public struct KBD { public uint vkCode; public uint scanCode; public uint flags; public uint time; public IntPtr dwExtraInfo; }

    const int REPEAT_GAP_MS = 500;
    const int BOUNCE_MS = 120;

    static Proc proc;
    static Stopwatch sw;
    static bool[] isDown = new bool[256];
    static long[] lastEvent = new long[256];
    static long[] lastAccepted = new long[256];
    static bool[] watched = new bool[256];
    static long swallowed = 0;
    static long passed = 0;

    public static void Run(int[] vks)
    {
        foreach (int v in vks) watched[v] = true;
        for (int i = 0; i < 256; i++) lastAccepted[i] = -1000000;
        sw = Stopwatch.StartNew();
        proc = Hook;
        IntPtr hook = SetWindowsHookEx(13, proc, GetModuleHandle(null), 0);
        Console.WriteLine("KeyboardRescue guard running. hook=" + hook + "  Ctrl+C to stop.");
        while (true) { Application.DoEvents(); System.Threading.Thread.Sleep(5); }
    }

    static IntPtr Hook(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            KBD k = (KBD)Marshal.PtrToStructure(lParam, typeof(KBD));
            uint msg = (uint)wParam;
            bool down = (msg == 0x100 || msg == 0x104);
            bool up = (msg == 0x101 || msg == 0x105);
            int vk = (int)k.vkCode;
            if (vk >= 0 && vk < 256 && watched[vk])
            {
                long now = sw.ElapsedMilliseconds;
                if (down)
                {
                    long gap = now - lastEvent[vk];
                    long sinceAccept = now - lastAccepted[vk];
                    if ((isDown[vk] && gap < REPEAT_GAP_MS) || sinceAccept < BOUNCE_MS)
                    {
                        swallowed++;
                        lastEvent[vk] = now;
                        if (swallowed % 50 == 1) Console.WriteLine("swallowed vk=0x" + vk.ToString("X2") + " total=" + swallowed);
                        return (IntPtr)1;
                    }
                    isDown[vk] = true;
                    lastEvent[vk] = now;
                    lastAccepted[vk] = now;
                    passed++;
                }
                else if (up) { isDown[vk] = false; }
            }
        }
        return CallNextHookEx(IntPtr.Zero, nCode, wParam, lParam);
    }
}
"@
    Add-Type -TypeDefinition $code -Language CSharp -ReferencedAssemblies 'System.Windows.Forms'
    Write-Host ("守护按键: " + ($names -join ', ')) -ForegroundColor Cyan
    [KRGuard]::Run([int[]]$vks)
}

# ---------------------------------------------------------------- 映射

function Invoke-Remap([bool]$Disable) {
    if (-not (Test-Admin)) { throw '修改键盘映射需要管理员权限，请右键“以管理员身份运行”。' }
    if (-not $Key) { throw '请用 -Key 指定有问题的按键，例如 -Key I' }
    $keyName = $Key.Trim().ToUpper()
    if (-not $Scancodes.ContainsKey($keyName)) { throw "无法识别按键 '$Key'。请参考 README 的键位表。" }
    $oldSc = [int]$Scancodes[$keyName]

    $newSc = 0x00
    if (-not $Disable) {
        if (-not $To) { throw '请用 -To 指定要映射到的备用键，例如 -To RCTRL' }
        $newSc = $Scancodes[$To.Trim().ToUpper()]
        if ($null -eq $newSc) { throw "无法识别备用键 $To。" }
    }

    Write-Host "即将修改扫描码映射：" -ForegroundColor Yellow
    if ($Disable) { Write-Host ("  禁用 {0} (0x{1:X})" -f $Key, $oldSc) }
    else { Write-Host ("  {0} (0x{1:X})  ->  {2} (0x{3:X})" -f $Key, $oldSc, $To, $newSc) }
    Write-Host "  （需要重启后生效）"

    if (-not $Apply) {
        Write-Host "`n这是预演。确认无误后加上 -Apply 真正写入。" -ForegroundColor Gray
        return
    }

    Backup-ScancodeMap
    $existing = Read-ScancodeMap
    $entries = @()
    if ($existing -and $existing.Length -ge 12) {
        $count = [BitConverter]::ToInt32($existing, 8)
        for ($i = 0; $i -lt $count - 1; $i++) {
            $off = 12 + $i * 4
            if ($off + 4 -gt $existing.Length) { break }
            $new = [BitConverter]::ToUInt16($existing, $off)
            $old = [BitConverter]::ToUInt16($existing, $off + 2)
            if ($old -ne 0) { $entries += @{ New = [int]$new; Old = [int]$old } }
        }
    }
    $entries = @($entries | Where-Object { $_.Old -ne $oldSc }) + @(@{ New = [int]$newSc; Old = [int]$oldSc })

    $map = Build-ScancodeMap $entries
    Write-ScancodeMap $map
    Write-Host ("已写入: " + (($map | ForEach-Object { $_.ToString('X2') }) -join ' ')) -ForegroundColor Green
    Write-Host "请重启电脑生效。还原请运行: .\keyboard-rescue.ps1 restore -Apply" -ForegroundColor Cyan
}

function Invoke-Restore {
    if (-not (Test-Admin)) { throw '还原需要管理员权限，请右键“以管理员身份运行”。' }
    if (-not (Test-Path $BackupFile)) {
        Write-Host "没有找到备份文件，将直接清除自定义映射。" -ForegroundColor Yellow
        $exists = $false
    }
    else {
        $b = Get-Content $BackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $exists = $b.existed
    }

    if (-not $Apply) {
        Write-Host "这是预演。将恢复为：$(if ($exists) { '备份中的映射' } else { '无自定义映射（默认状态）' })" -ForegroundColor Gray
        Write-Host "确认后加上 -Apply 执行。"
        return
    }

    if ($exists) {
        $bytes = [byte[]]($b.data.Split(' ') | ForEach-Object { [Convert]::ToByte($_, 16) })
        Write-ScancodeMap $bytes
        Write-Host "已恢复备份映射。" -ForegroundColor Green
    }
    else {
        Remove-ItemProperty -Path $RegPath -Name 'Scancode Map' -ErrorAction SilentlyContinue
        Write-Host "已清除自定义映射，键盘恢复默认。" -ForegroundColor Green
    }
    Write-Host "请重启电脑生效。" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- status

function Invoke-Status {
    Write-Host "== 当前扫描码映射 ==" -ForegroundColor Cyan
    $m = Read-ScancodeMap
    if ($null -eq $m) { Write-Host "  无（系统默认）" }
    else { Write-Host ("  " + (($m | ForEach-Object { $_.ToString('X2') }) -join ' ')) }

    Write-Host "`n== 守护任务 ==" -ForegroundColor Cyan
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($t) { Write-Host ("  {0}: {1}" -f $t.TaskName, $t.State) }
    else { Write-Host "  未安装开机自启" }

    Write-Host "`n== 备份 ==" -ForegroundColor Cyan
    if (Test-Path $BackupFile) { Write-Host ("  " + $BackupFile) } else { Write-Host "  无备份" }
}

# ---------------------------------------------------------------- 入口

switch ($Action) {
    'detect' { Invoke-Detect }
    'guard' {
        if ($Uninstall) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "已移除开机自启。" -ForegroundColor Green
        }
        else { Invoke-Guard }
    }
    'remap' { Invoke-Remap $false }
    'disable' { Invoke-Remap $true }
    'restore' { Invoke-Restore }
    'status' { Invoke-Status }
}
