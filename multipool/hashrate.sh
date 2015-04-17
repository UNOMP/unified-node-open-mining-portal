#!/bin/bash
workercounter=0
arraycounter=0
now="`date +%s`"
TenMins=$((now - 300))
interval=300
modifier=65536
SHAmodifier=4294967296
redis-cli del tmpkey
while read Algo
do
        TotalWorkers=0
        WorkerTotals=0
        unset arrWorkerTotals
        unset arrWorkerCounts
        unset arrWorkerNames
        typeset -A arrWorkerTotals
        typeset -A arrWorkerCounts
        typeset -A arrWorkerNames
        AlgoCounter=0
        workercounter=0
        redis-cli del tmpkey
        while read CoinType
        do
                echo "$CoinType"

                counter=0
                CoinKeyName=$CoinType":hashrate"
                totalhashes=`redis-cli zcard $CoinKeyName`
        if [ -z "$totalhashes" ]
        then
                echo "no hashes" >/dev/null
        else
                while read LineItem
                do
#                       echo "$LineItem"
        counter=$(($counter + 1))
                        AlgoCounter=$(($AlgoCounter + 1))
                        IN=$LineItem
            arrIN=(${IN//:/ })
            preworker=(${arrIN[1]})
            #strip HTML tags out to ensure safe displaying later
            workername=`echo "$preworker," | tr -d '<>,'`
                        echo "$workername"
                        if [[ $workername == "" ]]
                        then
                                echo "ignore worker"
                        else
#                               echo "found line"
                               share=(${arrIN[0]})
#                               echo "a"
                                arrWorkerCounts[$workername]=$((${arrWorkerCounts[$workername]} + 1))
#                               echo "b"
if [[ ${arrWorkerCounts[$workername]} -eq 1 ]]
                                  then
#       echo "c"
                                #must have been this workers first share, so this is a new worker
                                TotalWorkers=$(($TotalWorkers + 1))
#       echo "d"
                workercounter=$(($workercounter + 1))
#       echo "e"
                        arrWorkerNames[$workercounter]=$workername
                                echo "TotalWorkers - $TotalWorkers ~~~ workercounter - $workercounter ~~~ arrWorkerNames -" ${arrWorkerNames[$workercounter]}
                                  else
                                        #this was a duplicate worker, do nothing
                                        echo " " >/dev/null
                                fi
                        if [ -z "${arrWorkerTotals[$workername]}" ]
                        then
                                tempvar=0
                        else
                                tempvar=${arrWorkerTotals[$workername]}
                        fi
#echo "z"
#                       echo "tempvar - $tempvar  ~~ share - $share"
                         arrWorkerTotals[$workername]=`echo "scale=6;$tempvar + $share" | bc -l`
#echo "f"
                        echo "${arrWorkerNames[$workercounter]}"
#echo "g"
#               echo "share-  $share"
#echo "h"
#                echo "Share: $share - arrWorkerTotalsworkername" ${arrWorkerTotals[$workername]}
            fi
                        done< <(redis-cli zrangebyscore $CoinKeyName $TenMins $now)

                        TotalHash=`echo "$TotalHash + $share" | bc -l`
fi
                done< <(redis-cli hkeys Coin_Names_$Algo)
                                if [ $Algo = "sha256" ]
                                then
                                        modifier=4294967296
                                        divisor=1073741824
                                elif [ $Algo = "keccak" ]
                                then
                                        modifier=16777216
                                        divisor=1048576
                                elif [ $Algo = "x11" ]
                                then
                                        modifier=4294967296
                                        divisor=1048576
                                else
                                        modifier=65536
                                        divisor=1048576
                                fi
 
                                TotalHR=`echo "scale=3;$TotalHash * $modifier / $interval / $divisor" | bc`
#                redis-cli zadd Pool_Stats:avgHR:$Algo $now $TotalHR":"$now
                #go over the array of WorkerNames and calculate each workers HR
                                counterB=0
                while [[ $counterB -lt $workercounter ]]
                do
                        counterB=$(($counterB + 1))
                        workerName=${arrWorkerNames[$counterB]}
                        arrWorkerHashRates[$counterB]=`echo "scale=3;${arrWorkerTotals[$workerName]} * $modifier / $interval / $divisor" | bc -l`
                                                workerName=${arrWorkerNames[$counterB]}
                                                rate=${arrWorkerHashRates[$counterB]}
                                                string=$rate":"$now
                                                redis-cli zadd Pool_Stats:WorkerHRs:$Algo:$workerName $now $string
                                                echo "$Algo - $workerName -"$arrWorkerHashRates[$counterB]}
                done
 
 
done< <(redis-cli hkeys Coin_Algos)
