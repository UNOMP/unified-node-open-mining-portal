var redis = require('redis');
client = redis.createClient()
schedule = require('node-schedule');
async = require('async')
var bittrex = require('node.bittrex.api');
bittrex.options({
  'apikey': 'KEY',
  'apisecret': 'SECRET',
  'stream': true,
  'verbose': false,
  'cleartext': true,
  'baseUrl': 'https://bittrex.com/api/v1.1'
});

var exchangeBalances = [];

console.log('Withdraws bitcoin daily + Sells coins every 6 hours');

function bitcoinwithdraw(exchangeBalances, callback) {
  console.log('Withdrawing Bitcoin');
  bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/account/withdraw?apikey=539221df75b74af299958012e09c3912&currency=BTC&quantity=' + exchangeBalances.BTC.Available + '&address=ADDRESS', function( data ) {
    console.log( data );
    callback(null, exchangeBalances);
  }, true);
};

// Sell Coins on Bittrex //
function coinsell() {
  console.log('Selling coins');
  bittrex.getbalances(function(data) {
    getbalance=data.result
    async.waterfall([
      function(callback){
        Object.keys(getbalance).forEach(function(coin) {
          var Name = data.result[coin].Currency;
          var Balance = data.result[coin].Balance;
          exchangeBalances[Name] = {
            Balance: data.result[coin].Balance,
            Available: data.result[coin].Available,
            Pending: data.result[coin].Pending
          };
        });
        callback(null, exchangeBalances);
      }, function(exchangeBalances, callback){
        client.hget("Exchange_Rates", "californium", function(err, exchange) {
          bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-CF&quantity=' + exchangeBalances.CF.Available + '&rate=' + exchange, function( data ) {
            console.log( data );
            callback(null, exchangeBalances);
          }, true);
        });
      }, function(exchangeBalances, callback){
        client.hget("Exchange_Rates", "florincoin", function(err, exchange) {
          bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-FLO&quantity=' + exchangeBalances.FLO.Available + '&rate=' + exchange, function( data ) {
            console.log( data );
            callback(null, exchangeBalances);
          }, true);
        });
      }, function(exchangeBalances, callback){
        client.hget("Exchange_Rates", "omnicoin", function(err, exchange) {
          bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-OMC&quantity=' + exchangeBalances.OMC.Available + '&rate=' + exchange, function( data ) {
            console.log( data );
            callback(null, exchangeBalances);
          }, true);
        });
      }, function(exchangeBalances, callback){
        client.hget("Exchange_Rates", "quatloo", function(err, exchange) {
          bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-QTL&quantity=' + exchangeBalances.QTL.Available + '&rate=' + exchange, function( data ) {
            console.log( data );
            callback(null, exchangeBalances);
          }, true);
        });
      }, function(exchangeBalances, callback){
        client.hget("Exchange_Rates", "unitcurrency", function(err, exchange) {
          bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-UNIT&quantity=' + exchangeBalances.UNIT.Available + '&rate=' + exchange, function( data ) {
            console.log( data );
            callback(null, exchangeBalances);
          }, true);
        });
      }
    ], function() {
      console.log("Done selling coins");
    });
  });
}

var j = schedule.scheduleJob('0 4 * * *', function(){
    async.waterfall([
        function(callback){
            bittrex.getbalances(function(data) {
                getbalance=data.result
                Object.keys(getbalance).forEach(function(coin) {
                    var Name = data.result[coin].Currency;
                    var Balance = data.result[coin].Balance;
                    exchangeBalances[Name] = {
                        Balance: data.result[coin].Balance,
                        Available: data.result[coin].Available,
                        Pending: data.result[coin].Pending,
                        Exchange: 0
                    };
                });
                callback(null, exchangeBalances);
            });
        },
        function(exchangeBalances, callback){
            bitcoinwithdraw(exchangeBalances, callback)
        }
    ], function() {
        console.log('Done withdrawing Coins');
    });
});

var j = schedule.scheduleJob('0 0/6 * * *', function(){
  coinsell();
});
