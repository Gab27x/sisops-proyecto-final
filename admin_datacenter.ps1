# ============================================
# Herramienta de Administracion Data Center
# PowerShell Version
# ============================================

function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  HERRAMIENTA DE ADMINISTRACION DATA CENTER" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Usuarios y ultimo ingreso"
    Write-Host "2. Filesystems y espacio disponible"
    Write-Host "3. Top 10 archivos mas grandes"
    Write-Host "4. Memoria y Swap"
    Write-Host "5. Backup de directorio a USB"
    Write-Host "6. Salir"
    Write-Host ""
}

function Get-UserLogins {
    Write-Host "`n========== USUARIOS Y ULTIMO INGRESO ==========" -ForegroundColor Green
    
    try {
        $users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }
        
        foreach ($user in $users) {
            $username = $user.Name
            $lastLogin = "No disponible"
            
            # Metodo 1: Intentar desde Net User
            try {
                $netUserInfo = net user $username 2>$null
                $lastLogonLine = $netUserInfo | Select-String "Last logon"
                if ($lastLogonLine) {
                    $lastLogin = ($lastLogonLine -split '\s{2,}')[1]
                }
            } catch {}
            
            # Metodo 2: Intentar desde WMI
            if ($lastLogin -eq "No disponible" -or $lastLogin -eq "Never") {
                try {
                    $wmiUser = Get-WmiObject -Class Win32_NetworkLoginProfile -Filter "Name='$env:COMPUTERNAME\\$username'" -ErrorAction SilentlyContinue
                    if ($wmiUser -and $wmiUser.LastLogon) {
                        $lastLogin = [DateTime]::ParseExact($wmiUser.LastLogon.Split('.')[0], 'yyyyMMddHHmmss', $null)
                    }
                } catch {}
            }
            
            # Metodo 3: Event Log (como respaldo)
            if ($lastLogin -eq "No disponible" -or $lastLogin -eq "Never") {
                try {
                    $lastLoginEvent = Get-WinEvent -FilterHashtable @{
                        LogName = 'Security'
                        Id = 4624
                    } -MaxEvents 2000 -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Properties[5].Value -eq $username } | 
                    Select-Object -First 1
                    
                    if ($lastLoginEvent) {
                        $lastLogin = $lastLoginEvent.TimeCreated
                    }
                } catch {}
            }
            
            # Metodo 4: Propiedad LastLogon del usuario
            if (($lastLogin -eq "No disponible" -or $lastLogin -eq "Never") -and $user.LastLogon) {
                $lastLogin = $user.LastLogon
            }
            
            Write-Host "Usuario: $username" -ForegroundColor Yellow
            Write-Host "  Ultimo ingreso: $lastLogin"
            Write-Host ""
        }
    } catch {
        Write-Host "Error al obtener informacion de usuarios: $_" -ForegroundColor Red
    }
    
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
}

function Get-FileSystems {
    Write-Host "`n========== FILESYSTEMS Y DISCOS ==========" -ForegroundColor Green
    
    try {
        $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
        
        foreach ($disk in $disks) {
            $totalSize = $disk.Used + $disk.Free
            $freeSpace = $disk.Free
            $totalGB = [math]::Round($totalSize/1GB, 2)
            $freeGB = [math]::Round($freeSpace/1GB, 2)
            
            Write-Host "Disco: $($disk.Name):\" -ForegroundColor Yellow
            Write-Host "  Tamano total: $totalSize bytes ($totalGB GB)"
            Write-Host "  Espacio libre: $freeSpace bytes ($freeGB GB)"
            Write-Host ""
        }
    } catch {
        Write-Host "Error al obtener informacion de discos: $_" -ForegroundColor Red
    }
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
}

function Get-LargestFiles {
    Write-Host "`n========== TOP 10 ARCHIVOS MAS GRANDES ==========" -ForegroundColor Green
    
    $drive = Read-Host "`nIngrese la letra del disco a analizar (ej: C)"
    $path = "$drive" + ":\"
    
    if (-not (Test-Path $path)) {
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
    }
    
    Write-Host "`nBuscando archivos mas grandes en $path..." -ForegroundColor Yellow
    Write-Host "Esto puede tomar varios minutos...`n"
    
    try {
        $largestFiles = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object Length -Descending |
            Select-Object -First 10
        
        $counter = 1
        foreach ($file in $largestFiles) {
            $sizeMB = [math]::Round($file.Length/1MB, 2)
            Write-Host "$counter. Archivo: $($file.FullName)" -ForegroundColor Yellow
            Write-Host "   Tamano: $($file.Length) bytes ($sizeMB MB)"
            Write-Host ""
            $counter++
        }
    } catch {
        Write-Host "Error al buscar archivos: $_" -ForegroundColor Red
    }
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
}

