#!/bin/bash
# Change this to your directory structure. Search/replace OPAL with Tgt. Search/replace redis-cli with redis-cli.

cp ~/unomp/multipool/alerts/payouts.log ~/unomp/multipool/alerts/old_payouts.log
rm ~/unomp/multipool/alerts/payouts.log

counter=0
redis-cli del Pool_Stats:CurrentShift:Coins
redis-cli del Pool_Stats:CurrentShift:CoinsOPALCoin
now="$(date +"%s")"
thisShift=$(redis-cli hget Pool_Stats This_Shift)
ShiftStart=$(redis-cli hget Pool_Stats:"$thisShift" starttime)
OPALPrice=$(redis-cli hget Exchange_Rates opalcoin)
TotalEarned=0
TotalEarnedOPAL=0

#Adding Profitability and AVG hashrate for this shift to API for yesterdays stats
		while read Algo
        	do
thisalgoAVG=$(redis-cli hget Pool_Stats:CurrentShift average_$Algo)
thisalgoPRF=$(redis-cli hget Pool_Stats:CurrentShift Profitability_$Algo)
		redis-cli hset API Average_$Algo $thisalgoAVG
		redis-cli hset API Profitability_$Algo $thisalgoPRF
        	done< <(redis-cli hkeys Coin_Algos)

# loop through algos
while read line
do
        AlgoTotal=0
        AlgoTotalOPAL=0
        logkey2="Pool_Stats:"$thisShift":Algos"
        logkey2OPAL="Pool_Stats:"$thisShift":AlgosOPAL"
	echo "LOGKEY2: $logkey2"

        # loop through each coin for that algo
        while read CoinName
        do
                coinTotal=0
                coinTotalOPAL=0
                thiskey=$CoinName":balances"
                logkey="Pool_Stats:"$thisShift":Coins"
                logkeyOPAL="Pool_Stats:"$thisShift":CoinsOPAL"
                #Determine price for Coin
                coin2btc=`redis-cli hget Exchange_Rates $CoinName`
		echo "$CoinName - $coin2btc"
                workersPerCoin=`redis-cli hlen $thiskey`
                if [ $workersPerCoin = 0 ]
                then
                        echo "do nothing" > /dev/null
                else

                        while read WorkerName
                        do
                                thisBalance=$(redis-cli hget $thiskey $WorkerName)
                                thisEarned=$(echo "scale=8;$thisBalance * $coin2btc" | bc -l)
                                coinTotal=$(echo "scale=8;$coinTotal + $thisEarned" | bc -l)
                                AlgoTotal=$(echo "scale=8;$AlgoTotal + $thisEarned" | bc -l)
                                OPALEarned=$(echo "scale=8;$thisEarned / $OPALPrice" | bc -l)
                                coinTotalOPAL=$(echo "scale=8;$coinTotalOPAL + $OPALEarned" | bc -l)
                                AlgoTotalOPAL=$(echo "scale=8;$AlgoTotalOPAL + $OPALEarned" | bc -l)
                                redis-cli hincrbyfloat Pool_Stats:CurrentRound "Total" "$OPALEarned"
                                redis-cli hincrbyfloat Pool_Stats:CurrentRound "$WorkerName" "$OPALEarned"
                                redis-cli hincrbyfloat Worker_Stats:TotalPaid "Total" "$OPALEarned"
                                echo "$WorkerName earned $thisEarned from $CoinName"
                        done< <(redis-cli hkeys "$CoinName":balances)
                        redis-cli hset "$logkey" "$CoinName" "$coinTotal"
                        redis-cli hset "$logkeyOPAL" "$CoinName" "$coinTotalOPAL"
                        echo "$CoinName: $coinTotal"

                fi
        done< <(redis-cli hkeys Coin_Names_"$line")
TotalEarned=$(echo "scale=8;$TotalEarned + $AlgoTotal" | bc -l)
TotalEarnedOPAL=$(echo "scale=8;$TotalEarnedOPAL + $AlgoTotalOPAL" | bc -l)


done< <(redis-cli hkeys Coin_Algos)
redis-cli hset Pool_Stats:"$thisShift" Earned_BTC "$TotalEarned"
redis-cli hset Pool_Stats:"$thisShift" Earned_OPAL "$TotalEarnedOPAL"

echo "Total Earned: $TotalEarned"

redis-cli hset Pool_Stats:"$thisShift" endtime "$now"
nextShift=$(($thisShift + 1))
redis-cli hincrby Pool_Stats This_Shift 1
echo "$thisShift" >> ~/unomp/multipool/alerts/Shifts
redis-cli hset Pool_Stats:$nextShift starttime "$now"
echo "Printing Earnings report" >> ~/unomp/multipool/alerts/ShiftChangeLog.txt
echo "Shift change switching from $thisShift to $nextShift at $now" >> ~/unomp/multipool/alerts/ShiftChangeErrorCheckerReport

