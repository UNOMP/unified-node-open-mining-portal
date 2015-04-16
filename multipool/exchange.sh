#!/bin/bash
# Example of sending coins to exchange with bash.
# Most have to be fine tuned for the transaction fees.
# You have to use absolute paths to your coin's datadir if stored in a non-default way
# Using the cron entry below you can set the script to run once an hour
# 0 * * * * ~/unomp/exchange >~/unomp/scripts/cronexchange.log 2>&1

echo
echo
DGBbalance=`digibyted --datadir=/media/coin/.digibyte getbalance`
DGBBalance=$(echo "$DGBbalance - 1.0" | bc -l)
echo "Digibyte BALANCE: $DGBbalance"
DGBaddress="D8T5m86h1L3GhQWonLqToX9pv2FkQMq9GG"
digibyted  --datadir=/media/coin/.digibyte sendtoaddress $DGBaddress $DGBBalance
echo
echo
DGCbalance=`digitalcoind  --datadir=/media/coin/.digitalcoin getbalance`
DGCBalance=$(echo "$DGCbalance - 0.1" | bc -l)
echo "Digitalcoin BALANCE: $DGCbalance"
DGCaddress="DBTQk74mbf2Uk8vwY5mPGZJeE98Qr7RQf3"
digitalcoind  --datadir=/media/coin/.digitalcoin sendtoaddress $DGCaddress $DGCBalance
echo
echo
WDCbalance=`worldcoind  --datadir=/media/coin/.worldcoin getbalance`
WDCBalance=$(echo "$WDCbalance - 0.1" | bc -l)
echo "Worldcoin BALANCE: $WDCbalance"
WDCaddress="WkQDWBnZJ534EfoNeQsp4nekn5YNgpN3jP"
worldcoind  --datadir=/media/coin/.worldcoin sendtoaddress $WDCaddress $WDCBalance
echo
echo
MECbalance=`megacoind  --datadir=/media/coin/.megacoin getbalance`
MECBalance=$(echo "$MECbalance - 0.1" | bc -l)
echo "Megacoin BALANCE: $MECbalance"
MECaddress="MFbz2WH3mTPLPinUjoGT8rBEerKtPsuDJp"
megacoind  --datadir=/media/coin/.megacoin sendtoaddress $MECaddress $MECBalance
echo
echo
NEOSbalance=`neoscoind  --datadir=/media/coin/.neoscoin getbalance`
NEOSBalance=$(echo "$NEOSbalance - 0.1" | bc -l)
echo "Neoscoin BALANCE: $NEOSbalance"
NEOSaddress="NY3v4kbKft7hyzWsH8gyVrMqCgai8mo3qb"
neoscoind  --datadir=/media/coin/.neoscoin sendtoaddress $NEOSaddress $NEOSBalance
echo
echo
MYRbalance=`myriadcoind  --datadir=/media/coin/.myriadcoin getbalance`
MYRBalance=$(echo "$MYRbalance - 1.0" | bc -l)
echo "Myriadcoin BALANCE: $MYRbalance"
MYRaddress="MSSPhtazdgjWobmAqLg3kZ8cfpZ45vQAeH"
myriadcoind  --datadir=/media/coin/.myriadcoin sendtoaddress $MYRaddress $MYRBalance
echo
echo
NOTEbalance=`dnotesd  --datadir=/media/coin/.DNotes getbalance`
NOTEBalance=$(echo "$NOTEbalance - 1.0" | bc -l)
echo "Dnotes BALANCE: $NOTEbalance"
NOTEaddress="DiQhSKweYywbnN5nAF9s59GSFchT1Wp2zo"
dnotesd  --datadir=/media/coin/.DNotes sendtoaddress $NOTEaddress $NOTEBalance
echo
echo
STARTbalance=`startcoind  --datadir=/media/coin/.startcoin getbalance`
STARTBalance=$(echo "$STARTbalance - 1.0" | bc -l)
echo "Startcoin BALANCE: $STARTbalance"
STARTaddress="sccgv3e51SNt4gWRwVSE8prebMhdPEfrVW"
startcoind  --datadir=/media/coin/.startcoin sendtoaddress $STARTaddress $STARTBalance
echo
echo
DOGEbalance=`dogecoind  --datadir=/media/coin/.dogecoin getbalance`
DOGEBalance=$(echo "$DOGEbalance - 1.0" | bc -l)
echo "Dogecoin BALANCE: $DOGEbalance"
DOGEaddress="DReaGSVBoKzx9XnNeJiMoDSb7UUVkHmSNc"
dogecoind  --datadir=/media/coin/.dogecoin sendtoaddress $DOGEaddress $DOGEBalance
echo
echo "Syscoin Not Displayed ATM"
#SYSbalance=`syscoind  --datadir=/media/coin/.syscoin getbalance`
#SYSBalance=$(echo "$SYSbalance - 1.0" | bc -l)
#echo "Syscoin BALANCE: $SYSbalance"
#SYSaddress="SiMeWNp57TvGVRSJfFSATUKMTmnibP5zxU"
#syscoind  --datadir=/media/coin/.syscoin sendtoaddress $SYSaddress $SYSBalance
echo
echo
UISbalance=`unitus-cli  --datadir=/media/coin/.unitus getbalance`
UISBalance=$(echo "$UISbalance - 1.0" | bc -l)
echo "Unitus BALANCE: $UISbalance"
UISaddress="UYdWHXPPvJCnoHCC6da6GgVQHwVHyMR5W3"
unitus-cli  --datadir=/media/coin/.unitus sendtoaddress $UISaddress $UISBalance
echo
echo
VIAbalance=`viacoin-cli  --datadir=/media/coin/.viacoin getbalance`
VIABalance=$(echo "$VIAbalance - 0.5" | bc -l)
echo "Viacoin BALANCE: $VIAbalance"
VIAaddress="VwNHRcXm4ehULhGUQ9FY1ProtDW7qhyJL5"
viacoin-cli  --datadir=/media/coin/.viacoin sendtoaddress $VIAaddress $VIABalance
echo
echo
DVCbalance=`devcoind  --datadir=/media/coin/.devcoin getbalance`
DVCBalance=$(echo "$DVCbalance - 1.0" | bc -l)
echo "Devcoin BALANCE: $DVCbalance"
DVCaddress="1D4wcVaZQJun8MrUsQsnABJfSUg8dA7uuz"
devcoind  --datadir=/media/coin/.devcoin sendtoaddress $DVCaddress $DVCBalance
echo
echo
CANNbalance=`cannabiscoind  --datadir=/media/coin/.CannabisCoin getbalance`
CANNBalance=$(echo "$CANNbalance - 1.0" | bc -l)
echo "Cannabiscoin BALANCE: $CANNbalance"
CANNaddress="CPQ1feCZHv94A1LB2Ath14Ut3ckUPvUzLA"
cannabiscoind  --datadir=/media/coin/.CannabisCoin sendtoaddress $CANNaddress $CANNBalance
echo
