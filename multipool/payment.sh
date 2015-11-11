#!/bin/bash
# Search/replace OPAL and POT with ticker symbol of your desired payout coin. To
# enumerate for additional coins, looks for the commented blocks and copy/paste
# the information and change ticker as necessary. Leave things 'BTC' alone. :)

#!/bin/bash
# START CALCULATING AVERAGE HASHRATES SO FAR THIS SHIFT
now="$(date +"%s")"
ShiftNumber=$(redis-cli hget Pool_Stats This_Shift)
starttime=$(redis-cli hget Pool_Stats:"$ShiftNumber" starttime)
endtime="$now"
length=$(echo "$endtime - $starttime" | bc -l)
dayslength=$(echo "scale=3;$length / 86400" | bc -l)
thisShift=$(redis-cli hget Pool_Stats This_Shift)
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
                thisalgoAVG=`echo "scale=8;$AlgoHRTotal / $counter" |  bc -l`> /dev/null
                string="average_"$Algo
                redis-cli hset Pool_Stats:CurrentShift $string $thisalgoAVG> /dev/null
                redis-cli hset Pool_Stats:$thisShift $string $thisalgoAVG> /dev/null
                string3="Pool_Stats:CurrentShift:Algos"
                thisalgoEarned=`redis-cli hget $string3 $Algo`
                echo "thisalgoEarned: $thisalgoEarned"
                echo "dayslength: $dayslength"
                thisalgoP=`echo "scale=8;$thisalgoEarned / $thisalgoAVG / $dayslength" | bc -l`
                string2="Profitability_$Algo"
                if [ -z "$thisalgoP" ]
                then
                        thisalgoP=0
                fi
                if [ $thisalgoP = 0 ]
                then
                        echo "do nothing" > /dev/null
                else
                if [ $Algo = "sha256" ]
                then
                        thisalgoP=`echo "scale=8;$thisalgoP * 1000" | bc -l`> /dev/null
                elif [ $Algo = "x11" ]
                then
                        thisalgoP=`echo "scale=8;$thisalgoP * 1" | bc -l`> /dev/null
                else
                        echo "done" >/dev/null
                fi
                ProArr[$AlgoCounter]=$thisalgoP
                NameArr[$AlgoCounter]=$Algo
                redis-cli hset Pool_Stats:CurrentShift $string2 $thisalgoP
                redis-cli hset Pool_Stats:$thisShift $string2 $thisalgoP
		redis-cli hset API $Algo 0$thisalgoP
               fi
                echo "For Current Shift Algo $Algo had an average of $thisalgoAVG - profitability was $thisalgoP"
done< <(redis-cli hkeys Coin_Algos)
redis-cli hget API sha256 > ~/unomp/website/static/sha256_profit.txt
redis-cli hget API scrypt > ~/unomp/website/static/scrypt_profit.txt
redis-cli hget API x11 > ~/unomp/website/static/x11_profit.txt

# Change to your path variables throughout, hoping to add up front global vars
cp ~/unomp/multipool/alerts/payouts.log ~/unomp/multipool/alerts/old_payouts.log
rm ~/unomp/multipool/alerts/payouts.log

counter=0
redis-cli   del Pool_Stats:CurrentShift:Coins
redis-cli   del Pool_Stats:CurrentShift:CoinsOPALCoin
redis-cli   del Pool_Stats:CurrentShift:CoinsPOTCoin
now="$(date +"%s")"
thisShift=$(redis-cli   hget Pool_Stats This_Shift)
ShiftStart=$(redis-cli   hget Pool_Stats:"$thisShift" starttime)
OPALPrice=$(redis-cli   hget Exchange_Rates opalcoin)
POTPrice=$(redis-cli   hget Exchange_Rates potcoin)
TotalEarned=0
TotalEarnedOPAL=0
TotalEarnedPOT=0