######STILL NEEDS TO BE CHANGED FOR EXTRA COINS#####
while read WorkerName
do
        PrevBalance=$(redis-cli zscore Pool_Stats:Balances "$WorkerName")
        if [[ $PrevBalance == "" ]]
        then
                PrevBalance=0
        fi
        thisBalance=$(redis-cli hget Pool_Stats:CurrentRound "$WorkerName")
        TotalBalance=$(echo "scale=8;$PrevBalance + $thisBalance" | bc -l) >/dev/null
        echo "$WorkerName" "$TotalBalance"
        echo "$WorkerName $TotalBalance - was $PrevBalance plus today's $thisBalance" >> ~/unomp/multipool/alerts/ShiftChangeErrorCheckerReport
        redis-cli zadd Pool_Stats:Balances "$TotalBalance" "$WorkerName"
        redis-cli hset Worker_Stats:Earnings:"$WorkerName" "$thisShift" "$thisBalance"
        redis-cli hincrbyfloat Worker_Stats:TotalEarned "$WorkerName" "$thisBalance"
echo "$WorkerName" "$TotalBalance"
        redis-cli zadd Pool_Stats:Balances "$TotalBalance" "$WorkerName"
        redis-cli hset Worker_Stats:Earnings:"$WorkerName" "$thisShift" "$thisBalance"
        redis-cli hincrbyfloat Worker_Stats:TotalEarned "$WorkerName" "$thisBalance"
done< <(redis-cli hkeys Pool_Stats:CurrentRound)
echo "Done adding coins, clearing balances for shift $thisShift at $now." >> ~/unomp/multipool/alerts/ShiftChangeLog.log
######STILL NEEDS TO BE CHANGED FOR EXTRA COINS#####

# Save the total BTC/OPAL earned for each shift into a historical key for auditing purposes.
echo "Done adding coins, Saving round for historical purposes"
redis-cli rename Pool_Stats:CurrentRound Pool_Stats:"$thisShift":Shift
redis-cli rename Pool_Stats:CurrentRoundOPAL Pool_Stats:"$thisShift":ShiftOPAL
redis-cli rename Pool_Stats:CurrentRoundBTC Pool_Stats:"$thisShift":ShiftBTC

redis-cli rename Pool_Stats:CurrentShift:Algos Pool_Stats:"$thisShift":Algos
redis-cli rename Pool_Stats:CurrentShift:AlgosOPALCoin Pool_Stats:"$thisShift":AlgosOPALCoin

echo "Saving coin balances for historical purposes"
#for every coin on the pool....
while read Coin_Names2
do
        #Save the old balances key +shares and blocks for every coin into a historical key.
        redis-cli rename $Coin_Names2:balances Prev:$thisShift:$Coin_Names2:balances
	redis-cli rename $Coin_Names2:blocksKicked Prev:$thisShift:$Coin_Names2:blocksKicked
	redis-cli rename $Coin_Names2:blocksConfirmed Prev:$thisShift:$Coin_Names2:blocksConfirmed
	redis-cli rename $Coin_Names2:blocksOrphaned Prev:$thisShift:$Coin_Names2:blocksOrphaned
	redis-cli rename $Coin_Names2:blocksPaid Prev:$thisShift:$Coin_Names2:blocksPaid
	redis-cli rename $Coin_Names2:stats Prev:$thisShift:$Coin_Names2:stats

        # This loop will move every block from the blocksConfirmed keys into the blocksPaid keys. This means only blocksConfirmed are unpaid.
        while read PaidLine
        do
                redis-cli sadd "$Coin_Names2":"blocksPaid" "$PaidLine"
                redis-cli srem "$Coin_Names2":"blocksConfirmed" "$PaidLine"
                echo "nothing" > /dev/null
        done< <(redis-cli smembers "$Coin_Names2":"blocksConfirmed")


done< <(redis-cli hkeys Coin_Names)
echo "Done saving coin balances in database"
echo "Done script for shift $thisShift at $now" >> ~/unomp/multipool/alerts/ShiftChangeLog.log
echo "Running payouts for shift $thisShift at $now"
#Calculate workers owed in excesss of 0.01 coins and generate a report of them.
while read PayoutLine
do
        amount=$(redis-cli zscore Pool_Stats:Balances "$PayoutLine")
        roundedamount=$(echo "scale=8;$amount - 1" | bc -l)
        echo "$PayoutLine $roundedamount"
#send all of the payments using the coin daemon
        txn=$(opalcoind --datadir=/media/tba/coin_data/.opalcoin sendtoaddress "$PayoutLine" "$amount")
        if [[ -z "$txn" ]]
        then
	#log failed payout to txt file.
        echo "shiftnumber: $thisShift payment failed! $PayoutLine" >> ~/unomp/multipool/alerts/alert.log
	echo "payment failed! $PayoutLine"
        else
       		echo "$PayoutLine $amount" >> /home/an/unomp/unified/multipool/alerts/payouts.log
                newtotal=$(echo "scale=8;$amount - $roundedamount" | bc -l) >/dev/null
                redis-cli hincrby Pool_Stats Earning_Log_Entries 1
                redis-cli lpush Worker_Stats:Payouts:"$PayoutLine" "$amount"
                redis-cli hincrbyfloat Worker_Stats:TotalPaid "$PayoutLine" "$amount"
                redis-cli zadd Pool_Stats:Balances 0 $PayoutLine
        fi
done< <(redis-cli zrangebyscore Pool_Stats:Balances 1.0 inf)

redis-cli save
