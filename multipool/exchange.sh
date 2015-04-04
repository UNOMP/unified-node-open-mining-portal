#!/bin/bash
# Example of sending coins to exchange with bash.
# Most have to be fine tuned for the transaction fees.
# You have to use absolute paths to your coin's datadir if stored in a non-default way
# Using the cron entry below you can set the script to run once an hour
# 0 * * * * ~/unomp/exchange >~/unomp/scripts/cronexchange.log 2>&1

echo
echo
DGBbalance=`digibyted --datadir=/media/tba/coin_data/.digibyte getbalance`
DGBBalance=$(echo "$DGBbalance - 1.0" | bc -l)
echo "Digibyte BALANCE: $DGBbalance"
DGBaddress="D8T5m86h1L3GhQWonLqToX9pv2FkQMq9GG"
digibyted  --datadir=/media/tba/coin_data/.digibyte sendtoaddress $DGBaddress $DGBBalance
echo
echo
DGCbalance=`digitalcoind  --datadir=/media/tba/coin_data/.digitalcoin getbalance`
DGCBalance=$(echo "$DGCbalance - 0.1" | bc -l)
echo "Digitalcoin BALANCE: $DGCbalance"
DGCaddress="DBTQk74mbf2Uk8vwY5mPGZJeE98Qr7RQf3"
digitalcoind  --datadir=/media/tba/coin_data/.digitalcoin sendtoaddress $DGCaddress $DGCBalance
echo
echo
WDCbalance=`worldcoind  --datadir=/media/tba/coin_data/.worldcoin getbalance`
WDCBalance=$(echo "$WDCbalance - 0.1" | bc -l)
echo "Worldcoin BALANCE: $WDCbalance"
WDCaddress="WkQDWBnZJ534EfoNeQsp4nekn5YNgpN3jP"
worldcoind  --datadir=/media/tba/coin_data/.worldcoin sendtoaddress $WDCCaddress $WDCBalance
echo
echo
MECbalance=`megacoind  --datadir=/media/tba/coin_data/.megacoin getbalance`
MECBalance=$(echo "$MECbalance - 0.1" | bc -l)
echo "Megacoin BALANCE: $MECbalance"
MECaddress="MFbz2WH3mTPLPinUjoGT8rBEerKtPsuDJp"
megacoind  --datadir=/media/tba/coin_data/.megacoin sendtoaddress $MECaddress $MECBalance
echo
echo
NEOSbalance=`neoscoind  --datadir=/media/tba/coin_data/.neoscoin getbalance`
NEOSBalance=$(echo "$NEOSbalance - 0.1" | bc -l)
echo "Neoscoin BALANCE: $NEOSbalance"
NEOSaddress="NY3v4kbKft7hyzWsH8gyVrMqCgai8mo3qb"
neoscoind  --datadir=/media/tba/coin_data/.neoscoin sendtoaddress $NEOSaddress $NEOSBalance
echo
echo
MYRbalance=`myriadcoind  --datadir=/media/tba/coin_data/.myriadcoin getbalance`
MYRBalance=$(echo "$MYRbalance - 1.0" | bc -l)
echo "Myriadcoin BALANCE: $MYRbalance"
MYRaddress="MSSPhtazdgjWobmAqLg3kZ8cfpZ45vQAeH"
myriadcoind  --datadir=/media/tba/coin_data/.myriadcoin sendtoaddress $MYRaddress $MYRBalance
echo
echo