# loop through algos
while read line
    do
        AlgoTotal=0
        AlgoTotalOPAL=0
        AlgoTotalPOT=0
        logkey2="Pool_Stats:"$thisShift":Algos"
        logkey2OPAL="Pool_Stats:"$thisShift":AlgosOPALCoin"
        logkey2POT="Pool_Stats:"$thisShift":AlgosPOTCoin"
    echo "LOGKEY2: $logkey2"

        # loop through each coin for that algo
        while read CoinName
            do
                coinTotal=0
                coinTotalOPAL=0
                coinTotalPOT=0
                thiskey=$CoinName":balances"
                logkey="Pool_Stats:"$thisShift":Coins"
                logkeyOPAL="Pool_Stats:"$thisShift":CoinsOPALCoin"
                logkeyPOT="Pool_Stats:"$thisShift":CoinsPOTCoin"
                #Determine price for Coin
                coin2btc=`redis-cli   hget Exchange_Rates $CoinName`
                echo "$CoinName - $coin2btc"
                workersPerCoin=`redis-cli   hlen $thiskey`
                if [ $workersPerCoin = 0 ]
                then
                    echo "do nothing" > /dev/null
                else

                    while read WorkerName
                        do
                        #copy from here
                                echo    $WorkerName | grep ^o
                            if [ $? -eq 0 ]
                            then
                                thisBalance=$(redis-cli   hget $thiskey $WorkerName)
                                thisEarned=$(echo "scale=8;$thisBalance * $coin2btc" | bc -l)
                                coinTotal=$(echo "scale=8;$coinTotal + $thisEarned" | bc -l)
                                AlgoTotal=$(echo "scale=8;$AlgoTotal + $thisEarned" | bc -l)
                                OPALEarned=$(echo "scale=8;$thisEarned / $OPALPrice" | bc -l)
                                coinTotalOPAL=$(echo "scale=8;$coinTotalOPAL + $OPALEarned" | bc -l)
                                AlgoTotalOPAL=$(echo "scale=8;$AlgoTotalOPAL + $OPALEarned" | bc -l)
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRound "$WorkerName" "$OPALEarned"
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRoundOPAL "Total" "$OPALEarned"
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRoundOPAL "$WorkerName" "$OPALEarned"
                                redis-cli   hincrbyfloat Worker_Stats:TotalOPALPaid "Total" "$OPALEarned"
                            else
                            # to here and change all 'OPAL' to your desired ticker/coin. add a 'fi' at the next #
                                echo    $WorkerName | grep ^P
                            if [ $? -eq 0 ]
                            then
                                thisBalance=$(redis-cli   hget $thiskey $WorkerName)
                                thisEarned=$(echo "scale=8;$thisBalance * $coin2btc" | bc -l)
                                coinTotal=$(echo "scale=8;$coinTotal + $thisEarned" | bc -l)
                                AlgoTotal=$(echo "scale=8;$AlgoTotal + $thisEarned" | bc -l)
                                POTEarned=$(echo "scale=8;$thisEarned / $POTPrice" | bc -l)
                                coinTotalPOT=$(echo "scale=8;$coinTotalPOT + $POTEarned" | bc -l)
                                AlgoTotalPOT=$(echo "scale=8;$AlgoTotalPOT + $POTEarned" | bc -l)
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRound "$WorkerName" "$POTEarned"
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRoundPOT "Total" "$POTEarned"
                                redis-cli   hincrbyfloat Pool_Stats:CurrentRoundPOT "$WorkerName" "$POTEarned"
                                redis-cli   hincrbyfloat Worker_Stats:TotalPOTPaid "Total" "$POTEarned"
                            fi
                            fi
                            # add a fi here if you add MORE coins. if not, these will suffice for 2 coins. 
                    done< <(redis-cli   hkeys "$CoinName":balances)
                        redis-cli   hset "$logkey" "$CoinName" "$coinTotal"
                        redis-cli   hset "$logkeyOPAL" "$CoinName" "$coinTotalOPAL"
                        redis-cli   hset "$logkeyPOT" "$CoinName" "$coinTotalPOT"
                        echo "$CoinName: $coinTotal"
                fi
        done< <(redis-cli   hkeys Coin_Names_"$line")
            TotalEarned=$(echo "scale=8;$TotalEarned + $AlgoTotal" | bc -l)
            TotalEarnedOPAL=$(echo "scale=8;$TotalEarnedOPAL + $AlgoTotalOPAL" | bc -l)
            TotalEarnedPOT=$(echo "scale=8;$TotalEarnedPOT + $AlgoTotalPOT" | bc -l)

done< <(redis-cli   hkeys Coin_Algos)
    redis-cli   hset Pool_Stats:"$thisShift" Earned_BTC "$TotalEarned"
    redis-cli   hset Pool_Stats:"$thisShift" Earned_OPAL "$TotalEarnedOPAL"
    redis-cli   hset Pool_Stats:"$thisShift" Earned_POT "$TotalEarnedPOT"

echo "Total Earned: $TotalEarned"
redis-cli   hset Pool_Stats:"$thisShift" endtime "$now"
nextShift=$(($thisShift + 1))
redis-cli   hincrby Pool_Stats This_Shift 1
echo "$thisShift" >> /home/an/unomp/multipool/alerts/Shifts
redis-cli   hset Pool_Stats:"$nextShift" starttime "$now"
echo "Shift change switching from $thisShift to $nextShift at $now" >> ~/unomp/multipool/alerts/ShiftChangeErrorCheckerReport

