$dcs = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain().DomainControllers | select name
 
$startdate = get-date('1/1/1601')
 
$lst = new-Object System.Collections.ArrayList
$out = new-Object System.Collections.ArrayList

foreach ($dc in $dcs) {

	$root = [ADSI] "LDAP://$($dc.Name):389"
	$searcher = New-Object System.DirectoryServices.DirectorySearcher $root
	$searcher.PageSize = 100
	$searcher.filter = "(&(objectCategory=person)(objectClass=user))"
	$searcher.PropertiesToLoad.Add("name") | out-null
	$searcher.PropertiesToLoad.Add("LastLogon") | out-null
	$searcher.PropertiesToLoad.Add("displayName") | out-null
	$searcher.PropertiesToLoad.Add("userAccountControl") | out-null
	$searcher.PropertiesToLoad.Add("canonicalName") | out-null
	$searcher.PropertiesToLoad.Add("title") | out-null
	$searcher.PropertiesToLoad.Add("sAMAccountName") | out-null
	$searcher.PropertiesToLoad.Add("sn") | out-null
	$searcher.PropertiesToLoad.Add("givenName") | out-null
	$results = $searcher.FindAll()
	 
	foreach ($result in $results)
	{ 
	 		 
		$user = $result.Properties;
		$usr = $user | select -property @{name="Name"; expression={$_.name}},
				@{name="LastLogon"; expression={$_.lastlogon}},
				@{name="DisplayName"; expression={$_.displayname}},
				@{name="Disabled"; expression={(($_.useraccountcontrol[0]) -band 2) -eq 2}},
				@{name="CanonicalName"; expression={$_.canonicalname}},
				@{name="Title"; expression={$_.title}},
				@{name="sAMAccountName"; expression={$_.samaccountname}},
				@{name="LastName"; expression={$_.sn}},
				@{name="FirstName"; expression={$_.givenname}}
								
		$lst.Add($usr) | Add-Member -Name LastLogonMnd -Value $LastLogonMonth -MemberType NoteProperty | out-null
	}
}


$lst |	group name | 
		select-object Name, 
			@{Expression={ ($_.Group | Measure-Object -property LastLogon -max).Maximum }; Name="LastLogon" },
			@{Expression={ ($_.Group | select-object -first 1).DisplayName}; Name="DisplayName" },
			@{Expression={ ($_.Group | select-object -first 1).CanonicalName}; Name="CanonicalName" },
			@{Expression={ ($_.Group | select-object -first 1).Title}; Name="Title" },
			@{Expression={ ($_.Group | select-object -first 1).sAMAccountName + "<CorrelationKey>"}; Name="sAMAccountname" },
			@{Expression={ ($_.Group | select-object -first 1).LastName}; Name="LastName" },
			@{Expression={ ($_.Group | select-object -first 1).FirstName}; Name="FirstName" },
			@{Expression={ ($_.Group | select-object -first 1).Disabled}; Name="Disabled" }|
		select-object sAMAccountname, Name,
			@{Expression={ "Toll" }; Name="domain" },
			@{Expression={ "user" }; Name="endPoint" },
			@{Expression={ $startdate.adddays(($_.LastLogon / (60 * 10000000)) / 1440) }; Name="LastLogonTime" },
			# Denne kalkulerer hvor gammel lastlogon er, og skriver 2mnd, 6mnd eller Null som verdi. 
			@{Expression={ $ll=$startdate.adddays(($_.LastLogon / (60 * 10000000)) / 1440); if ($ll -eq $startdate) {"Aldri"} elseif ($ll -le (Get-Date).AddDays(-180)) { "6mnd" } elseif ($ll -le (Get-Date).AddDays(-60)) { "2mnd" } else {""} }; Name="LastLogonMonth" },
			Disabled | 
			Convertto-Csv | select -skip 2 | Out-File -FilePath "c:\temp\out.csv" -Encoding "UTF8"

