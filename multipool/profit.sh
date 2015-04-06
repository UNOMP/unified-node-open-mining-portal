#!/bin/bash
# Change this to your directory structure. Search/replace OPAL with Tgt. Search/replace redis-cli -h 172.16.1.17 with redis-cli.
cp -rf /var/lib/redis/6379/dump.rdb ~/unomp/unified/multipool/backup/redis.dump.rdb
AlgoCounter=0
now="$(date +"%s")"
ShiftNumber=$(redis-cli -h 172.16.1.17 hget Pool_Stats This_Shift)
echo "Shift: $ShiftNumber"
echo
#startstring="Pool_Stats:$ShiftNumber"
starttime=$(redis-cli -h 172.16.1.17 hget Pool_Stats:"$ShiftNumber" starttime)
echo "Start time: $starttime"
endtime="$now"
length=$(echo "$endtime - $starttime" | bc -l)
redis-cli -h 172.16.1.17 hset Pool_Stats CurLength $length
dayslength=$(echo "scale=3;$length / 86400" | bc -l)
echo $dayslength
OPALCoinPrice=$(redis-cli -h 172.16.1.17 hget Exchange_Rates opalcoin)
TotalEarned=0
TotalEarnedOPALCoin=0
redis-cli -h 172.16.1.17 hset Pool_Stats CurDaysLength "$dayslength"
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:WorkerBtc
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:WorkerOPALCoin
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:Algos
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:AlgosOPALCoin
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:Coins
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:CoinsOPALCoin

# START CALCULATING COIN PROFIT FOR CURRENT ROUND - THIS ALSO CALCULATES WORKER EARNINGS MID SHIFT.
# PLEASE NOTE ALL COIN NAMES IN COIN_ALGO REDIS KEY MUST MATCH KEY NAMES IN EXCHANGE_RATES KEY CASE-WISE

while read line
do
        AlgoTotal=0
        AlgoTotalOPALCoin=0
        logkey2="Pool_Stats:CurrentShift:Algos"
        logkey2OPALCoin="Pool_Stats:CurrentShift:AlgosOPALCoin"
        # loop through each coin for that algo
        while read CoinName
        do
                coinTotal=0
                coinTotalOPALCoin=0
                thiskey=$CoinName":balances"
                logkey="Pool_Stats:CurrentShift:Coins"
                logkeyOPALCoin="Pool_Stats:CurrentShift:CoinsOPALCoin"
                # Determine price for Coin 
                coin2btc=$(redis-cli -h 172.16.1.17 hget Exchange_Rates "$CoinName")
                #echo "$CoinName - $coin2btc"
                workersPerCoin=$(redis-cli -h 172.16.1.17 hlen "$thiskey")
                if [[ "$workersPerCoin" = 0 ]]
                then
                        echo "do nothing" > /dev/null
                else

                        while read WorkerName
                        do
                                thisBalance=$(redis-cli -h 172.16.1.17 hget "$thiskey" "$WorkerName")
                                thisEarned=$(echo "scale=8;$thisBalance * $coin2btc" | bc -l)
                                coinTotal=$(echo "scale=8;$coinTotal + $thisEarned" | bc -l)
                                AlgoTotal=$(echo "scale=8;$AlgoTotal + $thisEarned" | bc -l)
                                OPALCoinEarned=$(echo "scale=8;$thisEarned / $OPALCoinPrice" | bc -l)
                                coinTotalOPALCoin=$(echo "scale=8;$coinTotalOPALCoin + $OPALCoinEarned" | bc -l)
                                AlgoTotalOPALCoin=$(echo "scale=8;$AlgoTotalOPALCoin + $OPALCoinEarned" | bc -l)
                               echo "$WorkerName earned $OPALCoinEarned from $CoinName"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerOPALCoin "Total" "$OPALCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:AlgosOPALCoin "Total" "$OPALCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:Algos "Total" "$thisEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerOPALCoin "$WorkerName" "$OPALCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "Total" "$thisEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "$WorkerName" "$thisEarned"
                        done< <(redis-cli -h 172.16.1.17 hkeys "$CoinName":balances)
                        redis-cli -h 172.16.1.17 hset "$logkey" "$CoinName" "$coinTotal"
                        redis-cli -h 172.16.1.17 hset "$logkeyOPALCoin" "$CoinName" "$coinTotalOPALCoin"
                        #echo "$CoinName: $coinTotal"
fi
        done< <(redis-cli -h 172.16.1.17 hkeys Coin_Names_"$line")
        redis-cli -h 172.16.1.17 hset "$logkey2" "$line" "$AlgoTotal"
        redis-cli -h 172.16.1.17 hset "$logkey2OPALCoin" "$line" "$AlgoTotalOPALCoin"
TotalEarned=$(echo "scale=8;$TotalEarned + $AlgoTotal" | bc -l)
TotalEarnedOPALCoin=$(echo "scale=8;$TotalEarnedOPALCoin + $AlgoTotalOPALCoin" | bc -l)

done< <(redis-cli -h 172.16.1.17 hkeys Coin_Algos)

# END CALCULATING COIN PROFITS FOR CURRENT SHIFT

redis-cli -h 172.16.1.17 save

