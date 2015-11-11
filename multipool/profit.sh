#!/bin/bash
# Search/replace OPAL with ticker symbol of your desired payout coin. To
# enumerate for additional coins, add a line for EVERY place you see OPAL. Leave things 'BTC' alone. :)
cp -rf /var/lib/redis/6379/dump.rdb ~/unomp/multipool/backup/redis.dump.rdb
AlgoCounter=0
now="$(date +"%s")"
ShiftNumber=$(redis-cli hget Pool_Stats This_Shift)
echo "Shift: $ShiftNumber"
echo
#startstring="Pool_Stats:$ShiftNumber"
starttime=$(redis-cli hget Pool_Stats:"$ShiftNumber" starttime)
echo "Start time: $starttime"
endtime="$now"
length=$(echo "$endtime - $starttime" | bc -l)
redis-cli hset Pool_Stats CurLength $length
dayslength=$(echo "scale=3;$length / 86400" | bc -l)
echo $dayslength
OPALCoinPrice=$(redis-cli hget Exchange_Rates opalcoin)
TotalEarned=0
TotalEarnedOPALCoin=0
redis-cli hset Pool_Stats CurDaysLength "$dayslength"
redis-cli del Pool_Stats:CurrentShift:WorkerBtc
redis-cli del Pool_Stats:CurrentShift:WorkerOPALCoin
redis-cli del Pool_Stats:CurrentShift:Algos
redis-cli del Pool_Stats:CurrentShift:AlgosOPALCoin
redis-cli del Pool_Stats:CurrentShift:Coins
redis-cli del Pool_Stats:CurrentShift:CoinsOPALCoin

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
                coin2btc=$(redis-cli hget Exchange_Rates "$CoinName")
                #echo "$CoinName - $coin2btc"
                workersPerCoin=$(redis-cli hlen "$thiskey")
                if [[ "$workersPerCoin" = 0 ]]
                then
                        echo "do nothing" > /dev/null
                else

                        while read WorkerName
                        do
                                thisBalance=$(redis-cli hget "$thiskey" "$WorkerName")
                                thisEarned=$(echo "scale=8;$thisBalance * $coin2btc" | bc -l)
                                coinTotal=$(echo "scale=8;$coinTotal + $thisEarned" | bc -l)
                                AlgoTotal=$(echo "scale=8;$AlgoTotal + $thisEarned" | bc -l)
                                OPALCoinEarned=$(echo "scale=8;$thisEarned / $OPALCoinPrice" | bc -l)
                                coinTotalOPALCoin=$(echo "scale=8;$coinTotalOPALCoin + $OPALCoinEarned" | bc -l)
                                AlgoTotalOPALCoin=$(echo "scale=8;$AlgoTotalOPALCoin + $OPALCoinEarned" | bc -l)
                               echo "$WorkerName earned $OPALCoinEarned from $CoinName"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:WorkerOPALCoin "Total" "$OPALCoinEarned"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:AlgosOPALCoin "Total" "$OPALCoinEarned"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:Algos "Total" "$thisEarned"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:WorkerOPALCoin "$WorkerName" "$OPALCoinEarned"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "Total" "$thisEarned"
redis-cli hincrbyfloat Pool_Stats:CurrentShift:WorkerBtc "$WorkerName" "$thisEarned"
                        done< <(redis-cli hkeys "$CoinName":balances)
                        redis-cli hset "$logkey" "$CoinName" "$coinTotal"
                        redis-cli hset "$logkeyOPALCoin" "$CoinName" "$coinTotalOPALCoin"
                        #echo "$CoinName: $coinTotal"
fi
        done< <(redis-cli hkeys Coin_Names_"$line")
        redis-cli hset "$logkey2" "$line" "$AlgoTotal"
        redis-cli hset "$logkey2OPALCoin" "$line" "$AlgoTotalOPALCoin"
TotalEarned=$(echo "scale=8;$TotalEarned + $AlgoTotal" | bc -l)
TotalEarnedOPALCoin=$(echo "scale=8;$TotalEarnedOPALCoin + $AlgoTotalOPALCoin" | bc -l)

done< <(redis-cli hkeys Coin_Algos)

# END CALCULATING COIN PROFITS FOR CURRENT SHIFT

# START CALCULATIN AVERAGE HASHRATES SO FAR THIS SHIFT
echo "Start: $starttime End: $endtime"
        AlgoCounter=0
        while read Algo
        do
                AlgoCounter=$(($AlgoCounter + 1))
                if [ $Algo = "sha256" ]
                then
                        Algo="sha"
                fi
                AlgoHRTotal=0
                counter=0
                loopstring="Pool_Stats:AvgHRs:"$Algo
                while read HR
                do
                        IN=$HR
                        arrIN=(${IN//:/ })
                        amt=${arrIN[0]}
                        counter=`echo "$counter + 1" | bc`
                        AlgoHRTotal=`echo "$AlgoHRTotal + $amt" | bc -l`
               done< <(redis-cli zrangebyscore $loopstring $starttime $endtime)

                if [ $Algo = "sha" ]
                then
                        Algo="sha256"
                fi
                thisalgoAVG=`echo "scale=8;$AlgoHRTotal / $counter" |  bc -l`
                string="average_"$Algo
                redis-cli hset Pool_Stats:CurrentShift $string $thisalgoAVG
                string3="Pool_Stats:CurrentShift:Algos"
                thisalgoEarned=`redis-cli hget $string3 $Algo`
		echo "thisalgoEarned: $thisalgoEarned"
		echo "dayslength: $dayslength"
                thisalgoP=`echo "scale=8;$thisalgoEarned / $thisalgoAVG / $dayslength" | bc -l`
                string2="Profitability_$Algo"
                redis-cli hset Pool_Stats:CurrentShift $string2 $thisalgoP
                if [ $Algo = "keccak" ]
                then
                        thisalgoP=`echo "scale=8;$thisalgoP * 500" | bc -l`
                elif [ $Algo = "sha256" ]
                then
                        thisalgoP=`echo "scale=8;$thisalgoP * 1000" | bc -l`
                elif [ $Algo = "x11" ]
                then
                        thisalgoP=`echo "scale=8;$thisalgoP * 1" | bc -l`
                else
                        echo "done" >/dev/null
                fi
                if [ -z "$thisalgoP" ]
                then
                        thisalgoP=0
                fi

                ProArr[$AlgoCounter]=$thisalgoP
                NameArr[$AlgoCounter]=$Algo
                thisShift=$(redis-cli hget Pool_Stats This_Shift)
                redis-cli hset Pool_Stats:CurrentShift $string2 $thisalgoP
                redis-cli hset Pool_Stats:$thisShift $string2 $thisalgoP
                echo "For Current Shift Algo $Algo had an average of $thisalgoAVG - profitability was $thisalgoP"
        done< <(redis-cli hkeys Coin_Algos)

                profitstring=${ProArr[1]}":"${ProArr[2]}":"${ProArr[3]}":"${ProArr[4]}":"${ProArr[5]}
                stringnames=${NameArr[1]}":"${NameArr[2]}":"${NameArr[3]}":"${NameArr[4]}":"${NameArr[5]}
redis-cli hset Pool_Stats:CurrentShift:Profitability $now $profitstring
redis-cli hset Pool_Stats:CurrentShift NameString $stringnames

redis-cli bgsave
