# --- Configuration ---
# Path to your sweets.json file
$jsonFilePath = ".\sweets.json" # Assumes sweets.json is in the same directory as the script

# Path to the directory where your "WhatsApp Image..." files ARE and where they will be RENAMED.
$imagesDir = ".\img\New_img" # <<< IMAGES MUST ALREADY BE IN THIS FOLDER

# Set to $false to actually rename files. $true for a dry run.
$dryRun = $true # <<< CHANGE TO $false TO EXECUTE
# --- End Configuration ---

function Get-ImageFilesFromDirectory {
    param (
        [string]$DirectoryPath
    )
    $allowedExtensions = @(".jpg", ".jpeg", ".png", ".gif", ".webp")
    if (-not (Test-Path $DirectoryPath -PathType Container)) {
        Write-Error "Error: Image directory not found: $DirectoryPath"
        return @()
    }
    # Prioritize WhatsApp named files if many other types are present, or adjust filter
    return Get-ChildItem -Path $DirectoryPath -File | Where-Object { $_.Name -like "WhatsApp Image*" -and $allowedExtensions -contains $_.Extension.ToLower() } | Sort-Object Name | Select-Object -ExpandProperty Name
    # If you want to rename *any* image sequentially, use:
    # return Get-ChildItem -Path $DirectoryPath -File | Where-Object { $allowedExtensions -contains $_.Extension.ToLower() } | Sort-Object Name | Select-Object -ExpandProperty Name
}

