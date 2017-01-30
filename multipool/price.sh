#!/bin/bash
# Examples for grabbing prices from exchange orderbooks and setting them into a redis entry called Exchange_Rates
# Using the cron entry below you can set the script to run once every 5 minutes
# [*/5 * * * * ~/unomp/multipool/price.sh >~/unomp/multipool/alerts/cronprice.log 2>&1]

echo "START"
OMC2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-OMC&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
POT2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-POT&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
MONA2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-MONA&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
TIT2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-TIT&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
START2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-START&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
NEOS2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-NEOS&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
MYR2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-MYR&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
OPAL2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-OPAL&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
VPN2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-VPN&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
VRC2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-VRC&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
NXT2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-NXT&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
BTCD2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-BTCD&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
LTC2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-LTC&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
FIBRE2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-FIBRE&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
CANN2BTC=`curl -G 'https://bittrex.com/api/v1.1/public/getorderbook?market=BTC-CANN&type=both&depth=5' | jq -r .result.buy[4].Rate|awk {' printf "%.8f",$1 '}`
NOTE2BTC=`curl -G 'https://poloniex.com/public?command=returnTicker' | jq -r .BTC_NOTE.last`
echo "END"

redis-cli hset Exchange_Rates neoscoin $NEOS2BTC
redis-cli hset Exchange_Rates myriadcoin $MYR2BTC
redis-cli hset Exchange_Rates opalcoin $OPAL2BTC
redis-cli hset Exchange_Rates vpncoin $VPN2BTC
redis-cli hset Exchange_Rates vericoin $VRC2BTC
redis-cli hset Exchange_Rates nxt $NXT2BTC
redis-cli hset Exchange_Rates bitcoindark $BTCD2BTC
redis-cli hset Exchange_Rates litecoin $LTC2BTC
redis-cli hset Exchange_Rates fibre $FIBRE2BTC
redis-cli hset Exchange_Rates cannabiscoin $CANN2BTC
redis-cli hset Exchange_Rates dnotes $NOTE2BTC
redis-cli hset Exchange_Rates startcoin $START2BTC
redis-cli hset Exchange_Rates omnicoin $OMC2BTC
redis-cli hset Exchange_Rates potcoin $POT2BTC
redis-cli hset Exchange_Rates monacoin $MONA2BTC
redis-cli hset Exchange_Rates titcoin $TIT2BTC
