var redis = require('redis');
var async = require('async');
var express = require('express');
var stats = require('./stats.js');
var compress = require('compression');

module.exports = function(logger, portalConfig, poolConfigs){


    var app = express();
    var _this = this;

    var portalStats = this.stats = new stats(logger, portalConfig, poolConfigs);

    this.liveStatConnections = {};

    this.handleApiRequest = function(req, res, next){
        switch(req.params.method){
            case 'stats':
                res.end(portalStats.statsString);
                return;
            // hashgoal addition for better block stats
            case 'getblocksstats':
                portalStats.getBlocksStats(function (data) {
                    res.end(JSON.stringify(data));
                });
                return;
            case 'pool_stats':
                res.writeHead(200, {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'max-age=20',
                    'Connection': 'keep-alive'
                });
                res.end(JSON.stringify(portalStats.statPoolHistory));
                return;
            case 'worker_stats':
                res.writeHead(200, {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'max-age=20',
                    'Connection': 'keep-alive'
                });
                res.end(JSON.stringify(portalStats.statWorkerHistory));
                return;
                case 'algo_stats':
                res.writeHead(200, {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'max-age=20',
                    'Connection': 'keep-alive'
                });
                res.end(JSON.stringify(portalStats.statAlgoHistory));
                return;
            case 'live_stats':
                res.writeHead(200, {
                    'Content-Type': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive'
                });
                res.write('\n');
                var uid = Math.random().toString();
                _this.liveStatConnections[uid] = res;
                req.on("close", function() {
                    delete _this.liveStatConnections[uid];
                });

                return;
            default:
                next();
        }
    };


    this.handleAdminApiRequest = function(req, res, next){
        switch(req.params.method){
            case 'pools': {
                res.end(JSON.stringify({result: poolConfigs}));
                return;
            }
            default:
                next();
        }
    };

};
