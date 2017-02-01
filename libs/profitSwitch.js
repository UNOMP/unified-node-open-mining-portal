var async  = require('async');
var net    = require('net');
var bignum = require('bignum');
var fs     = require('fs');

var algos  = require('merged-pooler/lib/algoProperties.js');
var util   = require('merged-pooler/lib/util.js');
var Poloniex = require('./apiPoloniex.js');
var Bittrex  = require('./apiBittrex.js');
var Stratum  = require('merged-pooler');

module.exports = function(logger){

    var _this = this;

    var portalConfig = JSON.parse(process.env.portalConfig);
    var poolConfigs = JSON.parse(process.env.pools);

    var logSystem = 'Profit';

    // 
    // build status tracker for collecting coin market information
    //
    var profitStatus = {};
    var symbolToAlgorithmMap = {};
    
    process.on('message', function(message) {
        switch(message.type){
            case 'reloadpool':
                if (message.coin) {
                    var messageCoin = message.coin.toLowerCase();
                    var poolTarget = Object.keys(poolConfigs).filter(function(p){
                        return p.toLowerCase() === messageCoin;
                    })[0];
                    poolConfigs  = JSON.parse(message.pools);
                    populateProfitStatus(poolConfigs);
                    checkProfitStatus();
                }
                break;
	    }
    });	        
    
    var populateProfitStatus = function() {

        Object.keys(poolConfigs).forEach(function(coin){

            var poolConfig = poolConfigs[coin];
            var algo       = poolConfig.coin.algorithm;

            if (!profitStatus.hasOwnProperty(algo)) {
                profitStatus[algo] = {};
            }
            var coinStatus = {
                name: poolConfig.coin.name,
                symbol: poolConfig.coin.symbol,
                difficulty: 0,
                reward: 0,
                exchangeInfo: {}
            };
            profitStatus[algo][poolConfig.coin.symbol] = coinStatus;
            symbolToAlgorithmMap[poolConfig.coin.symbol] = algo;
        });
    }

    var checkProfitStatus = function() {

        // 
        // ensure we have something to switch
        //
        Object.keys(profitStatus).forEach(function(algo){
            if (Object.keys(profitStatus[algo]).length <= 1) {
                delete profitStatus[algo];
                Object.keys(symbolToAlgorithmMap).forEach(function(symbol){
                    if (symbolToAlgorithmMap[symbol] === algo)
                        delete symbolToAlgorithmMap[symbol];
                });
            }
        });
        if (Object.keys(profitStatus).length == 0){
            logger.debug(logSystem, 'Config', 'No alternative coins to switch to in current config, switching disabled.');
            return true;
        }
        return false
    }

    populateProfitStatus();
    if (checkProfitStatus())
        return;
    
    // 
    // setup APIs
    //
    var poloApi =  new Poloniex(
        // 'API_KEY',
        // 'API_SECRET'
    );
    var bittrexApi =  new Bittrex(
        // 'API_KEY',
        // 'API_SECRET'
    );

    // 
    // market data collection from Poloniex
    //
    this.getProfitDataPoloniex = function(callback){
        async.series([
            function(taskCallback){
                poloApi.getTicker(function(err, data){
                    if (err){
                        taskCallback(err);
                        return;
                    }

                    Object.keys(symbolToAlgorithmMap).forEach(function(symbol){
                        var exchangeInfo = profitStatus[symbolToAlgorithmMap[symbol]][symbol].exchangeInfo;
                        if (!exchangeInfo.hasOwnProperty('Poloniex'))
                            exchangeInfo['Poloniex'] = {};
                        var marketData = exchangeInfo['Poloniex'];

                        if (data.hasOwnProperty('BTC_' + symbol)) {
                            if (!marketData.hasOwnProperty('BTC'))
                                marketData['BTC'] = {};

                            var btcData = data['BTC_' + symbol];
                            marketData['BTC'].ask = new Number(btcData.lowestAsk);
                            marketData['BTC'].bid = new Number(btcData.highestBid);
                            marketData['BTC'].last = new Number(btcData.last);
                            marketData['BTC'].baseVolume = new Number(btcData.baseVolume);
                            marketData['BTC'].quoteVolume = new Number(btcData.quoteVolume);
                        }
                        if (data.hasOwnProperty('LTC_' + symbol)) {
                            if (!marketData.hasOwnProperty('LTC'))
                                marketData['LTC'] = {};

                            var ltcData = data['LTC_' + symbol];
                            marketData['LTC'].ask = new Number(ltcData.lowestAsk);
                            marketData['LTC'].bid = new Number(ltcData.highestBid);
                            marketData['LTC'].last = new Number(ltcData.last);
                            marketData['LTC'].baseVolume = new Number(ltcData.baseVolume);
                            marketData['LTC'].quoteVolume = new Number(ltcData.quoteVolume);
                        }
                        // save LTC to BTC exchange rate
                        if (marketData.hasOwnProperty('LTC') && data.hasOwnProperty('BTC_LTC')) {
                            var btcLtc = data['BTC_LTC'];
                            marketData['LTC'].ltcToBtc = new Number(btcLtc.highestBid);
                        }
                    });

                    taskCallback();
                });
            },
            function(taskCallback){
                var depthTasks = [];
                Object.keys(symbolToAlgorithmMap).forEach(function(symbol){
                    var marketData = profitStatus[symbolToAlgorithmMap[symbol]][symbol].exchangeInfo['Poloniex'];
                    if (marketData.hasOwnProperty('BTC') && marketData['BTC'].bid > 0){
                        depthTasks.push(function(callback){
                            _this.getMarketDepthFromPoloniex('BTC', symbol, marketData['BTC'].bid, callback) 
                        });
                    }
                    if (marketData.hasOwnProperty('LTC') && marketData['LTC'].bid > 0){
                        depthTasks.push(function(callback){
                            _this.getMarketDepthFromPoloniex('LTC', symbol, marketData['LTC'].bid, callback) 
                        });
                    }
                });

                if (!depthTasks.length){
                    taskCallback();
                    return;
                }
                async.series(depthTasks, function(err){
                    if (err){
                        taskCallback(err);
                        return;
                    }
                    taskCallback();
                });
            }
        ], function(err){
            if (err){
                callback(err);
                return;
            }
            callback(null);
        });
        
    };
    this.getMarketDepthFromPoloniex = function(symbolA, symbolB, coinPrice, callback){
        poloApi.getOrderBook(symbolA, symbolB, function(err, data){
            if (err){
                callback(err);
                return;
            }
            var depth = new Number(0);
            var totalQty = new Number(0);
            if (data.hasOwnProperty('bids')){
                data['bids'].forEach(function(order){
                    var price = new Number(order[0]);
                    var limit = new Number(coinPrice * portalConfig.profitSwitch.depth);
                    var qty = new Number(order[1]);
                    // only measure the depth down to configured depth
                    if (price >= limit){
                       depth += (qty * price);
                       totalQty += qty;
                    }
                });
            }

            var marketData = profitStatus[symbolToAlgorithmMap[symbolB]][symbolB].exchangeInfo['Poloniex'];
            marketData[symbolA].depth = depth;
            if (totalQty > 0)
                marketData[symbolA].weightedBid = new Number(depth / totalQty);
            callback();
        });
    };

    
    this.getProfitDataBittrex = function(callback){
        async.series([
            function(taskCallback){
                bittrexApi.getTicker(function(err, response){
                    if (err || !response.result){
                        taskCallback(err);
                        return;
                    }

                    Object.keys(symbolToAlgorithmMap).forEach(function(symbol){
                        response.result.forEach(function(market){
                            var exchangeInfo = profitStatus[symbolToAlgorithmMap[symbol]][symbol].exchangeInfo;
                            if (!exchangeInfo.hasOwnProperty('Bittrex'))
                                exchangeInfo['Bittrex'] = {};

                            var marketData = exchangeInfo['Bittrex'];
                            var marketPair = market.MarketName.match(/([\w]+)-([\w-_]+)/)
                            market.exchange = marketPair[1]
                            market.code = marketPair[2]
                            if (market.exchange == 'BTC' && market.code == symbol) {
                                if (!marketData.hasOwnProperty('BTC'))
                                    marketData['BTC'] = {};

                                marketData['BTC'].last = new Number(market.Last);
                                marketData['BTC'].baseVolume = new Number(market.BaseVolume);
                                marketData['BTC'].quoteVolume = new Number(market.BaseVolume / market.Last);
                                marketData['BTC'].ask = new Number(market.Ask);
                                marketData['BTC'].bid = new Number(market.Bid);
                            }

                            if (market.exchange == 'LTC' && market.code == symbol) {
                                if (!marketData.hasOwnProperty('LTC'))
                                    marketData['LTC'] = {};

                                marketData['LTC'].last = new Number(market.Last);
                                marketData['LTC'].baseVolume = new Number(market.BaseVolume);
                                marketData['LTC'].quoteVolume = new Number(market.BaseVolume / market.Last);
                                marketData['LTC'].ask = new Number(market.Ask);
                                marketData['LTC'].bid = new Number(market.Bid);
                            }

                        });
                    });
                    taskCallback();
                });
            },
            function(taskCallback){
                var depthTasks = [];
                Object.keys(symbolToAlgorithmMap).forEach(function(symbol){
                    var marketData = profitStatus[symbolToAlgorithmMap[symbol]][symbol].exchangeInfo['Bittrex'];
                    if (marketData.hasOwnProperty('BTC') && marketData['BTC'].bid > 0){
                        depthTasks.push(function(callback){
                            _this.getMarketDepthFromBittrex('BTC', symbol, marketData['BTC'].bid, callback) 
                        });
                    }
                    if (marketData.hasOwnProperty('LTC') && marketData['LTC'].bid > 0){
                        depthTasks.push(function(callback){
                            _this.getMarketDepthFromBittrex('LTC', symbol, marketData['LTC'].bid, callback) 
                        });
                    }
                });

                if (!depthTasks.length){
                    taskCallback();
                    return;
                }
                async.series(depthTasks, function(err){
                    if (err){
                        taskCallback(err);
                        return;
                    }
                    taskCallback();
                });
            }
        ], function(err){
            if (err){
                callback(err);
                return;
            }
            callback(null);
        });
    };
    this.getMarketDepthFromBittrex = function(symbolA, symbolB, coinPrice, callback){
        bittrexApi.getOrderBook(symbolA, symbolB, function(err, response){
            if (err){
                callback(err);
                return;
            }
            var depth = new Number(0);
            if (response.hasOwnProperty('result') && response.success == true){
                var totalQty = new Number(0);
                response['result'].forEach(function(order){
                    var price = new Number(order.Rate);
                    var limit = new Number(coinPrice * portalConfig.profitSwitch.depth);
                    var qty = new Number(order.Quantity);
                    // only measure the depth down to configured depth
                    if (price >= limit){
                       depth += (qty * price);
                       totalQty += qty;
                    }
                });
            } else {
		logger.error(logSystem, symbolB, 'Error while getting Bittrex market information: ' + response.message);
		callback();
                return;
	    }

            var marketData = profitStatus[symbolToAlgorithmMap[symbolB]][symbolB].exchangeInfo['Bittrex'];
            marketData[symbolA].depth = depth;
            if (totalQty > 0)
                marketData[symbolA].weightedBid = new Number(depth / totalQty);
            callback();
        });
    };


    this.getCoindDaemonInfo = function(callback){
        var daemonTasks = [];
        Object.keys(profitStatus).forEach(function(algo){
            Object.keys(profitStatus[algo]).forEach(function(symbol){
                var coinName = profitStatus[algo][symbol].name;
                var poolConfig = poolConfigs[coinName];
                var daemonConfig = poolConfig.paymentProcessing.daemon;
                daemonTasks.push(function(callback){
                    _this.getDaemonInfoForCoin(symbol, daemonConfig, callback)
                });
            });
        });

        if (daemonTasks.length == 0){
            callback();
            return;
        }
        async.series(daemonTasks, function(err){
            if (err){
                callback(err);
                return;
             }
             callback(null);
        });
    };
    this.getDaemonInfoForCoin = function(symbol, cfg, callback){
        var daemon = new Stratum.daemon.interface([cfg], function(severity, message){
            logger[severity](logSystem, symbol, message);
            callback(null); // fail gracefully for each coin
        });
        if (symbol == 'PPC') {
            daemon.cmd('getblocktemplate', [{"mode": "template" }], function(result) {
                if (result[0].error != null) {
                    logger.error(logSystem, symbol, 'Error while reading daemon info: ' + JSON.stringify(result[0]));
                    callback(null); // fail gracefully for each coin
                    return;
                }
                var coinStatus = profitStatus[symbolToAlgorithmMap[symbol]][symbol];
                var response = result[0].response;

                // some shitcoins dont provide target, only bits, so we need to deal with both
                var target = response.target ? bignum(response.target, 16) : util.bignumFromBitsHex(response.bits);
                coinStatus.difficulty = parseFloat((diff1 / target.toNumber()).toFixed(9));
                logger.warn(logSystem, symbol, 'difficulty is ' + coinStatus.difficulty);

                coinStatus.reward = response.coinbasevalue / 1000000;
                callback(null);
            });
        } else {
            daemon.cmd('getblocktemplate', [{"capabilities": [ "coinbasetxn", "workid", "coinbase/append" ]}], function(result) {
                if (result[0].error != null) {
                    logger.error(logSystem, symbol, 'Error while reading daemon info: ' + JSON.stringify(result[0]));
                    callback(null); // fail gracefully for each coin
                    return;
                }
                var coinStatus = profitStatus[symbolToAlgorithmMap[symbol]][symbol];
                var response = result[0].response;
    
                // some shitcoins dont provide target, only bits, so we need to deal with both
                var target = response.target ? bignum(response.target, 16) : util.bignumFromBitsHex(response.bits);
                coinStatus.difficulty = parseFloat((diff1 / target.toNumber()).toFixed(9));
                logger.warn(logSystem, symbol, 'difficulty is ' + coinStatus.difficulty);
    
            if (coinStatus.name == 'dogecoindark'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'cryptobullion'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'tekcoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'battlecoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'opensourcecoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'legendarycoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'novacoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
            else if (coinStatus.name == 'tagcoin'){coinStatus.reward = response.coinbasevalue / 1000000;}
    
            else{coinStatus.reward = response.coinbasevalue / 100000000;}
            callback(null);
            });
	}
    };


    this.getMiningRate = function(callback){
        var daemonTasks = [];
        Object.keys(profitStatus).forEach(function(algo){
            Object.keys(profitStatus[algo]).forEach(function(symbol){
                var coinStatus = profitStatus[symbolToAlgorithmMap[symbol]][symbol];
                if (algo == "sha256"){
	coinStatus.blocksPerMhPerHour = 86400 / ((coinStatus.difficulty * Math.pow(2,32)) / (1 * 1000 * 1000 * 1000));
	} else {coinStatus.blocksPerMhPerHour = 86400 / ((coinStatus.difficulty * Math.pow(2,32)) / (1 * 1000 * 1000));
}
                coinStatus.coinsPerMhPerHour = coinStatus.reward * coinStatus.blocksPerMhPerHour;
            });
        });
        callback(null);
    };


    this.switchToMostProfitableCoins = function() {
        Object.keys(profitStatus).forEach(function(algo) {
            var algoStatus = profitStatus[algo];

            var bestExchange;
            var bestCoin;
            var bestBtcPerMhPerHour = 0;

            Object.keys(profitStatus[algo]).forEach(function(symbol) {
                var coinStatus = profitStatus[algo][symbol];

                Object.keys(coinStatus.exchangeInfo).forEach(function(exchange){
                    var exchangeData = coinStatus.exchangeInfo[exchange];
                    if (exchangeData.hasOwnProperty('BTC') && exchangeData['BTC'].hasOwnProperty('weightedBid')){
                        var btcPerMhPerHour = exchangeData['BTC'].weightedBid * coinStatus.coinsPerMhPerHour;
                        if (btcPerMhPerHour > bestBtcPerMhPerHour){
                            bestBtcPerMhPerHour = btcPerMhPerHour;
                            bestExchange = exchange;
                            bestCoin = profitStatus[algo][symbol].name;
                        }
                        coinStatus.btcPerMhPerHour = btcPerMhPerHour;
                        logger.warn(logSystem, 'CALC', 'BTC/' + symbol + ' on ' + exchange + ' with ' + coinStatus.btcPerMhPerHour.toFixed(8) + ' BTC/day per Mh/s');
                    }
                    if (exchangeData.hasOwnProperty('LTC') && exchangeData['LTC'].hasOwnProperty('weightedBid')){
                        var btcPerMhPerHour = (exchangeData['LTC'].weightedBid * coinStatus.coinsPerMhPerHour) * exchangeData['LTC'].ltcToBtc;
                        if (btcPerMhPerHour > bestBtcPerMhPerHour){
                            bestBtcPerMhPerHour = btcPerMhPerHour;
                            bestExchange = exchange;
                            bestCoin = profitStatus[algo][symbol].name;
                        }
                        coinStatus.btcPerMhPerHour = btcPerMhPerHour;
                        logger.warn(logSystem, 'CALC', 'LTC/' + symbol + ' on ' + exchange + ' with ' + coinStatus.btcPerMhPerHour.toFixed(8) + ' BTC/day per Mh/s');
                    }
                });
            });
            logger.warn(logSystem, 'RESULT', 'Best coin for ' + algo + ' is ' + bestCoin + ' on ' + bestExchange + ' with ' + bestBtcPerMhPerHour.toFixed(8) + ' BTC/day per Mh/s');
			// Uncomment for advanced reporting, not included in base repo. You must do some magic on your side ;)
			//fs.writeFile('~/unomp/website/static/' + algo + '.txt', bestBtcPerMhPerHour.toFixed(8),function (err) {
  			//	if (err) throw err;
		//});
            var client = net.connect(portalConfig.cliPort, function () {
                client.write(JSON.stringify({
                    command: 'coinswitch',
                    params: [bestCoin],
                    options: {algorithm: algo}
                }) + '\n');
            }).on('error', function(error){
                if (error.code === 'ECONNREFUSED')
                    logger.error(logSystem, 'CLI', 'Could not connect to UNOMP instance on port ' + portalConfig.cliPort);
                else
                    logger.error(logSystem, 'CLI', 'Socket error ' + JSON.stringify(error));
            });

        });
    };


    var checkProfitability = function(){
        logger.warn(logSystem, 'Check', 'Collecting profitability data.');

        profitabilityTasks = [];
        if (portalConfig.profitSwitch.usePoloniex)
            profitabilityTasks.push(_this.getProfitDataPoloniex);

        if (portalConfig.profitSwitch.useBittrex)
            profitabilityTasks.push(_this.getProfitDataBittrex);

        profitabilityTasks.push(_this.getCoindDaemonInfo);
        profitabilityTasks.push(_this.getMiningRate);

        // has to be series 
        async.series(profitabilityTasks, function(err){
            if (err){
                logger.error(logSystem, 'Check', 'Error while checking profitability: ' + err);
                return;
            }
            //
            // TODO offer support for a userConfigurable function for deciding on coin to override the default
            // 
            _this.switchToMostProfitableCoins();
        });
    };
    setInterval(checkProfitability, portalConfig.profitSwitch.updateInterval * 1000);

};
