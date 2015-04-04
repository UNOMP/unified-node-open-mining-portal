#!/bin/bash
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
TgtCoinPrice=$(redis-cli -h 172.16.1.17 hget Exchange_Rates opalcoin)
TotalEarned=0
TotalEarnedTgtCoin=0
redis-cli -h 172.16.1.17 hset Pool_Stats CurDaysLength "$dayslength"
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:WorkerBtc
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:WorkerTgtCoin
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:Algos
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:AlgosTgtCoin
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:Coins
redis-cli -h 172.16.1.17 del Pool_Stats:CurrentShift:CoinsTgtCoin

# START CALCULATING COIN PROFIT FOR CURRENT ROUND - THIS ALSO CALCULATES WORKER EARNINGS MID SHIFT.
# PLEASE NOTE ALL COIN NAMES IN COIN_ALGO REDIS KEY MUST MATCH KEY NAMES IN EXCHANGE_RATES KEY CASE-WISE

while read line
do
        AlgoTotal=0
        AlgoTotalTgtCoin=0
        logkey2="Pool_Stats:CurrentShift:Algos"
        logkey2TgtCoin="Pool_Stats:CurrentShift:AlgosTgtCoin"
        # loop through each coin for that algo
        while read CoinName
        do
                coinTotal=0
                coinTotalTgtCoin=0
                thiskey=$CoinName":balances"
                logkey="Pool_Stats:CurrentShift:Coins"
                logkeyTgtCoin="Pool_Stats:CurrentShift:CoinsTgtCoin"
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
                                TgtCoinEarned=$(echo "scale=8;$thisEarned / $TgtCoinPrice" | bc -l)
                                coinTotalTgtCoin=$(echo "scale=8;$coinTotalTgtCoin + $TgtCoinEarned" | bc -l)
                                AlgoTotalTgtCoin=$(echo "scale=8;$AlgoTotalTgtCoin + $TgtCoinEarned" | bc -l)
                               echo "$WorkerName earned $TgtCoinEarned from $CoinName"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerTgtCoin "Total" "$TgtCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:AlgosTgtCoin "Total" "$TgtCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:Algos "Total" "$thisEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerTgtCoin "$WorkerName" "$TgtCoinEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "Total" "$thisEarned"
redis-cli -h 172.16.1.17 hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "$WorkerName" "$thisEarned"
                        done< <(redis-cli -h 172.16.1.17 hkeys "$CoinName":balances)
                        redis-cli -h 172.16.1.17 hset "$logkey" "$CoinName" "$coinTotal"
                        redis-cli -h 172.16.1.17 hset "$logkeyTgtCoin" "$CoinName" "$coinTotalTgtCoin"
                        #echo "$CoinName: $coinTotal"
fi
        done< <(redis-cli -h 172.16.1.17 hkeys Coin_Names_"$line")
        redis-cli -h 172.16.1.17 hset "$logkey2" "$line" "$AlgoTotal"
        redis-cli -h 172.16.1.17 hset "$logkey2TgtCoin" "$line" "$AlgoTotalTgtCoin"
TotalEarned=$(echo "scale=8;$TotalEarned + $AlgoTotal" | bc -l)
TotalEarnedTgtCoin=$(echo "scale=8;$TotalEarnedTgtCoin + $AlgoTotalTgtCoin" | bc -l)

done< <(redis-cli -h 172.16.1.17 hkeys Coin_Algos)

# END CALCULATING COIN PROFITS FOR CURRENT SHIFT

redis-cli -h 172.16.1.17 save

