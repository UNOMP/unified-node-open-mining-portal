var request = require('request');
var nonce   = require('nonce');

module.exports = function() {
    'use strict';

    // Module dependencies

    // Constants
    var version         = '0.1.1',
        PUBLIC_API_URL = 'https://yobit.net/api/3',
        USER_AGENT      = 'unomp/unified-node-open-mining-portal'

    // Constructor
    function Yobit(key, secret){
        // Generate headers signed by this user's key and secret.
        // The secret is encapsulated and never exposed
        this._getPrivateHeaders = function(parameters){
            var paramString, signature;

            if (!key || !secret){
                throw 'Yobit: Error. API key and secret required';
            }

            // Sort parameters alphabetically and convert to `arg1=foo&arg2=bar`
            paramString = Object.keys(parameters).sort().map(function(param){
                return encodeURIComponent(param) + '=' + encodeURIComponent(parameters[param]);
            }).join('&');

            signature = crypto.createHmac('sha512', secret).update(paramString).digest('hex');

            return {
                Key: key,
                Sign: signature
            };
        };
    }

    // If a site uses non-trusted SSL certificates, set this value to false
    Yobit.STRICT_SSL = true;

    // Helper methods
    function joinCurrencies(currencyA, currencyB){
        return currencyB + '_' + currencyA;
    }

    // Prototype
    Yobit.prototype = {
        constructor: Yobit,

        // Make an API request
        _request: function(options, callback){
            if (!('headers' in options)){
                options.headers = {};
            }

            options.headers['User-Agent'] = USER_AGENT;
            options.json = true;
            options.strictSSL = Yobit.STRICT_SSL;

            request(options, function(err, response, body) {
                callback(err, body);
            });

            return this;
        },

        // Make a public API request
        _public: function(parameters, callback){
            var options = {
                method: 'GET',
                url: PUBLIC_API_URL+'/'+parameters

            };

            return this._request(options, callback);
        },

        // Make a private API request
        _private: function(parameters, callback){
            var options;

            parameters.nonce = nonce();
            options = {
                method: 'POST',
                url: PRIVATE_API_URL,
                form: parameters,
                headers: this._getPrivateHeaders(parameters)
            };

            return this._request(options, callback);
        },


        /////


        // PUBLIC METHODS

        getTickerFor: function(callback,pairs){
            var options = {
                method: 'GET',
                url: PUBLIC_API_URL + '/ticker/'+pairs+'?ignore_invalid=1',
                qs: null
            };

            return this._request(options, callback);
        },

        getBuyOrderBook: function(currencyA, currencyB, callback){
             var options = {
                 method: 'GET',
                 url: PUBLIC_API_URL + '/orders/' + currencyB + '/' + currencyA + '/BUY',
                 qs: null
             };

             return this._request(options, callback);
         },

        getOrderBook: function(currencyA, currencyB, callback){

            var options = {
                method: 'GET',
                url: PUBLIC_API_URL + '/depth/' + joinCurrencies(currencyA, currencyB),
                qs:null

            }

            return this._request(options, callback);
        },

        getTradeHistory: function(currencyA, currencyB, callback){


            return this._public('trades/' + joinCurrencies(currencyA, currencyB), callback);
        },

        /////

        // PRIVATE METHODS , not implemented yet

    };

    return Yobit;
}();
