# Enables [NoDelete] Shield-Kin and turns off Horde, marth Follower Overhaul and Harbinger.
# Run only while Mod Organizer 2 is closed. Backups go next to the profile files.
$p = 'B:\Modlists\Authoria\profiles\Authoria - Requiem Reforged'
if (Get-Process ModOrganizer -ErrorAction SilentlyContinue) { throw 'Close Mod Organizer 2 first.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item "$p\modlist.txt" "$p\modlist.txt.shk-$stamp.bak"
Copy-Item "$p\plugins.txt" "$p\plugins.txt.shk-$stamp.bak"

$off = '[NoDelete] marth Follower Overhaul', '[NoDelete] Horde - A Light-Weight SKSE Follower Management System', '[NoDelete] Harbinger - AI Package Management Framework'
$mods = Get-Content "$p\modlist.txt" | Where-Object { $_ -notmatch '^[+-]\[NoDelete\] Shield-Kin$' -and $_ -notmatch '^[+-]houseCARL - Shield-Kin$' }
$mods = $mods | ForEach-Object { if ($off -contains $_.Substring(1)) { '-' + $_.Substring(1) } else { $_ } }
$head = $mods | Select-Object -First 1
$out = @($head, '+[NoDelete] Shield-Kin') + ($mods | Select-Object -Skip 1)
[IO.File]::WriteAllLines("$p\modlist.txt", [string[]]$out, (New-Object Text.UTF8Encoding $false))

$plugs = Get-Content "$p\plugins.txt" | Where-Object { $_ -notmatch '^\*?Shield-Kin\.esp$' }
$plugs = $plugs | ForEach-Object { if ($_ -match '^\*(MFO\.esp|Horde\.esp|APMF\.esl)$') { $_.Substring(1) } else { $_ } }
$plugs += '*Shield-Kin.esp'
[IO.File]::WriteAllLines("$p\plugins.txt", [string[]]$plugs, (New-Object Text.UTF8Encoding $false))
'Done. Backups: *.shk-' + $stamp + '.bak'
