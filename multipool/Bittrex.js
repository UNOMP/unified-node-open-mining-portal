var redis = require('redis');
client = redis.createClient()
schedule = require('node-schedule');
async = require('async')
var bittrex = require('node.bittrex.api');
bittrex.options({
  'apikey': 'KEY',
  'apisecret': 'SECRET',
  'stream': true,
  'verbose': true,
  'cleartext': true,
  'baseUrl': 'https://bittrex.com/api/v1.1'
});

var foobar = [];



function bitcoinwithdraw() {
  bittrex.getbalances(function(data) {
    console.log('Withdrawing Bitcoin');
    fubar=data.result
    Object.keys(fubar).forEach(function(coin) {
      var Name = data.result[coin].Currency;
      var Balance = data.result[coin].Balance;
      foobar[Name] = {
        Balance: data.result[coin].Balance,
        Available: data.result[coin].Available,
        Pending: data.result[coin].Pending,
        Exchange: 0
      };
      client.hget("Exchange_Rates", Name, function(err, exchange) {
        if (exchange == null) {
          exchange = 0;
        }
        else {
          foobar[Name].Exchange = parseFloat(exchange)
        }
      client.quit();
    });
  });
  bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/account/withdraw?apikey=API-KEY&currency=BTC&quantity=' + foobar.BTC.Available + '&address=ADDRESS', function( data ) {
    console.log( data );
    console.log('Done withdrawing Bitcoin');
  }, true);  
});
};

// Sell Coins on Bittrex //
function coinsell() {
  console.log('Selling coins');
  bittrex.getbalances(function(data) {
    fubar=data.result
    Object.keys(fubar).forEach(function(coin) {
      var Name = data.result[coin].Currency;
      var Balance = data.result[coin].Balance;
      foobar[Name] = {
        Balance: data.result[coin].Balance,
        Available: data.result[coin].Available,
        Pending: data.result[coin].Pending,
        Exchange: 0
      };
      client.hget("Exchange_Rates", Name, function(err, exchange) {
        if (exchange == null) {
          exchange = 0;
        }
        else {
          foobar[Name].Exchange = parseFloat(exchange)
        }
      client.quit();
      });
    });
    client.hget("Exchange_Rates", "californium", function(err, exchange) {
      bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-CF&quantity=' + foobar.CF.Available + '&rate=' + exchange, function( data ) {
        console.log( data );
      }, true);
    });
    client.hget("Exchange_Rates", "florincoin", function(err, exchange) {
      bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-FLO&quantity=' + foobar.FLO.Available + '&rate=' + exchange, function( data ) {
        console.log( data );
      }, true);
    });
    client.hget("Exchange_Rates", "omnicoin", function(err, exchange) {
      bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-OMC&quantity=' + foobar.OMC.Available + '&rate=' + exchange, function( data ) {
        console.log( data );
      }, true);
    });
    client.hget("Exchange_Rates", "quatloo", function(err, exchange) {
      bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-QTL&quantity=' + foobar.QTL.Available + '&rate=' + exchange, function( data ) {
        console.log( data );
      }, true);
    });
    client.hget("Exchange_Rates", "unitcurrency", function(err, exchange) {
      bittrex.sendCustomRequest( 'https://bittrex.com/api/v1.1/market/selllimit?apikey=API-KEY&market=BTC-UNIT&quantity=' + foobar.UNIT.Available + '&rate=' + exchange, function( data ) {
        console.log( data );
      }, true);
    });
  });    
}

console.log('Withdraws bitcoin daily + Sells coins every 6 hours');
var j = schedule.scheduleJob('0 4 * * *', function(){
async.parallel([
    function(){ bitcoinwithdraw(); }
]);
});
var j = schedule.scheduleJob('0 0/6 * * *', function(){
async.parallel([
    function(){ coinsell(); }
]);
});
