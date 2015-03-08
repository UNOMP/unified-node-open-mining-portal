var redis = require('redis');
var Stratum = require('merged-pooler');



/*
This module deals with handling shares when in internal payment processing mode. It connects to a redis
database and inserts shares with the database structure of:

key: coin_name + ':' + block_height
value: a hash with..
        key:

 */



module.exports = function(logger, poolConfig){

    var redisConfig = poolConfig.redis;
    var coin = poolConfig.coin.name;


    var forkId = process.env.forkId;
    var logSystem = 'Pool';
    var logComponent = coin;
    var logSubCat = 'Thread ' + (parseInt(forkId) + 1);

    var connection = redis.createClient(redisConfig.port, redisConfig.host);
    // redis auth if needed
     connection.auth(redisConfig.password);
     connection.select(redisConfig.db);

    connection.on('ready', function(){
        logger.debug(logSystem, logComponent, logSubCat, 'Share processing setup with redis (' + redisConfig.host +
            ':' + redisConfig.port  + ')');
    });
    connection.on('error', function(err){
        logger.error(logSystem, logComponent, logSubCat, 'Redis client had an error: ' + JSON.stringify(err))
    });
    connection.on('end', function(){
        logger.error(logSystem, logComponent, logSubCat, 'Connection to redis database as been ended');
    });

    connection.info(function(error, response){
        if (error){
            logger.error(logSystem, logComponent, logSubCat, 'Redis version check failed');
            return;
        }
        var parts = response.split('\r\n');
        var version;
        var versionString;
        for (var i = 0; i < parts.length; i++){
            if (parts[i].indexOf(':') !== -1){
                var valParts = parts[i].split(':');
                if (valParts[0] === 'redis_version'){
                    versionString = valParts[1];
                    version = parseFloat(versionString);
                    break;
                }
            }
        }
        if (!version){
            logger.error(logSystem, logComponent, logSubCat, 'Could not detect redis version - but be super old or broken');
        }
        else if (version < 2.6){
            logger.error(logSystem, logComponent, logSubCat, "You're using redis version " + versionString + " the minimum required version is 2.6. Follow the damn usage instructions...");
        }
    });


    this.handleShare = function(isValidShare, isValidBlock, shareData){

        var redisCommands = [];
	myAuxes = poolConfig.auxes	
	shareData.worker = shareData.worker.replace(/([\-_.!~*'()].*)/g, '').replace(/\s+/g, ''); // strip any extra strings from worker name.

	for (var i=0; i < myAuxes.length; i++)
	{
		AuxCoin = myAuxes[i].coin.name;

		if (isValidShare){
         	   redisCommands.push(['hincrbyfloat', AuxCoin + ':shares:roundCurrent', shareData.worker, shareData.difficulty]);
         	   redisCommands.push(['hincrby', AuxCoin + ':stats', 'validShares', 1]);
        	
        	} else {
            	  redisCommands.push(['hincrby', AuxCoin + ':stats', 'invalidShares', 1]);
        	}

	        /* Stores share diff, worker, and unique value with a score that is the timestamp. Unique value ensures it
	           doesn't overwrite an existing entry, and timestamp as score lets us query shares from last X minutes to
	           generate hashrate for each worker and pool. */
	        var dateNow = Date.now();
	        var hashrateData = [ isValidShare ? shareData.difficulty : -shareData.difficulty, shareData.worker, dateNow];
	        redisCommands.push(['zadd', AuxCoin + ':hashrate', dateNow / 1000 | 0, hashrateData.join(':')]);

	        if (isValidBlock){
	            redisCommands.push(['rename', AuxCoin + ':shares:roundCurrent', coin + ':shares:round' + shareData.height]);
	            redisCommands.push(['sadd', AuxCoin + ':blocksPending', [shareData.blockHash, shareData.txHash, shareData.height].join(':')]);
	            redisCommands.push(['hincrby', AuxCoin + ':stats', 'validBlocks', 1]);
	   	} else if (shareData.blockHash){
            	    redisCommands.push(['hincrby', AuxCoin + ':stats', 'invalidBlocks', 1]);
	        }

        	connection.multi(redisCommands).exec(function(err, replies){
        	    if (err)
        	        logger.error(logSystem, logComponent, logSubCat, 'Error with share processor multi ' + JSON.stringify(err));
        	});
	
	}

        if (isValidShare){
            redisCommands.push(['hincrbyfloat', coin + ':shares:roundCurrent', shareData.worker, shareData.difficulty]);
            redisCommands.push(['hincrby', coin + ':stats', 'validShares', 1]);
        }
        else{
            redisCommands.push(['hincrby', coin + ':stats', 'invalidShares', 1]);
        }
        /* Stores share diff, worker, and unique value with a score that is the timestamp. Unique value ensures it
           doesn't overwrite an existing entry, and timestamp as score lets us query shares from last X minutes to
           generate hashrate for each worker and pool. */
        var dateNow = Date.now();
        var hashrateData = [ isValidShare ? shareData.difficulty : -shareData.difficulty, shareData.worker, dateNow];
        redisCommands.push(['zadd', coin + ':hashrate', dateNow / 1000 | 0, hashrateData.join(':')]);

        if (isValidBlock){
            redisCommands.push(['rename', coin + ':shares:roundCurrent', coin + ':shares:round' + shareData.height]);
            redisCommands.push(['sadd', coin + ':blocksPending', [shareData.blockHash, shareData.txHash, shareData.height].join(':')]);
            redisCommands.push(['hincrby', coin + ':stats', 'validBlocks', 1]);
        }
        else if (shareData.blockHash){
            redisCommands.push(['hincrby', coin + ':stats', 'invalidBlocks', 1]);
        }

        connection.multi(redisCommands).exec(function(err, replies){
            if (err)
                logger.error(logSystem, logComponent, logSubCat, 'Error with share processor multi ' + JSON.stringify(err));
        });


    };

};

