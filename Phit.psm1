. $PsScriptRoot\Helpers.ps1

function Get-PhitHelp {
    $helps = @()
    dir "$PsScriptRoot\Commands\*.ps1" | foreach {
        $helps += @{
            "Name" = [IO.Path]::GetFileNameWithoutExtension($_.Name);
            "Synopsis" = (Get-Help $_.FullName).Synopsis
        }
    }

    $maxLen = $helps | foreach { $_.Name.Length } | sort -desc | select -first 1
    $helps | foreach {
        $str = "    ";
        $str += $_.Name.PadRight($maxLen + 3);
        $str += $_.Synopsis
        $str
    }
}

function Get-DefaultPullRequestBranch {
    $branch = Get-PSGitConfig "pr.defaultBranch"
    if(!$branch)
    {
        "master"
    } else {
        $branch
    }
}
Export-ModuleMember -Function Get-DefaultPullRequestBranch

function Set-DefaultPullRequestBranch {
    param([Parameter(Mandatory=$true, Position = 0)][string]$Branch)
    $branch = Set-PSGitConfig "pr.defaultBranch" $Branch
}
Export-ModuleMember -Function Set-DefaultPullRequestBranch

function Get-GitCurrentBranch {
    git symbolic-ref --short HEAD
}
Export-ModuleMember -Function Get-GitCurrentBranch

function Get-GitRemoteUrl {
    param(
        [Parameter(Mandatory=$true, Position = 0)][string]$RemoteName = "origin")
    
    git remote -v | where { $_ -match "^origin\s+(?<url>.*)\s+\(push\)$" } | foreach { $matches["url"] }
}
Export-ModuleMember -Function Get-GitRemoteUrl

function Invoke-Phit {
    if($args.Length -eq 0) {
        $args = @("help")
    }

    $cmd = $args[0]
    if($cmd -eq "help") {
        $help = $true
        $cmd = $args[1]
        $cmdArgs = $args[2..$args.Length]
    } else {
        $cmdArgs = $args[1..$args.Length]
    }

    $commandPath = Join-Path $PsScriptRoot "Commands\$cmd.ps1"
    $filterPath = Join-Path $PsScriptRoot "Filters\$cmd.ps1"
    if(Test-Path $commandPath) {
        Write-Debug "Invoking $commandPath $cmdArgs"
        if($help) {
            $content = [IO.File]::ReadAllText((Convert-Path $commandPath))
            Set-Content "function:\phit $cmd" -Value $content
            man "phit $cmd" @cmdArgs
            del "function:\phit $cmd"
        } else {
            & $commandPath @cmdArgs
        }
    } else {
        if(Test-Path $filterPath) {
            $parsedArgs = $cmdArgs | Parse-Arguments;
            & $filterPath $parsedArgs;
            if($parsedArgs.Cancel) {
                return;
            }
            $cmdArgs = $parsedArgs.Raw;
            Write-Host -ForegroundColor Magenta "phit> " -NoNewLine
            Write-Host "git $cmd $cmdArgs"
        }

        if($help) {
            Write-Host -ForegroundColor Green "Git Commands:"
            Write-Host
            git $cmd @cmdArgs
            Write-Host
            Write-Host -ForegroundColor Green "Phit Commands:"
            Write-Host
            Get-PhitHelp
        } else {
            & git $cmd @cmdArgs
        }
    }
}
Set-Alias -Name phit -Value Invoke-Phit
Export-ModuleMember -Function Invoke-Phit -Alias phit

$regex = [regex]"(?s).*available git commands in '.*'(?<builtin>.*)git commands available from elsewhere on your \`$PATH(?<external>.*)'git help -a'.*";
function Get-PhitCommands {
    $list = ([String]::Join([Environment]::NewLine, (git help -a)));
    $m = $regex.Match($list);
    if($m.Success) {
        $builtin = @(
            $m.Groups["builtin"].Value.Split(@(" "), "RemoveEmptyEntries") | 
                where { ![String]::IsNullOrWhitespace($_) } | 
                foreach { $_.Trim() })
        $external = @(
            $m.Groups["external"].Value.Split(@(" "), "RemoveEmptyEntries") | 
                where { ![String]::IsNullOrWhitespace($_) } | 
                foreach { $_.Trim() })
        $phit = @(
            dir "$PsScriptRoot\Commands\*.ps1" | 
                foreach { [IO.Path]::GetFileNameWithoutExtension($_.Name) })
        $builtin + $external + $phit
    }
}
Export-ModuleMember -Function Get-PhitCommands

$PhitRoot = $PsScriptRoot
Export-ModuleMember -Variable PhitRoot