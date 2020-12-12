Function New-DirectoryWebBrowsing {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [System.String]$Path,
        [Parameter(Mandatory=$false)]
        [System.String]$Website = "example.com",
        [Switch]$Recurse,
        [Switch]$IsRoot
    )
    BEGIN {
        Function _CreateDocumentIndex {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory=$true)]
                [Object[]]$InputObject,
                [Switch]$IsRoot
            )
            # clear any previous index reference
            $index = $null
           #If ($InputObject[0].RootPath.StartsWith(".")) { $InputObject[0].RootPath = (Resolve-Path $InputObject[0].RootPath).Path }
            # creates and index based on the parent path
            $parentPathIndex = $InputObject[0].PSParentPath.IndexOf($InputObject[0].RootPath.TrimStart("."))
            # creates output file path based on the parent path
            $outputPath = $InputObject[0].PSParentPath.SubString($parentPathIndex)
            $outputFile = ("{0}\index.html" -f $outputPath)
            # html header and breadcrump HTML string builders
            $htmltop = "<html><head><title>{0} - {1}</title></head><body><H1>{0} - {1}</H1><hr>`n<div style='width:1024px;overflow:auto'>`n<pre>`n"
            $htmlBreadCrumb = "<A HREF='{0}'>[To Parent Directory]</A><br><br>`n"
        
            Write-Verbose ("Creating index.html for {0}" -f $outputPath)
            # creates index variable based on if folder is root
            If ($IsRoot) { $index = $htmltop -f $InputObject[0].SiteFQDN,"/" }
            Else {
                # find the index value for the root path from parent path
                $i = $InputObject[0].PSParentPath.IndexOf($InputObject[0].RootPath)

                [System.Collections.Generic.List[Object]]$parentArray = @()
                # finds parent path based on index PLUS root path length
                $parentPath = $InputObject[0].PSParentPath.Substring($i + $InputObject[0].RootPath.Length)
                # splits the path by the separator, then loops to add each of the paths to an array
                $parentPath.Split("\") | Foreach-Object { $parentArray.Add($_) }
                # removes the last item of the array
                $parentArray.Remove($parentArray[-1]) | Out-Null
                # if the array exists, join the items using '/'
                If ($parentArray) { $parentHREF = $parentArray -Join "/" }
                Else { $parentHREF = "/" }
                # create the index variable
                $index = $htmltop -f $InputObject[0].SiteFQDN,$parentPath.Replace("\","/")
                $index += $htmlBreadCrumb -f $parentHREF
            }
        
            # create hash table based on folders
            $ObjectHash = $InputObject | Group-Object PSIsContainer -AsHashTable -AsString
        
            # loop through hash table
            Foreach ($Key in $ObjectHash.Keys) {
                Switch ($Key) {
                    "False" {
                        # loops through each file and generates html links to those files
                        Foreach ($Object in $ObjectHash[$Key]) {
                            Write-Verbose ("[FILE] Creating HTML Links: {0}" -f $Object.Name)
                            $fileHREF = $Object.FullName.Substring($Object.RootPath.Length).Replace("\","/")
                            #based on the character length of the file, the spaces in the strings need to be adjusted
                            If ($Object.Length.ToString().Length -ge 8) { $index += ("{0}		{1}	<A HREF='{2}'>{3}</A>`n" -f $Object.LastWriteTimeUtc,$Object.Length,$fileHREF,$Object.Name) }
                            ElseIf ($Object.Length.ToString().Length -ge 4) { $index += ("{0}		{1}		<A HREF='{2}'>{3}</A>`n" -f $Object.LastWriteTimeUtc,$Object.Length,$fileHREF,$Object.Name) }
                            Else { $index += ("{0}		{1}		<A HREF='{2}'>{3}</A>`n" -f $Object.LastWriteTimeUtc,$Object.Length,$fileHREF,$Object.Name) }
                        }
                    }
                    "True" {
                        # loops through each folder and generates html links to those folders
                        Foreach ($Object in $ObjectHash[$key]) {
                            Write-Verbose ("[FOLDER] Creating HTML Links: {0}" -f $Object.Name)
                            $folderHREF = $Object.FullName.Substring($Object.RootPath.Length).Replace("\","/")
                            $folderDepth = $folderHREF.TrimStart("/").Split("/").Count
                            If ($folderDepth -eq 1) { $index += ("{0}		&lt;dir&gt;		<A HREF='/{1}/'>{1}</A>`n" -f $Object.LastWriteTimeUtc,$Object.Name) }
                            ElseIf ($folderDepth -gt 1) { $index += ("{0}		&lt;dir&gt;		<A HREF='{1}'>{2}</A>`n" -f $Object.LastWriteTimeUtc,$folderHREF,$Object.Name) }
                        }
                    }
                }        
            }
        
            Write-Verbose ("Finished Processing Folders and Files in {0}" -f $outputPath)
            # writes html footer
            $index += "</div></pre>`n<hr></body></html>"
            # creates the index.html file in the directory
            $index | Out-File -FilePath $outputFile -Force
        }
    }
    PROCESS {
        # check to ensure path exists
        If (Test-Path -Path $Path -ErrorAction SilentlyContinue) {
            Write-Verbose ("Analyzing Path: {0}" -f $Path)
            # checks that the $path does not have trailing '\', trims the separator if found
            If ([System.IO.Path]::EndsInDirectorySeparator($Path)) { $Path = [System.IO.Path]::TrimEndingDirectorySeparator($Path) }
        }
        Else {
            # function exits if path not found
            Write-Warning ("The provided path, {0}, was not found" -f $Path)
            Return
        }
        
        # get folder items excluding common web files
        $FolderItems = Get-ChildItem -Path $Path -Exclude "index.html","web.config"
        # checks for folder items
        If ($FolderItems) {
            # check for root folder
            If ($IsRoot) {
                # check if using $PSDrive and sets global variable for root path - needed for html links and pathing
                If ($PSDrive) { $Global:RootPath = $PSDrive.Root }
                Else { $Global:RootPath = $Path }

                # resolves the root path if specified with .\ notation
                If ($Global:RootPath.StartsWith(".")) {$Global:RootPath = (Resolve-Path $Global:RootPath).Path }
                Write-Verbose ("Processing Root Folder Items: {0}" -f $RootPath)
                # adds root path and site fqdn to folder item array
                $FolderItems | Add-Member -MemberType NoteProperty -Name RootPath -Value $Global:RootPath
                $FolderItems | Add-Member -MemberType NoteProperty -Name SiteFQDN -Value $Website
                # calls function to create html files in the path
                _CreateDocumentIndex -InputObject $FolderItems -IsRoot
            }
            Else {
                Write-Verbose ("Processing Folder Items: {0}" -f $RootPath)
                # adds root path and site fqdn to folder item array
                $FolderItems | Add-Member -MemberType NoteProperty -Name RootPath -Value $Global:RootPath
                $FolderItems | Add-Member -MemberType NoteProperty -Name SiteFQDN -Value $Website
                # calls function to create html files in the path
                _CreateDocumentIndex -InputObject $FolderItems
            }
            
            # checks to recurse the child folders
            If ($Recurse) {
                # loops through each child folder
                Foreach ($Folder in $FolderItems.Where{$_.PSIsContainer -eq $true}) {
                    Write-Verbose ("Processing Child Folder: {0}" -f $Folder.fullname)
                    # if the folder name does not equal the incoming path, call the function again for the new folder with recursion
                    If ($Folder.FullName -ne $Path) { New-DirectoryWebBrowsing -Path $Folder.FullName -Website $Website -Recurse }
                }
            }
        }
        Else {
            # function ends if no folder items found
            Write-Warning ("No files found in path: {0}" -f $path)
            Return
        }
    }
}