$computerobjectname="" 
$samaccountname=""
$ou_path=""
New-ADComputer -Name $computerobjectname -SamAccountName $samaccountname -Path $ou_path
