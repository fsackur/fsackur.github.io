$AppPath = $PSScriptRoot | Split-Path
Push-Location $AppPath

try
{
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)
    {
        if (-not (Get-Command ruby -ErrorAction Ignore))
        {
            winget install RubyInstallerTeam.Ruby.3.2
        }

        if (-not (Get-Command bundle -ErrorAction Ignore))
        {
            gem install bundler
        }

        ridk install 1,3
    }
    else
    {
        if (-not (Get-Command ruby -ErrorAction Ignore))
        {
            $PackageMgr = Get-Command dnf -ErrorAction Ignore
            if (-not $PackageMgr)
            {
                $PackageMgr = Get-Command apt -ErrorAction Ignore
            }
            sudo $PackageMgr install ruby-devel
        }

        if (-not (Get-Command bundle -ErrorAction Ignore))
        {
            gem install bundler
        }

        bundle config set --local path ./gem
    }

    bundle install

}
finally
{
    Pop-Location
}
