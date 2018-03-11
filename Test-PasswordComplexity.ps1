$PasswordPolicy = [PSCustomObject]@{
    MinPasswordLength = '12'
    ComplexityEnabled = $true
}
Function Test-PasswordComplexity {
    Param (
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$false)][string]$AccountSamAccountName = '',
        [Parameter(Mandatory=$false)][string]$AccountDisplayName     
        #[Microsoft.ActiveDirectory.Management.ADEntity]$PasswordPolicy = (Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue)
    )
   
    If ($Password.Length -lt $PasswordPolicy.MinPasswordLength) 
    {
        return $false
    }

    if ($AccountDisplayName) 
    {
        $tokens = $AccountDisplayName.Split(",.-,_ #`t")
        foreach ($token in $tokens) 
        {
            if (($token) -and ($Password -match "$token")) 
            {
                return $false
            }
        }
    }

    if ($PasswordPolicy.ComplexityEnabled) 
    {
        $permittedSpecialChars = [Regex]::Escape('~!@#$%^&*_+=`|(){}[]:;"''<>,.?/') -replace ']','\]'
        If (
            ($Password -cmatch '[A-Z\p{Lu}]') `
            + ($Password -cmatch '[a-z\p{Ll}]') `
            + ($Password -match '\d') `
            + ($Password -match "[$permittedSpecialChars]") -ge 3 )
        {
            return $true
        } 
        else
        {    
            return $false
        }
    }
    else {
        return $true
    }
}



Test-PasswordComplexity 'a1B@'  # Fail - Valid Character Set, but too short
Test-PasswordComplexity 'a1B@password'  # Pass - Valid Character Set
Test-PasswordComplexity 'ß!1B@PASSWORD' # Pass - Valid Character Set even with unicode characters (Used a lowercase ß)
Test-PasswordComplexity "ẞ!B@PASSWORD"
Test-PasswordComplexity '!äÄöäöAl5lajrnäöäö1' -AccountDisplayName 'Wade. Walter, Jr' # Fail - Contains JR (case insensitive) which is part of the split apart Display Name
Test-PasswordComplexity '!äÄöäöAl5lanäöäö1' -AccountDisplayName 'Wade. Walter, Jr' # Pass - JR (case insensitive) removed from the password
Test-PasswordComplexity 'Bad password' -AccountDisplayName 'azure' # Fail - spaces don't count as special chars
Test-PasswordComplexity '© or Copyleft' # Fail - copyright sign not treated as an acceptable special char
Test-PasswordComplexity 'We are in the £' # Fail - pound sign neither
Test-PasswordComplexity "I 'quote' thee" # Pass - quotes are good
Test-PasswordComplexity "I put a ] on the wall" # Pass - ] is good