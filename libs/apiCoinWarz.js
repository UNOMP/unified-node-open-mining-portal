var request = require('request');
var nonce   = require('nonce');

module.exports = function() {
    'use strict';

    // Module dependencies

    // Constants
    var version         = '0.0.1',
        PUBLIC_API_URL  = 'http://www.coinwarz.com/v1/api/profitability/?apikey=YOUR_API_KEY&algo=all',
        USER_AGENT      = 'unomp/unified-node-open-mining-portal'

    // Helper methods
    function joinCurrencies(currencyA, currencyB){
        return currencyA + '_' + currencyB;
    }

    // Prototype
    CoinWarz.prototype = {
        constructor: CoinWarz,

        // Make an API request
        _request: function(options, callback){
            if (!('headers' in options)){
                options.headers = {};
            }

            options.headers['User-Agent'] = USER_AGENT;
            options.json = true;
            options.strictSSL = CoinWarz.STRICT_SSL;

            request(options, function(err, response, body) {
                callback(err, body);
            });

            return this;
        },

        // Make a public API request
        _public: function(parameters, callback){
            var options = {
                method: 'GET',
                url: PUBLIC_API_URL,
                qs: parameters
            };

            return this._request(options, callback);
        },


        /////


        // PUBLIC METHODS

        getTicker: function(callback){
            var parameters = {
                    method: 'marketdatav2'
                };

            return this._public(parameters, callback);
        },

        getOrderBook: function(currencyA, currencyB, callback){
            var parameters = {
                    command: 'returnOrderBook',
                    currencyPair: joinCurrencies(currencyA, currencyB)
                };

            return this._public(parameters, callback);
        },

        getTradeHistory: function(currencyA, currencyB, callback){
            var parameters = {
                    command: 'returnTradeHistory',
                    currencyPair: joinCurrencies(currencyA, currencyB)
                };

            return this._public(parameters, callback);
        },


        ////
        
    return CoinWarz;
}();
