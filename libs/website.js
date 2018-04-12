
var fs = require('fs');
var path = require('path');

var async = require('async');
var watch = require('node-watch');
var redis = require('redis');
var dot = require('dot');
var express = require('express');
var bodyParser = require('body-parser');
var compress = require('compression');

var Stratum = require('merged-pooler');
var util = require('merged-pooler/lib/util.js');

var api = require('./api.js');


module.exports = function(logger){

    dot.templateSettings.strip = false;

    var portalConfig = JSON.parse(process.env.portalConfig);
    var poolConfigs = JSON.parse(process.env.pools);

    var websiteConfig = portalConfig.website;

    var portalApi;
    var portalStats;

    var startPortalApi = function() {
        portalApi = new api(logger, portalConfig, poolConfigs);
        portalStats = portalApi.stats;
    }
    startPortalApi();

    var logSystem = 'Website';

    var pageFiles = {
        'index.html': 'index',
        'home.html': '',
        'getting_started.html': 'getting_started',
        'stats.html': 'stats',
        'workers.html': 'workers',
        'api.html': 'api',
        'admin.html': 'admin',
        'mining_key.html': 'mining_key'
    };

    var pageTemplates = {};

    var pageProcessed = {};
    var indexesProcessed = {};

    var keyScriptTemplate = '';
    var keyScriptProcessed = ''; 

    process.on('message', function(message) {
        switch(message.type){
            case 'reloadpool':
                if (message.coin) {
                    var messageCoin = message.coin.toLowerCase();
                    var poolTarget = Object.keys(poolConfigs).filter(function(p){
                        return p.toLowerCase() === messageCoin;
                    })[0];
                    poolConfigs  = JSON.parse(message.pools);
                    startPortalApi();
                }
                break;
        }
    });

    var processTemplates = function(){

        for (var pageName in pageTemplates){
            if (pageName === 'index') continue;
            pageProcessed[pageName] = pageTemplates[pageName]({
                poolsConfigs: poolConfigs,
                stats: portalStats.stats,
                portalConfig: portalConfig
            });
            indexesProcessed[pageName] = pageTemplates.index({
                page: pageProcessed[pageName],
                selected: pageName,
                stats: portalStats.stats,
                poolConfigs: poolConfigs,
                portalConfig: portalConfig
            });
        }

        //logger.debug(logSystem, 'Stats', 'Website updated to latest stats');
    };

    var readPageFiles = function(files){
        async.each(files, function(fileName, callback){
            var filePath = 'website/' + (fileName === 'index.html' ? '' : 'pages/') + fileName;
            fs.readFile(filePath, 'utf8', function(err, data){
                var pTemp = dot.template(data);
                pageTemplates[pageFiles[fileName]] = pTemp
                callback();
            });
        }, function(err){
            if (err){
                console.log('error reading files for creating dot templates: '+ JSON.stringify(err));
                return;
            }
            processTemplates();
        });
    };


    //If an html file was changed reload it
    watch('website', function(filename){
        var basename = path.basename(filename);
        if (basename in pageFiles){
            console.log(filename);
            readPageFiles([basename]);
            logger.debug(logSystem, 'Server', 'Reloaded file ' + basename);
        }
    });

    portalStats.getGlobalStats(function(){
        readPageFiles(Object.keys(pageFiles));
    });

    var buildUpdatedWebsite = function(){
        portalStats.getGlobalStats(function(){
            processTemplates();

            var statData = 'data: ' + JSON.stringify(portalStats.stats) + '\n\n';
            for (var uid in portalApi.liveStatConnections){
                var res = portalApi.liveStatConnections[uid];
                res.write(statData);
            }

        });
    };

    setInterval(buildUpdatedWebsite, websiteConfig.stats.updateInterval * 1000);


    var buildKeyScriptPage = function(){
        async.waterfall([
            function(callback){
                 var client = redis.createClient(portalConfig.redis.port, portalConfig.redis.host);
                 client.auth(portalConfig.redis.password);
                 client.select(portalConfig.redis.db);

                client.hgetall('coinVersionBytes', function(err, coinBytes){
                    if (err){
                        client.quit();
                        return callback('Failed grabbing coin version bytes from redis ' + JSON.stringify(err));
                    }
                    callback(null, client, coinBytes || {});
                });
            },
            function (client, coinBytes, callback){
                var enabledCoins = Object.keys(poolConfigs).map(function(c){return c.toLowerCase()});
                var missingCoins = [];
                enabledCoins.forEach(function(c){
                    if (!(c in coinBytes))
                        missingCoins.push(c);
                });
                callback(null, client, coinBytes, missingCoins);
            },
            function(client, coinBytes, missingCoins, callback){
                var coinsForRedis = {};
                async.each(missingCoins, function(c, cback){
                    var coinInfo = (function(){
                        for (var pName in poolConfigs){
                            if (pName.toLowerCase() === c)
                                return {
                                    daemon: poolConfigs[pName].paymentProcessing.daemon,
                                    address: poolConfigs[pName].address,
                                    dumpprivkeyOptions: ["I_UNDERSTAND_AND_ACCEPT_THE_RISK_OF_DUMPING_AN_HD_PRIVKEY"]
                                }
                        }
                    })();
                    var daemon = new Stratum.daemon.interface([coinInfo.daemon], function(severity, message){
                        logger[severity](logSystem, c, message);
                    });
                    daemon.cmd('dumpprivkey', [coinInfo.address].concat(coinInfo.dumpprivkeyOptions), function(result){
                        if (result[0].error){
                            logger.error(logSystem, c, 'Could not dumpprivkey for ' + c + ' ' + JSON.stringify(result[0].error));
                            cback();
                            return;
                        }

                        var vBytePub = util.getVersionByte(coinInfo.address)[0];
                        var vBytePriv = util.getVersionByte(result[0].response)[0];

                        coinBytes[c] = vBytePub.toString() + ',' + vBytePriv.toString();
                        coinsForRedis[c] = coinBytes[c];
                        cback();
                    });
                }, function(err){
                    callback(null, client, coinBytes, coinsForRedis);
                });
            },
            function(client, coinBytes, coinsForRedis, callback){
                if (Object.keys(coinsForRedis).length > 0){
                    client.hmset('coinVersionBytes', coinsForRedis, function(err){
                        if (err)
                            logger.error(logSystem, 'Init', 'Failed inserting coin byte version into redis ' + JSON.stringify(err));
                        client.quit();
                    });
                }
                else{
                    client.quit();
                }
                callback(null, coinBytes);
            }
        ], function(err, coinBytes){
            if (err){
                logger.error(logSystem, 'Init', err);
                return;
            }
            try{
                keyScriptTemplate = dot.template(fs.readFileSync('website/key.html', {encoding: 'utf8'}));
                keyScriptProcessed = keyScriptTemplate({coins: coinBytes});
            }
            catch(e){
                logger.error(logSystem, 'Init', 'Failed to read key.html file');
            }
        });

    };
    buildKeyScriptPage();

    var getPage = function(pageId){
        if (pageId in pageProcessed){
            var requestedPage = pageProcessed[pageId];
            return requestedPage;
        }
    };

    var route = function(req, res, next){
        var pageId = req.params.page || '';
        if (pageId in indexesProcessed){
            res.header('Content-Type', 'text/html');
            res.end(indexesProcessed[pageId]);
        }
        else
            next();

    };

    var minerpage = function(req, res, next){
        var address = req.params.address || null;

        if (address !== null){
            portalStats.getBalanceByAddress(address, function(){
                processTemplates();

                res.end(indexesProcessed['miner_stats']);

            });
        }
        else
            next();
    };

    var payout = function(req, res, next){
        var address = req.params.address || null;

        if (address !== null){
            portalStats.getPayout(address, function(data){
                res.write(data.toString());
                res.end();
            });
        }
        else
            next();
    };


    var shares = function(req, res, next){
        portalStats.getCoins(function(){
            processTemplates();

            res.end(indexesProcessed['user_shares']);

        });
    };

    var usershares = function(req, res, next){

        var coin = req.params.coin || null;

        if(coin !== null){
            portalStats.getCoinTotals(coin, null, function(){
                processTemplates();

                res.end(indexesProcessed['user_shares']);

            });
        }
        else
            next();
    };


    var app = express();

     app.get('/stats/shares/:coin', usershares);
     app.get('/stats/shares', shares);
     app.get('/miner/:address', minerpage);
     app.get('/payout/:address', payout);

    app.use(bodyParser.json());

    app.get('/get_page', function(req, res, next){
        var requestedPage = getPage(req.query.id);
        if (requestedPage){
            res.end(requestedPage);
            return;
        }
        next();
    });

    app.get('/key.html', function(req, res, next){
        res.end(keyScriptProcessed);
    });

    app.get('/:page', route);

    app.get('/', route);

    app.get('/api/:method', function(req, res, next){
        portalApi.handleApiRequest(req, res, next);
    });

    app.post('/api/admin/:method', function(req, res, next){
        if (portalConfig.website
            && portalConfig.website.adminCenter
            && portalConfig.website.adminCenter.enabled){
            if (portalConfig.website.adminCenter.password === req.body.password)
                portalApi.handleAdminApiRequest(req, res, next);
            else
                res.send(401, JSON.stringify({error: 'Incorrect Password'}));

        }
        else
            next();

    });

    app.use(compress());
    app.use('/static', express.static('website/static', { maxAge: 86400000 * 7}));

    app.use(function(err, req, res, next){
        console.error(err.stack);
        res.send(500, 'Something broke!');
    });

    try {
        app.listen(portalConfig.website.port, portalConfig.website.host, function () {
            logger.debug(logSystem, 'Server', 'Website started on ' + portalConfig.website.host + ':' + portalConfig.website.port);
        });
    }
    catch(e){
        logger.error(logSystem, 'Server', 'Could not start website on ' + portalConfig.website.host + ':' + portalConfig.website.port
            +  ' - its either in use or you do not have permission');
    }


};