function Get-MemoryInfo {
    Write-Host "`n========== MEMORIA Y SWAP ==========" -ForegroundColor Green
    
    try {
        # Memoria RAM
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMemory = $os.TotalVisibleMemorySize * 1024
        $freeMemory = $os.FreePhysicalMemory * 1024
        $usedMemory = $totalMemory - $freeMemory
        $memoryPercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
        
        $totalMemoryGB = [math]::Round($totalMemory/1GB, 2)
        $freeMemoryGB = [math]::Round($freeMemory/1GB, 2)
        $usedMemoryGB = [math]::Round($usedMemory/1GB, 2)
        
        Write-Host "MEMORIA RAM:" -ForegroundColor Yellow
        Write-Host "  Total: $totalMemory bytes ($totalMemoryGB GB)"
        Write-Host "  Libre: $freeMemory bytes ($freeMemoryGB GB)"
        Write-Host "  En uso: $usedMemory bytes ($usedMemoryGB GB - $memoryPercent%)"
        Write-Host ""
        
        # Swap / Page File
        $pageFile = Get-CimInstance Win32_PageFileUsage
        if ($pageFile) {
            $totalSwap = $pageFile.AllocatedBaseSize * 1024 * 1024
            $usedSwap = $pageFile.CurrentUsage * 1024 * 1024
            $swapPercent = [math]::Round(($usedSwap / $totalSwap) * 100, 2)
            
            $totalSwapGB = [math]::Round($totalSwap/1GB, 2)
            $usedSwapGB = [math]::Round($usedSwap/1GB, 2)
            
            Write-Host "SWAP (Page File):" -ForegroundColor Yellow
            Write-Host "  Total: $totalSwap bytes ($totalSwapGB GB)"
            Write-Host "  En uso: $usedSwap bytes ($usedSwapGB GB - $swapPercent%)"
        } else {
            Write-Host "No se detecto archivo de paginacion (Swap)." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error al obtener informacion de memoria: $_" -ForegroundColor Red
    }
    
    Write-Host "`nPresione Enter para continuar..."
    Read-Host
}


function Start-Backup {
    Write-Host "`n========== BACKUP A USB ==========" -ForegroundColor Green
    
    $sourceDir = Read-Host "`nIngrese la ruta completa del directorio a respaldar"
    
    if (-not (Test-Path $sourceDir)) {
        Write-Host "El directorio especificado no existe." -ForegroundColor Red
        Write-Host "`nPresione Enter para continuar..."
        Read-Host
        return
    }
    
    # Mostrar unidades USB disponibles
    Write-Host "`nUnidades removibles disponibles:" -ForegroundColor Yellow
    $removableDrives = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $volume = Get-Volume -DriveLetter $_.Name -ErrorAction SilentlyContinue
        if ($volume -and $volume.DriveType -eq 'Removable') {
            $_
        }
    }
    
    if (-not $removableDrives -or $removableDrives.Count -eq 0) {
        Write-Host "No se detectaron unidades USB." -ForegroundColor Red
        Write-Host "`nPresione Enter para continuar..."
        Read-Host
        return
    }
    
    foreach ($drive in $removableDrives) {
        Write-Host "  - $($drive.Name):\"
    }
    
    $usbDrive = Read-Host "`nIngrese la letra de la unidad USB (ej: E)"
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $destDir = "$usbDrive" + ":\Backup_$timestamp"
    
    try {
        Write-Host "`nCreando backup en $destDir..." -ForegroundColor Yellow
        
        # Crear directorio de destino
        New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
        
        # Copiar archivos (lanza excepción si algo falla)
        Copy-Item -Path "$sourceDir\*" -Destination $destDir -Recurse -Force -ErrorAction Stop
        
        # Crear catálogo
        $catalogPath = Join-Path $destDir "catalogo.txt"
        $files = Get-ChildItem -Path $sourceDir -Recurse -File -ErrorAction Stop
        
        $catalog = @(
            "CATALOGO DE BACKUP",
            "Fecha de backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Directorio origen: $sourceDir",
            ("=" * 80),
            ""
        )
        
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($sourceDir.Length)
            $catalog += "Archivo: $relativePath"
            $catalog += "  Última modificación: $($file.LastWriteTime)"
            $catalog += "  Tamaño: $($file.Length) bytes"
            $catalog += ""
        }
        
        $catalog | Out-File -FilePath $catalogPath -Encoding UTF8 -ErrorAction Stop
        
        Write-Host "`n¡Backup completado exitosamente!" -ForegroundColor Green
        Write-Host "Ubicación: $destDir"
        Write-Host "Catálogo generado: $catalogPath"
        
    } catch {
        Write-Host "`nError al realizar el backup:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host "`nPresione Enter para continuar..."
    Read-Host | Out-Null
}


# ============================================
# PROGRAMA PRINCIPAL
# ============================================

do {
    Show-Menu
    $option = Read-Host "Seleccione una opcion (1-6)"
    
    switch ($option) {
        '1' { Get-UserLogins }
        '2' { Get-FileSystems }
        '3' { Get-LargestFiles }
        '4' { Get-MemoryInfo }
        '5' { Start-Backup }
        '6' { 
            Write-Host "`nSaliendo del programa..." -ForegroundColor Cyan
            Start-Sleep -Seconds 1
            exit
        }
        default { 
            Write-Host "`nOpcion invalida. Presione Enter para continuar..." -ForegroundColor Red
            Read-Host
        }
    }
} while ($true)