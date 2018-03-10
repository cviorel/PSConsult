function Add-ContentFilterPolicyDetail {
    <#
    .SYNOPSIS
        Adds Detail to Content Filter Policy.

    .DESCRIPTION
        Adds Detail to Content Filter Policy.

    .PARAMETER ContentFilterPolicy
        Name of the Content Filter Policy to use.

    .PARAMETER AllowedSenderDomains
        The AllowedSenderDomains parameter specifies trusted domains that aren't processed by the spam filter. 
        Messages from senders in these domains are stamped with SFV:SKA in the X-Forefront-Antispam-Report header and receive a spam confidence level (SCL) of -1,
        so the messages are delivered to the recipient's inbox. Valid values are one or more SMTP domains.
    
    .PARAMETER AllowedSenders
        The AllowedSenders parameter specifies a list of trusted senders that aren't processed by the spam filter.
        Messages from these senders are stamped with SFV:SKA in the X-Forefront-Antispam-Report header and receive an SCL of -1,
        so the messages are delivered to the recipient's inbox. Valid values are one or more SMTP email addresses.

    .PARAMETER BlockedSenderDomains
        The BlockedSenderDomains parameter specifies domains that are always marked as spam sources.
        Messages from senders in these domains are stamped with SFV:SKB in the X-Forefront-Antispam-Report header and receive an SCL of 9 (high confidence spam).
        Valid values are one or more SMTP domains.

    .PARAMETER BlockedSenders
        The BlockedSenders parameter specifies senders that are always marked as spam sources.
        Messages from these senders are stamped with SFV:SKB in the X-Forefront-Antispam-Report header and receive an SCL of 9 (high confidence spam).
        Valid values are one or more SMTP email addresses.

    .PARAMETER OutputPath
        Where to write the report files to.
        By default it will write to the current path.

    .EXAMPLE
        Import-Csv .\PolicyDetail.csv | Add-ContentFilterPolicyDetail -ContentFilterPolicy "Spam Filter Policy for contoso.com recipients"

        Example of Policy Detail.csv

        AllowedSenderDomains, SubjectBodyWords, ExceptSubjectBodyWords, SenderIPs 
        fred@contoso.com, moon, wind, 142.23.221.21
        jane@fabrikam.com, sun fire, rain, 142.23.220.1-142.23.220.254
        potato.com, ocean, snow, 72.14.52.0/24
    .EXAMPLE
        Import-Csv .\PolicyDetail.csv | Add-ContentFilterPolicyDetail -ContentFilterPolicy "Bypass Spam Filtering for New York Partners" -Action01 BypassSpamFiltering

#>
    [CmdletBinding()]
    param (
		
        [Parameter(Mandatory = $true)]
        [String]
        $ContentFilterPolicy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('AllowedDomains')]
        [Alias('AllowedDomain')]
        [string]
        $AllowedSenderDomains,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('AllowedSender')]
        [string[]]
        $AllowedSenders,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('BlockedSenderDomain')]
        [Alias('BlockedDomains')]
        [Alias('BlockedDomain')]
        [string[]]
        $BlockedSenderDomains,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('BlockedSender')]
        [string[]]
        $BlockedSenders,

        [string]
        $OutputPath = "."
    )
    begin {
        $Params = @{}
        $listAllowedSenderDomains = New-Object System.Collections.Generic.HashSet[String]
        $listAllowedSenders = New-Object System.Collections.Generic.HashSet[String]
        $listBlockedSenderDomains = New-Object System.Collections.Generic.HashSet[String]
        $listBlockedSenders = New-Object System.Collections.Generic.HashSet[String]

        $headerstring = ("ContentFilterPolicy" + "," + "Detail")
        $errheaderstring = ("ContentFilterPolicy" + "," + "Detail" + "," + "Error")
		
        $successPath = Join-Path $OutputPath "Success.csv"
        $failedPath = Join-Path $OutputPath "Failed.csv"
        Out-File -FilePath $successPath -InputObject $headerstring -Encoding UTF8 -append
        Out-File -FilePath $failedPath -InputObject $errheaderstring -Encoding UTF8 -append
		
    }
    process {
        if ($AllowedSenderDomains) {
            [void]$listAllowedSenderDomains.add($AllowedSenderDomains)
        }
        if ($AllowedSenders) {
            [void]$listAllowedSenders.add($AllowedSenders)
        }
        if ($BlockedSenderDomains) {
            [void]$listBlockedSenderDomains.add($BlockedSenderDomains)
        }
        if ($BlockedSenders) {
            [void]$listBlockedSenders.add($BlockedSenders)
        }
    }
    end {
        if ($listAllowedSenderDomains.count -gt "0") {
            if ((Get-HostedContentFilterPolicy $ContentFilterPolicy -ErrorAction SilentlyContinue).AllowedSenderDomains) {
                (Get-HostedContentFilterPolicy $ContentFilterPolicy).AllowedSenderDomains | ForEach-Object {[void]$listAllowedSenderDomains.Add($_)}
            }
            $Params.Add("AllowedSenderDomains", $listAllowedSenderDomains)
        }
        if ($listAllowedSenders.count -gt "0") {
            if ((Get-HostedContentFilterPolicy $ContentFilterPolicy -ErrorAction SilentlyContinue).AllowedSenders) {
                (Get-HostedContentFilterPolicy $ContentFilterPolicy).AllowedSenders | ForEach-Object {[void]$listAllowedSenders.Add($_)}
            }
            $Params.Add("AllowedSenders", $listAllowedSenders)
        }
        if ($listBlockedSenderDomains.count -gt "0") {
            if ((Get-HostedContentFilterPolicy $ContentFilterPolicy -ErrorAction SilentlyContinue).BlockedSenderDomains) {
                (Get-HostedContentFilterPolicy $ContentFilterPolicy).BlockedSenderDomains | ForEach-Object {[void]$listBlockedSenderDomains.Add($_)}
            }
            $Params.Add("BlockedSenderDomains", $listBlockedSenderDomains)
        }
        if ($listBlockedSenders.count -gt "0") {
            if ((Get-HostedContentFilterPolicy $ContentFilterPolicy -ErrorAction SilentlyContinue).BlockedSenders) {
                (Get-HostedContentFilterPolicy $ContentFilterPolicy).BlockedSenders | ForEach-Object {[void]$listBlockedSenders.Add($_)}
            }
            $Params.Add("BlockedSenders", $listBlockedSenders)
        }
        if ($Action01 -eq "DeleteMessage") {
            $Params.Add("DeleteMessage", $true)
        }
        if ($Action01 -eq "BypassSpamFiltering") {
            $Params.Add("SetSCL", "-1")
        }
        if (!(Get-HostedContentFilterPolicy -Identity $ContentFilterPolicy -ErrorAction SilentlyContinue)) {
            Try {
                New-HostedContentFilterPolicy -Name $ContentFilterPolicy @Params -ErrorAction Stop
                Write-Verbose "Content Filter Policy `"$ContentFilterPolicy`" has been created."
                Write-Verbose "Parameters: `t $($Params.values | % { $_ -join " "})"
            }
            Catch {
                $_
                Write-Verbose "Unable to Create Content Filter Policy"
                Throw
            }
        }
        else { 
            Write-Verbose "Content Filter Policy `"$ContentFilterPolicy`" already exists."
            try {
                Set-HostedContentFilterPolicy -Identity $ContentFilterPolicy @Params -ErrorAction Stop
                Write-Verbose "Parameters: `t $($Params.values | % { $_ -join " "})" 
                $ContentFilterPolicy + "," + ($Params.values | % { $_ -join " "}) | Out-file $successPath -Encoding UTF8 -append
            }
            catch {
                Write-Warning $_
                $ContentFilterPolicy + "," + ($Params.values | % { $_ -join " "}) + "," + $_ | Out-file $failedPath -Encoding UTF8 -append
            }
        }
    }
}