######STILL NEEDS TO BE CHANGED FOR EXTRA COINS#####
while read WorkerName
    do
            echo    $WorkerName | grep ^P
        if [ $? -eq 0 ]
        then
            echo "ITS POT FOR $WorkerName"
            PrevBalance=$(redis-cli   zscore Pool_Stats:Balances "$WorkerName")
        if [[ $PrevBalance == "" ]]
        then
            PrevBalance=0
        fi
            thisBalance=$(redis-cli   hget Pool_Stats:CurrentRound "$WorkerName")
            TotalBalance=$(echo "scale=8;$PrevBalance + $thisBalance" | bc -l) >/dev/null
            echo "$WorkerName" "$TotalBalance" >> /home/an/unomp/multipool/alerts/debug-payouts-balance
            echo "$WorkerName $TotalBalance - was $PrevBalance plus today's $thisBalance" >> ~/unomp/multipool/alerts/ShiftChangeErrorCheckerReport
            redis-cli   zadd Pool_Stats:Balances "$TotalBalance" "$WorkerName"
            redis-cli   hset Worker_Stats:Earnings:"$WorkerName" "$thisShift" "$thisBalance"
            redis-cli   hincrbyfloat Worker_Stats:TotalEarned "$WorkerName" "$thisBalance"
        else
            echo    $WorkerName | grep ^o
        if [ $? -eq 0 ]
        then
            echo "ITS OPAL FOR $WorkerName"
            PrevBalance=$(redis-cli   zscore Pool_Stats:Balances "$WorkerName")
        if [[ $PrevBalance == "" ]]
        then
            PrevBalance=0
        fi
            thisBalance=$(redis-cli   hget Pool_Stats:CurrentRound "$WorkerName")
            TotalBalance=$(echo "scale=8;$PrevBalance + $thisBalance" | bc -l) >/dev/null
            echo "$WorkerName" "$TotalBalance" >> /home/an/unomp/multipool/alerts/debug-payouts-balance
            echo "$WorkerName $TotalBalance - was $PrevBalance plus today's $thisBalance" >> ~/unomp/multipool/alerts/ShiftChangeErrorCheckerReport
            redis-cli   zadd Pool_Stats:Balances "$TotalBalance" "$WorkerName"
            redis-cli   hset Worker_Stats:Earnings:"$WorkerName" "$thisShift" "$thisBalance"
            redis-cli   hincrbyfloat Worker_Stats:TotalEarned "$WorkerName" "$thisBalance"
        else
            echo CANT FIND ADDRESS
        fi
	fi
    echo "$WorkerName" "$TotalBalance"
    redis-cli   zadd Pool_Stats:Balances "$TotalBalance" "$WorkerName"
    redis-cli   hset Worker_Stats:Earnings:"$WorkerName" "$thisShift" "$thisBalance"
    redis-cli   hincrbyfloat Worker_Stats:TotalEarned "$WorkerName" "$thisBalance"
done< <(redis-cli   hkeys Pool_Stats:CurrentRound)
    echo "Done adding coins, clearing balances for shift $thisShift at $now." >> ~/unomp/multipool/alerts/ShiftChangeLog.log

######STILL NEEDS TO BE CHANGED FOR EXTRA COINS#####

# Save the total BTC/OPAL earned for each shift into a historical key for auditing purposes.
echo "Done adding coins, Saving round for historical purposes"
redis-cli   rename Pool_Stats:CurrentRound Pool_Stats:"$thisShift":Shift
redis-cli   rename Pool_Stats:CurrentRoundOPAL Pool_Stats:"$thisShift":ShiftOPAL
redis-cli   rename Pool_Stats:CurrentRoundPOT Pool_Stats:"$thisShift":ShiftPOT

redis-cli   rename Pool_Stats:CurrentShift:Algos Pool_Stats:"$thisShift":Algos
redis-cli   rename Pool_Stats:CurrentShift:AlgosOPALCoin Pool_Stats:"$thisShift":AlgosOPALCoin
redis-cli   rename Pool_Stats:CurrentShift:AlgosPOTCoin Pool_Stats:"$thisShift":AlgosPOTCoin


