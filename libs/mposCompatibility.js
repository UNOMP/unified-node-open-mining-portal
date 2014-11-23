var mysql = require('mysql');
var cluster = require('cluster');
var rpcClient = require('bitcoin');

module.exports = function(logger, poolConfig){
    var mposConfig = poolConfig.mposMode;
    var coin = poolConfig.coin.name;

    var connection = mysql.createPool({
        host: mposConfig.host,
        port: mposConfig.port,
        user: mposConfig.user,
        password: mposConfig.password,
        database: mposConfig.database
    });


    var logIdentify = 'MySQL';
    var logComponent = coin;



    this.handleAuth = function(workerName, password, authCallback){

        if (poolConfig.validateWorkerUsername !== true && mposConfig.autoCreateWorker !== true){
            authCallback(true);
            return;
        }

        connection.query(
            'SELECT password FROM workers WHERE name = LOWER(?)',
            [workerName.toLowerCase()],
            function(err, result){
                if (err){
                    logger.error(logIdentify, logComponent, 'Database error when authenticating worker: ' +
                        JSON.stringify(err));
                    authCallback(false);
                }
                else if (!result[0]){
                    if(mposConfig.autoCreateWorker){
                        var account = workerName.split('.')[0];
                        connection.query(
                            'SELECT id,username FROM user WHERE username = LOWER(?)',
                            [account.toLowerCase()],
                            function(err, result){
                                if (err){
                                    logger.error(logIdentify, logComponent, 'Database error when authenticating account: ' +
                                        JSON.stringify(err));
                                    authCallback(false);
                                }else if(!result[0]){
                                    authCallback(false);
                                }else{
                                    connection.query(
                                        "INSERT INTO `workers` (`user_id`, `name`, `password`) VALUES (?, ?, ?);",
                                        [result[0].id,workerName.toLowerCase(),password],
                                        function(err, result){
                                            if (err){
                                                logger.error(logIdentify, logComponent, 'Database error when insert worker: ' +
                                                    JSON.stringify(err));
                                                authCallback(false);
                                            }else {
                                                authCallback(true);
                                            }
                                        })
                                }
                            }
                        );
                    }
                    else{
                        authCallback(false);
                    }
                }
                else if (mposConfig.checkPassword &&  result[0].password !== password)
                    authCallback(false);
                else
                    authCallback(true);
            }
        );

    };

    this.getBlocks = function(client) {
	return client.getInfo()
    }
    this.handleShare = function(isValidShare, isValidBlock, shareData){
	myAuxes = poolConfig.auxes;
	var coinds = [];

        for (var i=0; i < myAuxes.length; i++)
        {  
	   coinds[i] = rpcClient.Client({
  		host: myAuxes[i].daemons.host,
  		port: myAuxes[i].daemons.port,
  		user: myAuxes[i].daemons.user,
  		pass: myAuxes[i].daemons.password,
	   });
	   console.log(coinds[0][i]);
    	   dbData = [
                shareData.worker,
                shareData.ip,
                isValidShare ? 'Y' : 'N',
                isValidBlock ? 'Y' : 'N',
                typeof(shareData.error) === 'undefined' ? null : shareData.error,
                shareData.blockHash ? shareData.blockHash : (shareData.blockHashInvalid ? shareData.blockHashInvalid : ''),
                shareData.difficulty * (poolConfig.coin.mposDiffMultiplier || 1),
		myAuxes[i].coin.symbol,
           ];
           connection.query(
	     	'INSERT INTO `shares` SET time = NOW(), user = ?, ip = ?, oresult = ?, uresult = ?, reason = ?, solution = ?, difficulty = ?, coin = ?, blkheight = ?',
              	dbData,
              	function(err, result) {
                if (err)
               	     logger.error(logIdentify, logComponent, 'Insert error when adding share: ' + JSON.stringify(err));
               	else
                    logger.debug(logIdentify, logComponent, 'Share inserted');
		});
	}
    };

    this.handleDifficultyUpdate = function(workerName, diff){

        connection.query(
            'UPDATE `pool_worker` SET `difficulty` = ' + diff + ' WHERE `username` = ' + connection.escape(workerName),
            function(err, result){
                if (err)
                    logger.error(logIdentify, logComponent, 'Error when updating worker diff: ' +
                        JSON.stringify(err));
                else if (result.affectedRows === 0){
                    connection.query('INSERT INTO `pool_worker` SET ?', {username: workerName, difficulty: diff});
                }
                else
                    console.log('Updated difficulty successfully', result);
            }
        );
    };


};
