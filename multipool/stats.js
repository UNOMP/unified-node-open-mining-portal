var algoHashrateData;

var algoHashrateChart;

var statData = [];
var algoKeys = [];

var timeHolder;
var columnBuffer = 0;
var algoColors;

function trimData(data, interval) {
    var retentionTime = Date.now() / 1000 - interval | 0;
    if(data.length > 60){
        for (var i = data.length - 1; i >= 0; i--){
            if (retentionTime > data[i].time){
                statData = data.slice(i);
                break;
            }
        }
    } else {
        statData = data;
    }

}

function buildChartData(){
    var algos = {};

    algoKeys = [];
    for (var i = 0; i < statData.length; i++){
        for (var algo in statData[i].algos){
            if (algoKeys.indexOf(algo) === -1)
                algoKeys.push(algo);
        }
    }

    for (var i = 0; i < statData.length; i++){

        var time = statData[i].time * 1000;

        for (var f = 0; f < algoKeys.length; f++){

            var pName = algoKeys[f];

            var a = algos[pName] = (algos[pName] || {
                hashrate: []
            });

            if (pName in statData[i].algos){
                a.hashrate.push([time, statData[i].algos[pName].hashrate]);
            }
            else{
                a.hashrate.push([time, 0]);
            }

        }

    }

    algoHashrateData = [];

    for (var algo in algos){
        algoHashrateData.push({
            key: algo,
            values: algos[algo].hashrate
        });
    }
}

function removeAllSeries() {
    while(algoHashrateChart.series.length > 0)
        algoHashrateChart.series[0].remove();
}

function changeGraphTimePeriod(timePeriod, sender) {
    timeHolder = new Date().getTime();
    removeAllSeries();
    $.getJSON('/api/algo_stats', function (data) {
        trimData(data, timePeriod);
        buildChartData();
        displayCharts();
        console.log("time to changeTimePeriod: " + (new Date().getTime() - timeHolder));
    });

    $('#scale_menu li a').removeClass('pure-button-active');
    $('#' + sender).addClass('pure-button-active');
}

function setHighchartsOptions() {
    Highcharts.setOptions({
        global : {
            useUTC : false
        }
    });
    var graphColors = $('#bottomCharts').data('info');
    if(graphColors !== 'undefined') {
        Highcharts.theme = {
            colors: graphColors.split(",")
        };
        Highcharts.setOptions(Highcharts.theme);
    }
}

function createCharts() {
    setHighchartsOptions();
    algoHashrateChart = new Highcharts.Chart({
        chart: {
            renderTo: 'algoHashRateChart',
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
            animation: true,
            shadow: false,
            borderWidth: 0,
            zoomType: 'x'
        },
        credits: {
            enabled: false
        },
        exporting: {
            enabled: false
        },
        title: {
            text: 'Hashrate Per algo'
        },
        xAxis: {
            type: 'datetime',
            dateTimeLabelFormats: {
                second: '%I:%M:%S %p',
                minute: '%I:%M %p',
                hour: '%I:%M %p',
                day: '%I:%M %p'
            },
            title: {
                text: null
            },
            minRange: 36000
        },
        yAxis: {
            labels: {
                formatter: function () {
                    return getReadableHashRateString(this.value, 'beta');
                }
            },
            title: {
                text: null
            },
            min: 0
        },
        tooltip: {
            shared: true,
            valueSuffix: ' H/s',
            crosshairs: true,
            useHTML: true,
            formatter: function () {
                var s = '<b>' + timeOfDayFormat(this.x) + '</b>';

                var hashrate = 0;
                $.each(this.points, function (i, point) {
                    val = getReadableHashRateString(point.y, 'tooltip');
                    s += '<br/> <span style="color:' + point.series.color + '" x="8" dy="16">&#9679;</span> ' + point.series.name + ': ' + val;
                });
                return s;
            }
        },
        legend: {
            enabled: true,
            borderWidth: 0
        },
        plotOptions: {
            spline: {
                marker: {
                    enabled: false
                },
                lineWidth: 1.75,
                shadow: false,
                states: {
                    hover: {
                        lineWidth: 1.75
                    }
                },
                threshold: null,
                animation: true
            }
        },
        series: []
    });
}

function displayCharts(){
    for (var i = 0; i < algoKeys.length; i++) {
        if(algoHashrateChart.series.length < algoKeys.length) {
            algoHashrateChart.addSeries({
                type: 'spline',
                name: capitaliseFirstLetter(algoHashrateData[i].key),
                data: algoHashrateData[i].values,
                lineWidth: 2
            }, false);
        }

        if (typeof algoColors !== "undefined") {
            var pName = algoKeys[i].toLowerCase();
            algoHashrateChart.series[i].update({color: algoColors[pName].color}, false);
        }
    }
    algoHashrateChart.redraw();
}