echo "Saving coin balances for historical purposes"
#for every coin on the pool....
while read Coin_Names2
    do
    #Save the old balances key +shares and blocks for every coin into a historical key.
        redis-cli   rename $Coin_Names2:balances Prev:$thisShift:$Coin_Names2:balances
        redis-cli   rename $Coin_Names2:blocksKicked Prev:$thisShift:$Coin_Names2:blocksKicked
        redis-cli   rename $Coin_Names2:blocksConfirmed Prev:$thisShift:$Coin_Names2:blocksConfirmed
        redis-cli   rename $Coin_Names2:blocksOrphaned Prev:$thisShift:$Coin_Names2:blocksOrphaned
        redis-cli   rename $Coin_Names2:blocksPaid Prev:$thisShift:$Coin_Names2:blocksPaid
        redis-cli   rename $Coin_Names2:stats Prev:$thisShift:$Coin_Names2:stats
        # This loop will move every block from the blocksConfirmed keys into the blocksPaid keys. This means only blocksConfirmed are unpaid.
        while read PaidLine
            do
                redis-cli   sadd "$Coin_Names2":"blocksPaid" "$PaidLine"
                redis-cli   srem "$Coin_Names2":"blocksConfirmed" "$PaidLine"
                echo "nothing" > /dev/null
        done< <(redis-cli   smembers "$Coin_Names2":"blocksConfirmed")


done< <(redis-cli   hkeys Coin_Names)
echo "Done saving coin balances in database"
echo "Done script for shift $thisShift at $now" >> ~/unomp/multipool/alerts/ShiftChangeLog.log
echo "Running payouts for shift $thisShift at $now"

btccounter=0
while read PayoutLine
    do
        echo    $PayoutLine | grep ^o
    if [ $? -eq 0 ]
    then
        echo "its OPALcoin for $PayoutLine"
        amount=$(redis-cli   zscore Pool_Stats:Balances "$PayoutLine")
        roundedamount=$(echo "scale=8;$amount / 1" | bc -l)
        echo "$PayoutLine $amount"
        txn=$(opalcoind sendtoaddress "$PayoutLine" "$roundedamount")
    else
        echo    $PayoutLine | grep ^P
    if [ $? -eq 0 ]
    then
        echo "its POTcoin for $PayoutLine"
        amount=$(redis-cli   zscore Pool_Stats:Balances $PayoutLine)
        roundedamount=$(echo "scale=8;$amount / 1" | bc -l)
        echo "$PayoutLine $amount"
        txn=$(potcoind sendtoaddress "$PayoutLine" "$roundedamount")
    else
    # The below is how you can enable workernames. Each address.worker is tracked separately,
    # but paid in the same transaction. This portion strips everything after the '.' and only
    # uses the valid addresses. I (sigwo) am working on the fix for same-starting letter pay-
    # out option and will eventually track all of a single address's workernames on the same
    # page in the GUI. Elitemobb will be working on the GUI part :)
#    echo    $PayoutLine | grep ^P
#    if [ $? -eq 0 ]
#    then
#	echo "its XPYcoin for $PayoutLine"
#	amount=$(redis-cli  zscore Pool_Stats:Balances "$PayoutLine")
#	roundedamount=$(echo "scale=8;$amount / 1" | bc -l)
#	stripPayoutLine=`echo $PayoutLine | sed 's/[.].*//'`
#	echo "$stripPayoutLine $amount"
#	txn=$(paycoind sendtoaddress "$stripPayoutLine" "$roundedamount")
#    else
        echo "CANT FIND ADDRESS"
    fi
    fi
    #fi
if [[ -z "$txn" ]]
then
#log failed payout to txt file.
echo "shiftnumber: $thisShift payment failed! $PayoutLine" >>~/unomp/multipool/alerts/alert.log
echo "payment failed! $PayoutLine"
else
echo "$PayoutLine $amount" >> ~/unomp/multipool/alerts/payouts.log
newtotal=$(echo "scale=8;$amount - $roundedamount" | bc -l) >/dev/null
redis-cli   hincrby Pool_Stats Earning_Log_Entries 1
redis-cli   lpush Worker_Stats:Payouts:"$PayoutLine" "$amount"
redis-cli   hincrbyfloat Worker_Stats:TotalPaid "$PayoutLine" "$amount"
redis-cli   zadd Pool_Stats:Balances 0 $PayoutLine
fi
done< <(redis-cli   zrangebyscore Pool_Stats:Balances 0.001 inf)
sleep 5
thisShift=$(redis-cli   hget Pool_Stats This_Shift)
lastShift=$(echo "$thisShift - 1" | bc -l)

OPAL=$(opalcoind getbalance)
POT=$(potcoind getbalance)

echo POT BALANCE:$POT
echo OPAL BALANCE:$OPAL

redis-cli   hset Pool_Stats:$lastShift "Balance_OPAL" "$OPAL"
redis-cli   hset Pool_Stats:$lastShift "Balance_POT" "$POT"

redis-cli   bgsave

