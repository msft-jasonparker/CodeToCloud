Function New-DemoData {
    Param (
        $Path,
        $FolderPrefix = "demo_fldr_",
        $FolderCount = 2,
        $MaxFolderDepth = 3,
        [Switch]$IsRoot
    )
    BEGIN {
        Function _CreateDemoFiles {
            Param (
                $Path,
                $FilePrefix = "demo_file_",
                $FileCount = (Get-Random -Minimum 1 -Maximum 4)
            )
        
            Write-Output "Generating $FileCount files in $path"
            # loop to create files based on $fileCount
            For ($i = 0; $i -lt $FileCount; $i++) {
                # create uniquestring for files from 1st section of a guid
                $uniqueString = [guid]::NewGuid().Guid.Split("-")[0]
                # create new file
                $filetemp = New-Item -ItemType File -Path $Path -Name ($FilePrefix + $uniqueString + ".txt")
                # create random content size
                $size = Get-Random 1024
                $data = $null
                # loop to create data based on $size
                For ($x = 0; $x -lt $size; $x++){ $data = $data+[char][byte]((Get-Random 64)+32) }
                # add content to file
                Add-Content -LiteralPath $filetemp.FullName -Value $data
            }
        }
    }
    PROCESS {
        # check the path
        If (Test-Path $Path -ErrorAction SilentlyContinue) {
            # is this path the root folder of the demo data to create
            If ($IsRoot) {
                Write-Output "Creating folders and files in Root of $path"
                # capturing the root path to determine folder depth
                $rootPath = $path
                # call function to create files in the path
                _CreateDemoFiles -Path $Path
                # loop based on $foldercount to create folders and recall function to continue the folder creation
                For ( $fldr_count = 0; $fldr_count -lt $FolderCount; $fldr_count++ ) {
                    # folder name using a uniquestring suffix from 2nd section of a guid
                    $folderName = $FolderPrefix + [guid]::NewGuid().Guid.Split("-")[1]
                    # create the folder
                    $folder = New-Item -ItemType Directory -Path $Path -Name $folderName -ErrorAction SilentlyContinue
                    # if folder created - call function to created random number of folders in the new path
                    # uses $maxdepth to prevent infinite looping
                    If ($folder) { New-DemoData -Path $folder.FullName -FolderCount (Get-Random -Minimum 0 -Maximum 5) -MaxFolderDepth $MaxFolderDepth }
                }
            }
            Else {
                # checks for 0 in $foldercount and only creates demo files
                If ($folderCount -eq 0) {
                    Write-Output "No more folders to create in $path"
                    # call function to create files in the path
                    _CreateDemoFiles -Path $Path
                    Return
                }
                Else {
                    # call function to create files in the path
                    _CreateDemoFiles -Path $Path
                    # get folder depth
                    $folderDepth = $Path.Substring($rootPath.Length).Split("\").Count
                    Write-Output "[Depth: $folderDepth] Path: $path"
                    If ($folderDepth -lt $MaxFolderDepth) {
                        # loop based on $foldercount to create folders and recall function to continue the folder creation
                        For ( $fldr_count = 0; $fldr_count -lt $FolderCount; $fldr_count++ ) {
                            # folder name using a uniquestring suffix from 2nd section of a guid
                            $folderName = $FolderPrefix + [guid]::NewGuid().Guid.Split("-")[1]
                            # create the folder
                            $folder = New-Item -ItemType Directory -Path $Path -Name $folderName -ErrorAction SilentlyContinue
                            # if folder created - call function to created random number of folders in the new path
                            # uses $maxdepth to prevent infinite looping
                            If ($folder) { New-DemoData -Path $folder.FullName -FolderCount $FolderCount -MaxFolderDepth $MaxFolderDepth }
                        }
                    }
                    Else {
                        # exit if $maxfolderdepth is reached for the folder
                        Write-Output "Max Folder depth reached!"
                        Return
                    }
                }
            }
        }
    }
}