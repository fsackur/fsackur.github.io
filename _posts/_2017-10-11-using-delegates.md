

```powershell
function Invoke-ApiCall {
    if ([bool](Get-Random -Minimum 0 -Maximum 2)) {
        return [psobject]@{
            prop1 = 'data1'
            prop2 = 'data2'
        }

    } else {
        throw "401"

    }
}


function Get-AuthToken {
    #Dummy, for demonstration purposes
    #This would probably prompt the user
    Write-Verbose "Prompting user for creds"
}

function Get-Objects {
    param(
        $AuthToken
    )

    begin {
        $OutputArray = @()
    }

    process {
        $Retry = $false
        $MaxRetries = 3
        do {
            try {
                $Objects = Invoke-ApiCall
                $Retry = $false
            } catch {
                Write-Warning $_.Exception.Message
                if ($_ -match '401') {$Retryable = $true}
                if ($Retryable) {
                    $MaxRetries -= 1
                    if ($MaxRetries -gt 0) {
                        $Retry = $true
                    }
                }
                if ($_ -match '401') {
                    $AuthToken = Get-AuthToken -Renew
                }
            }
        } while ($Retry)
    }

    end {
        return $Objects

    }
}

Get-Objects
```



```powershell




```