function Rename-SweetImagesInPlace {
    if (-not (Test-Path $imagesDir -PathType Container)) {
        Write-Error "ERROR: The specified image directory '$imagesDir' does not exist. Please create it and place your WhatsApp images there."
        return
    }

    $absoluteJsonPath = Resolve-Path -Path $jsonFilePath
    $absoluteImagesDir = Resolve-Path -Path $imagesDir

    Write-Host "JSON file: $absoluteJsonPath"
    Write-Host "Image directory (source and destination): $absoluteImagesDir"

    if (-not (Test-Path $absoluteJsonPath -PathType Leaf)) {
        Write-Error "Error: JSON file not found at $absoluteJsonPath"
        return
    }

    try {
        $sweetsData = Get-Content $absoluteJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Error: Could not decode JSON from $absoluteJsonPath. Check for syntax errors. $($_.Exception.Message)"
        return
    }

    $currentImageFiles = Get-ImageFilesFromDirectory -DirectoryPath $absoluteImagesDir
    if ($currentImageFiles.Count -eq 0) {
        Write-Warning "No 'WhatsApp Image...' like files found in $absoluteImagesDir to rename. Exiting."
        return
    }

    Write-Host "Found $($currentImageFiles.Count) source images in '$absoluteImagesDir' to potentially rename."
    Write-Host "Processing $($sweetsData.Count) sweets from '$absoluteJsonPath'."
    if ($dryRun) {
        Write-Host "`n--- DRY RUN --- (No files will be renamed) ---`n" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n--- ACTUAL RENAME --- (Files WILL be renamed) ---`n" -ForegroundColor Green
    }

    $currentImageIndex = 0
    $processedNewFilenames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase) # Track new filenames to avoid conflicts

    foreach ($sweetItem in $sweetsData) {
        $sweetName = if ($null -ne $sweetItem.name -and $sweetItem.name -ne "") { $sweetItem.name } else { "UnknownSweet" }
        $targetRelativePathsFromJson = New-Object System.Collections.Generic.List[string]

        if ($null -ne $sweetItem.img -and $sweetItem.img -ne "") {
            $targetRelativePathsFromJson.Add($sweetItem.img)
        }
        if ($null -ne $sweetItem.images) {
            foreach ($imgPath_json in $sweetItem.images) {
                if ($imgPath_json -and (-not $targetRelativePathsFromJson.Contains($imgPath_json))) {
                    $targetRelativePathsFromJson.Add($imgPath_json)
                }
            }
        }
        
        Write-Host "`nProcessing sweet: '$sweetName'"
        foreach ($targetRelativePathFromJson in $targetRelativePathsFromJson) {
            if ($currentImageIndex -ge $currentImageFiles.Count) {
                Write-Warning "Warning: Ran out of source 'WhatsApp Image...' files. Some target paths in JSON may not get a renamed image."
                if ($dryRun) { Write-Host "--- END OF DRY RUN ---" -ForegroundColor Yellow } else { Write-Host "--- END OF RENAME ---" -ForegroundColor Green }
                return
            }

            $oldFilename = $currentImageFiles[$currentImageIndex]
            $oldFullPath = Join-Path -Path $absoluteImagesDir -ChildPath $oldFilename
            
            # The target path from JSON is like "img/New img/new_filename.jpg"
            # We only want the "new_filename.jpg" part for renaming within $absoluteImagesDir
            $newFilenameOnly = Split-Path $targetRelativePathFromJson -Leaf
            $newFullPath = Join-Path -Path $absoluteImagesDir -ChildPath $newFilenameOnly
            
            # Check if the new filename is already processed or would result in conflict
            if ($processedNewFilenames.Contains($newFilenameOnly)) {
                Write-Warning "  Skipping target '$newFilenameOnly': This filename has already been used for another rename in this run. Check JSON for duplicate target filenames."
                # We should still advance the source image index, as this target is problematic
                $currentImageIndex++
                continue
            }
            # Check if the new filename is the same as an *existing source file* we haven't processed yet
            # This is to prevent renaming "WhatsApp Image A" to "WhatsApp Image B.jpg" if "WhatsApp Image B.jpg" is also a source file.
            if ($oldFilename.ToLower() -ne $newFilenameOnly.ToLower() -and ($currentImageFiles | Where-Object {$_.ToLower() -eq $newFilenameOnly.ToLower()})) {
                 Write-Warning "  Skipping target '$newFilenameOnly': This filename conflicts with another unprocessed source image name. Resolve naming in source folder or JSON."
                 $currentImageIndex++
                 continue
            }


            Write-Host "  Attempting to rename: '$oldFilename' ==> '$newFilenameOnly' (within $absoluteImagesDir)"

            if (-not $dryRun) {
                try {
                    if (-not (Test-Path $oldFullPath -PathType Leaf)) {
                        Write-Warning "    Error: Source file '$oldFullPath' does not exist. Skipping."
                        $currentImageIndex++ 
                        continue
                    }

                    # If target filename is different from old, and target doesn't already exist
                    if ($oldFilename.ToLower() -ne $newFilenameOnly.ToLower()) {
                        if (Test-Path $newFullPath) {
                            Write-Warning "    Warning: Target file '$newFullPath' already exists. Skipping rename for '$oldFilename'."
                        } else {
                            Rename-Item -Path $oldFullPath -NewName $newFilenameOnly
                            Write-Host "    SUCCESS: Renamed '$oldFilename' to '$newFilenameOnly' in '$absoluteImagesDir'" -ForegroundColor Green
                            [void]$processedNewFilenames.Add($newFilenameOnly)
                        }
                    } else {
                        Write-Host "    Info: Old and new filenames are the same ('$oldFilename'). No rename needed." -ForegroundColor DarkGray
                        [void]$processedNewFilenames.Add($newFilenameOnly) # Still mark as processed
                    }
                }
                catch {
                    Write-Error "    Error renaming '$oldFullPath' to '$newFilenameOnly': $($_.Exception.Message)"
                }
            } else { # Dry run: just mark as processed for tracking
                 [void]$processedNewFilenames.Add($newFilenameOnly)
            }
            $currentImageIndex++
        }
    }

    if ($currentImageIndex -lt $currentImageFiles.Count) {
        Write-Warning "`nWarning: $($currentImageFiles.Count - $currentImageIndex) source 'WhatsApp Image...' files were left over in '$absoluteImagesDir'."
    }

    if ($dryRun) {
        Write-Host "`n--- END OF DRY RUN ---" -ForegroundColor Yellow
        Write-Host "Review the output. If correct, change `$dryRun to `$false` and re-run." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n--- END OF RENAME PROCESS ---" -ForegroundColor Green
    }
}

# Run the main function
Rename-SweetImagesInPlace