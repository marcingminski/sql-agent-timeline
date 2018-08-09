Param (
 [parameter(
        Mandatory         = $true,
        ValueFromPipeline = $false)]
    $DbaAgentJobHistory,
 [Switch]$NoOpen
)    

#------------------------------------------------------------------------------------------------------------------------------------------------
# function to convert human time to java script time format: new Date( Year, Month, Day, Hour, Minute, Second)
# Java script time is zero base which means January = 0 and December = 11
#------------------------------------------------------------------------------------------------------------------------------------------------
Function Convert-ToJsDate ([datetime]$InputDate) {
    $out = "new Date($(Get-Date $InputDate -format "yyyy"), $($(Get-Date $InputDate -format "MM")-1), $(Get-Date $InputDate -format "dd"), $(Get-Date $InputDate -format "HH"), $(Get-Date $InputDate -format "mm"), $(Get-Date $InputDate -format "ss"))"
    return $out
}
    [datetime]$reportend =  if (!$EndTime -or $EndTime -eq "") {Get-date}
    [datetime]$reportstart = $reportend.AddHours(-$ChartPeriodHours)


#------------------------------------------------------------------------------------------------------------------------------------------------
# strip input out of any extra columns 
#------------------------------------------------------------------------------------------------------------------------------------------------
$Data = $DbaAgentJobHistory | Select ComputerName, InstanceName, Job, StartDate, EndDate, Status
$ServerName = $($($($Data.ComputerName | Select -first 1) + "\" + $($Data.InstanceName | Select -first 1)).ToUpper())


#------------------------------------------------------------------------------------------------------------------------------------------------
# build HTML header section containing all necessary embeded scripts and styling
#------------------------------------------------------------------------------------------------------------------------------------------------
[string]$header=@"
<html>
<head>
<!-- Developed by Marcin Gminski, https://marcin.gminski.net, 2018 -->

<!-- Load jQuery required to autosize timeline -->
<script src="https://code.jquery.com/jquery-3.3.1.min.js" integrity="sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8=" crossorigin="anonymous"></script>

<!-- Load Bootstrap -->
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css" integrity="sha384-rHyoN1iRsVXV4nD0JutlnGaslCJuC7uwjduW9SVrLvRYooPp2bWYgmgJQIXwl/Sp" crossorigin="anonymous">

<!-- Load Google Charts library -->
<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<!-- local styling to either override default boostrap styling or to style custom elements -->
<style>
    html,body{height:100%;background-color:#c2c2c2;}

    .viewport {height:100%}

    .wrapper{
        display:grid;
        grid-template-rows:auto;
        grid-gap:5px;
        width:99%;
        margin-bottom:5px
        height: 100%;
    }
    .col-1{grid-template-columns:1fr}
    .col-2{grid-template-columns:1fr 1fr}
    .col-3{grid-template-columns:1fr 1fr 1fr}
    .col-4{grid-template-columns:1fr 1fr 1fr 1fr}
    .col-5{grid-template-columns:1fr 1fr 1fr 1fr 1fr}
    
    .chart{
        background-color:#fff;
        text-align:left;
        padding:0;
        border:1px solid #7D7D7D;
        -webkit-box-shadow:1px 1px 3px 0 rgba(0,0,0,.45);
        -moz-box-shadow:1px 1px 3px 0 rgba(0,0,0,.45);
        box-shadow:1px 1px 3px 0 rgba(0,0,0,.45)
    }

    .timeline-tooltip{
        border:1px solid #E0E0E0;
        font-family:Arial,Helvetica;
        font-size:10pt;
        padding:12px
    }
    .timeline-tooltip div{padding:6px}
    .timeline-tooltip span{font-weight:700}
    .badge-custom{background-color:#939}

    .container {
        height:100%;
    }

    .fill{
        width:100%;
        height:100%;
        min-height:100%;
        padding:10px;
    }
</style>
"@

#------------------------------------------------------------------------------------------------------------------------------------------------
# generate section of the HTML code that will contain javascript for the Google Chart object
#------------------------------------------------------------------------------------------------------------------------------------------------
 [string]$header+=@"
    <script type="text/javascript">
    google.charts.load('43', {'packages':['timeline']});
    google.charts.setOnLoadCallback(drawChart);

    function drawChart() {
        var container = document.getElementById('WhoIsActiveTimeLine');
        var chart = new google.visualization.Timeline(container);

        var dataTable = new google.visualization.DataTable();
        dataTable.addColumn({type: 'string', id: 'vLabel'});
        dataTable.addColumn({type: 'string', id: 'hLabel'});
        dataTable.addColumn({type: 'date', id: 'date_start'});
        dataTable.addColumn({type: 'date', id: 'date_end'});

        dataTable.addRows([
     $( $data | %{"['$($_.Job)','$($_.Status)',$(Convert-ToJsDate $_.StartDate), $(Convert-ToJsDate $_.EndDate)],`r`n"})
        ]);

        var paddingHeight = 20;
        var rowHeight = dataTable.getNumberOfRows() * 41;
        var chartHeight = rowHeight + paddingHeight;

        dataTable.insertColumn(2, {type: 'string', role: 'tooltip', p: {html: true}});

        var dateFormat = new google.visualization.DateFormat({
          pattern: 'dd/MM/yy hh:mm:ss'
        });

        var colors=[];
        var colorMap = {
            Failed: '#FF3D3D',
            Succeeded: '#2EB800',
            Retry: '#7A7AFF',
            Canceled: '#C2C2C2'
        }


        for (var i = 0; i < dataTable.getNumberOfRows(); i++) {
          colors.push(colorMap[dataTable.getValue(i, 1)]);
          var duration = (dataTable.getValue(i, 4).getTime() - dataTable.getValue(i, 3).getTime()) / 1000;
          var hours = parseInt( duration / 3600 ) % 24;
          var minutes = parseInt( duration / 60 ) % 60;
          var seconds = duration % 60;

          var tooltip = '<div class="timeline-tooltip"><span>' +
            dataTable.getValue(i, 1).split(",").join("<br />")  + '</span></div><div class="timeline-tooltip"><span>Job: ' +
            dataTable.getValue(i, 0) + '</span>: ' +
            dateFormat.formatValue(dataTable.getValue(i, 3)) + ' - ' +
            dateFormat.formatValue(dataTable.getValue(i, 4)) + '</div>' +
            '<div class="timeline-tooltip"><span>Duration: </span>' +
            hours + 'h ' + minutes + 'm ' + seconds + 's ';

          dataTable.setValue(i, 2, tooltip);

            var options = {
                timeline: { 
                    rowLabelStyle: { },
                    barLabelStyle: { }, 
                },
                hAxis: {
                    format: 'dd/MM HH:MM',
                },
                colors: colors
            }

            chart.draw(dataTable, options);
            var realheight= parseInt(`$("#WhoIsActiveTimeLine div:first-child div:first-child div:first-child div svg").attr( "height"))+70;
            options.height=realheight
            chart.draw(dataTable, options);
        }

    }
</script>
"@

#------------------------------------------------------------------------------------------------------------------------------------------------
# build the actual HTML body containing chart
#------------------------------------------------------------------------------------------------------------------------------------------------
[string]$body=@"
</head>
<body>
    <div class="container-fluid">
    <h3>SQL jobs Timeline on <code>$ServerName</code> as reported by <code>Get-DbaAgentJobHistory</code></h3>
         <div class="col-12">
            <div class="chart" id="WhoIsActiveTimeLine"></div>
         </div>
         <script>

         </script>
"@

#------------------------------------------------------------------------------------------------------------------------------------------------
# Build footer
#------------------------------------------------------------------------------------------------------------------------------------------------
[string]$footer=@"
    <hr>
    <p>&copy; Marcin Gminski, 2018 | <a href="https://marcin.gminski.net">marcin.gminski.net</a> |  <a href="https://opensource.org/licenses/MIT">MIT License</a></p>
</div>
</body>
</html>
"@

#------------------------------------------------------------------------------------------------------------------------------------------------
# create HTML file and sanitse server names, replace "," and "\"
# "," will appear in servers with non standard port i.e. SQLSERVER001,14431
# "\" will appear in servers with non standard instance i.e. SQLSERVER001\INSTANCE001
#------------------------------------------------------------------------------------------------------------------------------------------------
$ServerName = $ServerName -replace "\\" , "-"
$ServerName = $ServerName -replace ",", "-"

ConvertTo-Html -Head $header -body $body -PostContent  $footer | Out-File "$($ServerName)_SQLAGENT_JOBS.html" -Encoding ASCII

#------------------------------------------------------------------------------------------------------------------------------------------------
# open in default browser if NoOpen flag not set:
#------------------------------------------------------------------------------------------------------------------------------------------------    
if ($NoOpen -eq $False) {
    Invoke-Item "$($ServerName)_SQLAGENT_JOBS.html"
}