function getInternetExplorerVersion(){
    var rv = -1; // Return value assumes failure.
    if (navigator.appName == 'Microsoft Internet Explorer')
    {
        var ua = navigator.userAgent;
        var re  = new RegExp("MSIE ([0-9]{1,}[\.0-9]{0,})");
        if (re.exec(ua) != null)
            rv = parseFloat( RegExp.$1 );
    }
    return rv;
}

function getReadableHashRateString(hashrate, version){
    if(version == 'default') {
        var i = -1;
        var byteUnits = [ ' KH', ' MH', ' GH', ' TH', ' PH' ];
        do {
            hashrate = hashrate / 1024;
            i++;
        } while (hashrate > 1024);
        return Math.round(hashrate) + byteUnits[i];
    } else if(version == 'beta') {
        if (hashrate > Math.pow(1000, 4)) {
            return (hashrate / Math.pow(1000, 4)) + ' TH/s';
        }
        if (hashrate > Math.pow(1000, 3)) {
            return (hashrate / Math.pow(1000, 3)) + ' GH/s';
        }
        if (hashrate > Math.pow(1000, 2)) {
            return (hashrate / Math.pow(1000, 2)) + ' MH/s';
        }
        if (hashrate > Math.pow(1000, 1)) {
            return (hashrate / Math.pow(1000, 1)) + ' KH/s';
        }
        return hashrate + ' H/s';
    } else if(version == 'tooltip') {
        if (hashrate > Math.pow(1000, 4)) {
            return (hashrate / Math.pow(1000, 4)).toFixed(2) + ' TH/s';
        } else if (hashrate > Math.pow(1000, 3)) {
            return (hashrate / Math.pow(1000, 3)).toFixed(2) + ' GH/s';
        } else if (hashrate > Math.pow(1000, 2)) {
            return (hashrate / Math.pow(1000, 2)).toFixed(2) + ' MH/s';
        } else if (hashrate > Math.pow(1000, 1)) {
            return (hashrate / Math.pow(1000, 1)).toFixed(2) + ' KH/s';
        } else {
            return hashrate + ' H/s';
        }
    }
}

function capitaliseFirstLetter(string){
    return string.charAt(0).toUpperCase() + string.substring(1);
}

function timeOfDayFormat(timestamp){
    var tempTime = moment(timestamp).format('MMM Do - h:mm A');
    if (tempTime.indexOf('0') === 0) tempTime = tempTime.slice(1);
    return tempTime;
}

(function ($){
    timeHolder = new Date().getTime();
    var ver = getInternetExplorerVersion();
    if (ver !== -1 && ver<=10.0) {
        $(window).load(function(){
            createCharts();
            $.getJSON('/api/algo_stats', function (data) {
                trimData(data, 1800);
                buildChartData();
                displayCharts();
                console.log("time to load: " + (new Date().getTime() - timeHolder));
            });
        });
    } else {
        $(function() {
            createCharts();
            $.getJSON('/api/algo_stats', function (data) {
                trimData(data, 1800);
                buildChartData();
                displayCharts();
                console.log("time to load: " + (new Date().getTime() - timeHolder));
            });
        });
    }
}(jQuery));
window.statsSource = new EventSource("/api/live_stats");
statsSource.addEventListener('message', function(e){ //Stays active when hot-swapping pages
    var stats = JSON.parse(e.data);
    statData.push(stats);
    var newalgoAdded = (function(){
        for (var p in stats.algos){
            if (algoKeys.indexOf(p) === -1)
                return true;
        }
        return false;
    })();

    if (newalgoAdded || Object.keys(stats.algos).length > algoKeys.length){
        buildChartData();
    }
    else {
        timeHolder = new Date().getTime(); //Temporary
        var time = stats.time * 1000;

        for (var f = 0; f < algoKeys.length; f++) {
            var algo =  algoKeys[f];
            for (var i = 0; i < algoHashrateData.length; i++) {
                if (algoHashrateData[i].key === algo) {
                    algoHashrateData[i].values.shift();
                    algoHashrateData[i].values.push([time, algo in stats.algos ? stats.algos[algo].hashrate : 0]);
                    if(algoHashrateChart.series[f].name.toLowerCase() === algo) {
                        algoHashrateChart.series[f].setData(algoHashrateData[i].values, true);
                    }
                    break;
                }
            }
        }
    }
    console.log("time to update stats: " + (new Date().getTime() - timeHolder));
});
