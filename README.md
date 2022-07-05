# sql-agent-timeline
A simple timeline report for SQL Server Agent Job history

You need dbatools.io to run this

### to execute:
```
.\Get-DbaAgentJobHistoryTimeline.ps1 -DbaAgentJobHistory $(Get-DbaAgentJobHistory -SqlInstance SQLSERVER001 -StartDate ‘2018-08-07 20:00’ -EndDate ‘2018-08-08 20:00’ -ExcludeJobSteps | ?{$(Get-Date $_.EndDate)-gt $(Get-Date $_.StartDate.AddMinutes(1))} )
```

details:
https://marcin.gminski.net/goodies/sql-agent-jobs-timeline/
