[![Build Status](https://travis-ci.org/UNOMP/unified-node-open-mining-portal.png?branch=master)](https://travis-ci.org/UNOMP/unified-node-open-mining-portal)

#### Unified NOMP

This repo will serve as an open source multipool. Multipool capabilities are in alpha testing in this version. This will give the ability to utilize NOMP with merged capabilities but NO merged coin payouts. *ONLY* the main chain coins will payout and calculate correctly at the moment.

This portal is an extremely efficient, highly scalable, all-in-one, easy to setup cryptocurrency mining pool written in Node.js. 
It contains a merged stratum pool server; reward/payment/share processor for multipooling; and an (*in progress*)
responsive user-friendly front-end website featuring mining instructions, in-depth live statistics, and an admin center.

#### Production Usage Notice - Do it with caution!
This is beta software. All of the following are things that can change and break an existing setup: functionality of any feature,
structure of configuration files and structure of redis data. If you use this software in production then *DO NOT* pull new code straight into 
production usage because it can and ~~often~~ will break your setup and require you to tweak things like config files or redis data, among other things.

#### Table of Contents
* [Features](#features)
  * [Attack Mitigation](#attack-mitigation)
  * [Security](#security)
  * [Planned Features](#planned-features)
* [Usage](#usage)
  * [Requirements](#requirements)
  * [Setting Up Coin Daemon](#0-setting-up-coin-daemon)
  * [Downloading & Installing](#1-downloading--installing)
  * [Configuration](#2-configuration)
    * [Portal Config](#portal-config)
    * [Coin Config](#coin-config)
    * [Pool Config](#pool-config)
    * [Setting Up Blocknotify](#optional-recommended-setting-up-blocknotify)
  * [Starting the Portal](#3-start-the-portal)
  * [Upgrading UNOMP](#upgrading)
* [Donations](#donations)
* [Credits](#credits)
* [License](#license)


### Features

* For the pool server it uses the highly efficient [node-merged-pool](//github.com/sigwo/node-merged-pool) module which
supports vardiff, POW & POS, transaction messages, anti-DDoS, IP banning, [several hashing algorithms](//github.com/sigwo/node-merged-pool#hashing-algorithms-supported).

* This implementation is [merged mining capable](https://en.bitcoin.it/wiki/Merged_mining_specification). You may add AUXPoW coins to the main chain configurations. 
At this point, the merged coins do everything EXCEPT display on the site or payout automatically. Shares, blocks, and coinbase transactions complete as planned.

* Multicoin ability - this software was built from the ground up to run with multiple coins simultaneously (which can
have different properties and hashing algorithms). It can be used to create a pool for a single coin or for multiple
coins at once. The pools use clustering to load balance across multiple CPU cores.

* For reward/payment processing, shares are inserted into Redis (a fast NoSQL key/value store). The PROP (proportional)
reward system is used with [Redis Transactions](http://redis.io/topics/transactions) for secure and super speedy payouts.
There is zero risk to the pool operator. Shares from rounds resulting in orphaned blocks will be merged into share in the
current round so that each and every share will be rewarded.

* This portal ~~does not~~ will never have user accounts/logins/registrations. Instead, miners simply use their coin address for stratum authentication. 

* Coin-switching ports using coin-networks and crypto-exchange APIs to detect profitability. 

* Past MPOS functionality is no longer maintained, althought it is working for now.
 
* Basic multipooling features included, but *NOT* enabled by default. You must follow the [README](//github.com/sigwo/unified-node-open-mining-portal/blob/master/multipool/README) in the [multipool](//github.com/sigwo/unified-node-open-mining-portal/blob/master/multipool) folder. More updates *WILL* happen in the multipool options and will stay open source.

#### Attack Mitigation
* Detects and thwarts socket flooding (garbage data sent over socket in order to consume system resources).
* Detects and thwarts zombie miners (botnet infected computers connecting to your server to use up sockets but not sending any shares).
* Detects and thwarts invalid share attacks:
   * UNOMP is not vulnerable to the low difficulty share exploits happening to other pool servers. Other pool server
   software has hardcoded guesstimated max difficulties for new hashing algorithms while UNOMP dynamically generates the
   max difficulty for each algorithm based on values founds in coin source code.
   * IP banning feature which on a configurable threshold will ban an IP for a configurable amount of time if the miner
   submits over a configurable threshold of invalid shares.
* UNOMP is written in Node.js which uses a single thread (async) to handle connections rather than the overhead of one
thread per connection, and clustering is also implemented so all CPU cores are taken advantage of. Result? Fastest stratum available.


#### Security
UNOMP has some implicit security advantages for pool operators and miners:
* Without a registration/login system, non-security-oriented miners reusing passwords across pools is no longer a concern.
* Automated payouts by default and pool profits are sent to another address so pool wallets aren't plump with coins -
giving hackers little reward and keeping your pool from being a target.
* Miners can notice lack of automated payments as a possible early warning sign that an operator is about to run off with their coins.


#### Planned Features

* UNOMP API - Used by the website to display stats and information about the pool(s) on the portal's front-end website. Mostly complete.

* Integration of [addie.cc](http://addie.cc) usernames for multiple payout type without using a public address that may/may not work with the 
coin (still not 100% committed yet, see Feature #7)

* Upgrade codebase to operate in node v 0.12. Multi-hashing module is still throwing fits.

Usage
=====

#### Requirements
* Coin daemon(s) (find the coin's repo and build latest version from source)
* Install node.js (correct procedure below)
* Install npm (correct procedure below)
* [Redis](http://redis.io/) key-value store v2.6+ ([follow these instructions](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-redis))

OPTIONAL: `sudo npm install posix`, but you will have to start the pool `sudo node init.js`

##### Seriously
Those are legitimate requirements. If you use old versions of Node.js or Redis that may come with your system package manager then you will have problems. Follow the linked 
instructions to get the last stable versions.


[**Redis security warning**](http://redis.io/topics/security): be sure firewall access to redis - an easy way is to
include `bind 127.0.0.1` in your `redis.conf` file. Also it's a good idea to learn about and understand software that
you are using - a good place to start with redis is [data persistence](http://redis.io/topics/persistence).

Redis server may require a password, this is done using the requirepass directive in the redis configuration file.
By default config.json contains blank "" - means disabled redis auth, to set any password just put "redispass" in quotes.

#### 0) Setting up coin daemon
Follow the build/install instructions for your coin daemon. Your coin.conf file should end up looking something like this:
```
daemon=1
rpcuser=litecoinrpc
rpcpassword=securepassword
rpcport=19332
```
For redundancy, its recommended to have at least two daemon instances running in case one drops out-of-sync or offline,
all instances will be polled for block/transaction updates and be used for submitting blocks. Creating a backup daemon
involves spawning a daemon using the `-datadir=/backup` command-line argument which creates a new daemon instance with
it's own config directory and coin.conf file. Learn about the daemon, how to use it and how it works if you want to be
a good pool operator. For starters be sure to read:
   * https://en.bitcoin.it/wiki/Running_bitcoind
   * https://en.bitcoin.it/wiki/Data_directory
   * https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_Calls_list
   * https://en.bitcoin.it/wiki/Difficulty

#### 1) Downloading & Installing

Clone the repository and run `npm update` for all the dependencies to be installed:

```bash
sudo apt-get install build-essential libssl-dev npm nodejs nodejs-legacy
curl https://raw.githubusercontent.com/creationix/nvm/v0.16.1/install.sh | sh
source ~/.profile
nvm install 0.10.25
nvm use 0.10.25
git clone https://github.com/UNOMP/unified-node-open-mining-portal.git unomp
cd unomp
npm update
```

#### 2) Configuration

##### Portal config
Inside the `config_example.json` file, ensure the default configuration will work for your environment, then copy the file to `config.json`.

Explanation for each field:
````javascript
{
    /* Specifies the level of log output verbosity. Anything more severe than the level specified
       will also be logged. */
    "logLevel": "debug", //or "warning", "error"
    
    /* By default UNOMP logs to console and gives pretty colors. If you direct that output to a
       log file then disable this feature to avoid nasty characters in your log file. */
    "logColors": true, 


    /* The UNOMP CLI (command-line interface) will listen for commands on this port. For example,
       blocknotify messages are sent to UNOMP through this. */
    "cliPort": 17117,

    /* By default 'forks' is set to "auto" which will spawn one process/fork/worker for each CPU
       core in your system. Each of these workers will run a separate instance of your pool(s),
       and the kernel will load balance miners using these forks. Optionally, the 'forks' field
       can be a number for how many forks will be spawned. */
    "clustering": {
        "enabled": true,
        "forks": "auto"
    },
    
    /* Pool config file will inherit these default values if they are not set. */
    "defaultPoolConfigs": {
    
        /* Poll RPC daemons for new blocks every this many milliseconds. */
        "blockRefreshInterval": 1000,
        
        /* If no new blocks are available for this many seconds update and rebroadcast job. */
        "jobRebroadcastTimeout": 55,
        
        /* Disconnect workers that haven't submitted shares for this many seconds. */
        "connectionTimeout": 600,
        
        /* (For MPOS mode) Store the block hashes for shares that aren't block candidates. */
        "emitInvalidBlockHashes": false,
        
        /* This option will only authenticate miners using an address or mining key. */
        "validateWorkerUsername": true,
        
        /* Enable for client IP addresses to be detected when using a load balancer with TCP
           proxy protocol enabled, such as HAProxy with 'send-proxy' param:
           http://haproxy.1wt.eu/download/1.5/doc/configuration.txt */
        "tcpProxyProtocol": false,
        
        /* If under low-diff share attack we can ban their IP to reduce system/network load. If
           running behind HAProxy be sure to enable 'tcpProxyProtocol', otherwise you'll end up
           banning your own IP address (and therefore all workers). */
        "banning": {
            "enabled": true,
            "time": 600, //How many seconds to ban worker for
            "invalidPercent": 50, //What percent of invalid shares triggers ban
            "checkThreshold": 500, //Perform check when this many shares have been submitted
            "purgeInterval": 300 //Every this many seconds clear out the list of old bans
        },
        
        /* Used for storing share and block submission data and payment processing. */
        "redis": {
            "host": "127.0.0.1",
            "port": 6379,
            "db": 0, /* redis db select, usefull for multi-node cluster replicas */
	    "password": ""  /* "" - no password, or any non blank "redispassword" to enable it */
        }
    },

    /* This is the front-end. Its not finished. When it is finished, this comment will say so. */
    "website": {
        "enabled": true,
        /* If you are using a reverse-proxy like nginx to display the website then set this to
           127.0.0.1 to not expose the port. */
        "host": "0.0.0.0",
        /* Title you want for your site. */
        "siteTitle": "UNOMP Beta",
        "port": 8080,
        /* Used for displaying stratum connection data on the Getting Started page. */
        "stratumHost": "pool.unomp.org",
        "stats": {
            /* Gather stats to broadcast to page viewers and store in redis for historical stats
               every this many seconds. */
            "updateInterval": 15,
            /* How many seconds to hold onto historical stats. Currently set to 24 hours. */
            "historicalRetention": 43200,
            /* How many seconds worth of shares should be gathered to generate hashrate. */
            "hashrateWindow": 300
        },
        /* Not done yet. */
        "adminCenter": {
            "enabled": true,
            "password": "password"
        }
    },

    /* Redis instance of where to store global portal data such as historical stats, proxy states,
       ect.. */
    "redis": {
        "host": "127.0.0.1",
        "port": 6379,
        "db": 0, /* redis db select, usefull for multi-node cluster replicas */
        "password": ""  /* similar "" - no password, or any non blank  "redispassword" to enable it */
    },


    /* With this switching configuration, you can setup ports that accept miners for work based on
       a specific algorithm instead of a specific coin. Miners that connect to these ports are
       automatically switched a coin determined by the server. The default coin is the first
       configured pool for each algorithm and coin switching can be triggered using the
       cli.js script in the scripts folder.  */
       
    "switching": {
        "switch1": {
            "enabled": false,
            "algorithm": "sha256",
            "ports": {
                "3333": {
                    "diff": 10,
                    "varDiff": {
                        "minDiff": 16,
                        "maxDiff": 512,
                        "targetTime": 15,
                        "retargetTime": 90,
                        "variancePercent": 30
                    }
                }
            }
        },
        "switch2": {
            "enabled": false,
            "algorithm": "scrypt",
            "ports": {
                "4444": {
                    "diff": 10,
                    "varDiff": {
                        "minDiff": 16,
                        "maxDiff": 512,
                        "targetTime": 15,
                        "retargetTime": 90,
                        "variancePercent": 30
                    }
                }
            }
        },
        "switch3": {
            "enabled": false,
            "algorithm": "x11",
            "ports": {
                "5555": {
                    "diff": 0.001
                }
            }
        }
    },

    "profitSwitch": {
        "enabled": false,
        "updateInterval": 600,
        "depth": 0.90,
        "usePoloniex": true,
        "useBittrex": true
    }
}
````


##### Coin config
Inside the `coins` directory, ensure a json file exists for your coin. If it does not you will have to create it.
Here is an example of the required fields:
````javascript
{
    "name": "Litecoin",
    "symbol": "LTC",
    "algorithm": "scrypt",

    /* Magic value only required for setting up p2p block notifications. It is found in the daemon
       source code as the pchMessageStart variable.
       For example, litecoin mainnet magic: http://git.io/Bi8YFw
       And for litecoin testnet magic: http://git.io/NXBYJA */
    "peerMagic": "fbc0b6db", //optional
    "peerMagicTestnet": "fcc1b7dc" //optional

    //"txMessages": false, //options - defaults to false

    //"mposDiffMultiplier": 256, //options - only for x11 coins in mpos mode
}
````

For additional documentation how to configure coins and their different algorithms
see [these instructions](//github.com/sigwo/node-merged-pool#module-usage).


##### Pool config
Take a look at the example json file inside the `pool_configs` directory. Rename it to `yourcoin.json` and change the
example fields to fit your setup.

Description of options:

````javascript
{
    "enabled": true, //Set this to false and a pool will not be created from this config file
    "coin": "litecoin.json", //Reference to coin config file in 'coins' directory
    "auxes": [
        {
            "coin": "viacoin.json",
            "daemons": [
                {
                    "host": "127.0.0.1",
                    "port": 4001,
                    "user": "user",
                    "password": "password"
                }
            ]
        }
    ],
    "address": "mi4iBXbBsydtcc5yFmsff2zCFVX4XG7qJc", //Address to where block rewards are given

    /* Block rewards go to the configured pool wallet address to later be paid out to miners,
       except for a percentage that can go to, for examples, pool operator(s) as pool fees or
       or to donations address. Addresses or hashed public keys can be used. Here is an example
       of rewards going to the main pool op and a pool co-owner. Can also be set for mandatory 
       donation coins like GRE and DMD. */
    "rewardRecipients": {
        "n37vuNFkXfk15uFnGoVyHZ6PYQxppD3QqK": 1.5, //1.5% goes to pool op
        "mirj3LtZxbSTharhtXvotqtJXUY7ki5qfx": 0.5 //0.5% goes to a pool co-owner
    },

    "paymentProcessing": {
        "enabled": true,

        /* Every this many seconds get submitted blocks from redis, use daemon RPC to check
           their confirmation status, if confirmed then get shares from redis that contributed
           to block and send out payments. */
        "paymentInterval": 30,

        /* Minimum number of coins that a miner must earn before sending payment. Typically,
           a higher minimum means less transactions fees (you profit more) but miners see
           payments less frequently (they dislike). Opposite for a lower minimum payment. */
        "minimumPayment": 0.01,

        /* This daemon is used to send out payments. It MUST be for the daemon that owns the
           configured 'address' that receives the block rewards, otherwise the daemon will not
           be able to confirm blocks or send out payments. */
        "daemon": {
            "host": "127.0.0.1",
            "port": 4000,
            "user": "testuser",
            "password": "testpass"
        }
    },

    /* Each pool can have as many ports for your miners to connect to as you wish. Each port can
       be configured to use its own pool difficulty and variable difficulty settings. varDiff is
       optional and will only be used for the ports you configure it for. */
    "ports": {
        "3032": { //A port for your miners to connect to
            "diff": 32, //the pool difficulty for this port

            /* Variable difficulty is a feature that will automatically adjust difficulty for
               individual miners based on their hashrate in order to lower networking overhead */
            "varDiff": {
                "minDiff": 8, //Minimum difficulty
                "maxDiff": 512, //Network difficulty will be used if it is lower than this
                "targetTime": 15, //Try to get 1 share per this many seconds
                "retargetTime": 90, //Check to see if we should retarget every this many seconds
                "variancePercent": 30 //Allow time to very this % from target without retargeting
            }
        },
        "3256": { //Another port for your miners to connect to, this port does not use varDiff
            "diff": 256 //The pool difficulty
        }
    },

    /* More than one daemon instances can be setup in case one drops out-of-sync or dies. */
    "daemons": [
        {   //Main daemon instance
            "host": "127.0.0.1",
            "port": 4000,
            "user": "testuser",
            "password": "testpass"
        }
    ],

    /* This allows the pool to connect to the daemon as a node peer to receive block updates.
       It may be the most efficient way to get block updates (faster than polling, less
       intensive than blocknotify script). It requires the additional field "peerMagic" in
       the coin config. */
    "p2p": {
        "enabled": false,

        /* Host for daemon */
        "host": "127.0.0.1",

        /* Port configured for daemon (this is the actual peer port not RPC port) */
        "port": 19333,

        /* If your coin daemon is new enough (i.e. not a shitcoin) then it will support a p2p
           feature that prevents the daemon from spamming our peer node with unnecessary
           transaction data. Assume its supported but if you have problems try disabling it. */
        "disableTransactions": true
    }
}

````

You can create as many of these pool config files as you want (such as one pool per coin you which to operate).
If you are creating multiple pools, ensure that they have unique stratum ports.

For more information on these configuration options see the [pool module documentation](https://github.com/UNOMP/node-merged-pool#module-usage)



##### [Optional, recommended] Setting up blocknotify
1. In `config.json` set the port and password for `blockNotifyListener`
2. In your daemon conf file set the `blocknotify` command to use:
```
node [path to cli.js] [coin name in config] [block hash symbol]
```
Example: inside `dogecoin.conf` add the line
```
blocknotify=node /home/unomp/scripts/cli.js blocknotify dogecoin %s
```

Alternatively, you can use a more efficient block notify script written in pure C. Build and usage instructions
are commented in [scripts/blocknotify.c](scripts/blocknotify.c).


#### 3) Start the portal

```bash
node init.js
```

###### Optional, highly-recommended enhancements for your awesome new mining pool server setup:
* Use something like [forever](https://github.com/nodejitsu/forever) or [ndt](https://github.com/snailjs/ndt) to keep the node script running
in case the master process crashes.
* Use something like [redis-commander](https://github.com/joeferner/redis-commander) to have a nice GUI
for exploring your redis database.
* Use something like [logrotator](http://www.thegeekstuff.com/2010/07/logrotate-examples/) to rotate log 
output from UNOMP.
* Use [New Relic](http://newrelic.com/) to monitor your UNOMP instance and server performance.


#### Upgrading
When updating UNOMP to the latest code its important to not only `git pull` the latest from this repo, but to also update
the `merged-pooler` and `node-multi-hashing` modules, and any config files that may have been changed.
* Inside your UNOMP directory (where the init.js script is) do `git pull` to get the latest UNOMP code.
* Remove the dependenices by deleting the `node_modules` directory with `rm -r node_modules`.
* Run `npm update` to force updating/reinstalling of the dependencies.
* Compare your `config.json` and `pool_configs/coin.json` configurations to the latest example ones in this repo or the ones in the setup instructions where each config field is explained. You may need to modify or add any new changes.

Donations
---------
Below is my donation address. The original [credits](//github.com/sigwo/unified-node-open-mining-portal/blob/master/CREDITS.md) are listed here because I felt scammy if I totally removed them. They no longer are supporting the current development effort. Please donate to:

* BTC: `19svwpxWAhD4zsfeEnnxExZgnQ46A3mrt3`

Donors (email me to be added):
* [elitemobb from altnuts.com](http://altnuts.com)
* [mike from minerpools.com](https://minerpools.com)
* [gentamicin from themultipool.com](http://themultipool.com)

[Credits](//github.com/sigwo/unified-node-open-mining-portal/blob/master/CREDITS.md)
-------

License
-------
Released under the GNU General Public License v2

http://www.gnu.org/licenses/gpl-2.0.html
