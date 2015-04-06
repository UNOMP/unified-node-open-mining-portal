#!/bin/bash
#examples for grabbing prices from exchange orderbooks and setting them into a redis entry called Exchange_Rates
#using the cron entry below you can set the script to run once every 5 minutes
# [*/5 * * * * ~/unomp/price >~/unomp/scripts/cronprice.log 2>&1]

FUEL2BTC=`curl -G 'http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=460' | jq -r .return.markets.FC2.buyorders[3].price`
DGB2BTC=`curl -G 'http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=167' | jq -r .return.markets.DGB.buyorders[3].price`
DGC2BTC=`curl -G 'http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=26' | jq -r .return.markets.DGC.buyorders[3].price`
WDC2BTC=`curl -G 'http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=14' | jq -r .return.markets.WDC.buyorders[3].price`
MEC2BTC=`curl -G 'http://pubapi.cryptsy.com/api.php?method=singlemarketdata&marketid=45' | jq -r .return.markets.MEC.buyorders[3].price`
NEOS2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-NEOS&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
MYR2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-MYR&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
OPAL2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-OPAL&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
VPN2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-VPN&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
VRC2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-VRC&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
NXT2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-NXT&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
BTCD2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-BTCD&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
LTC2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-LTC&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
FIBRE2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-FIBRE&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`

redis-cli -h 172.16.1.17 hset Exchange_Rates fuelcoin $FUEL2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates digibytecoin $DGB2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates digitalcoin $DGC2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates worldcoin $WDC2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates megacoincoin $MEC2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates neoscoin $NEOS2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates myriadcoin $MYR2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates opalcoin $OPAL2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates vpncoin $VPN2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates vericoin $VRC2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates nxt $NXT2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates bitcoindark $BTCD2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates litecoin $LTC2BTC
redis-cli -h 172.16.1.17 hset Exchange_Rates fibre $FIBRE2BTC
