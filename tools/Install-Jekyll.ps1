if ($IsLinux)
{
    # TODO
}
else
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

    bundle install
}
