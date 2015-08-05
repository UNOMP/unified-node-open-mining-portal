#!/bin/bash
# Example of sending coins to exchange with bash.
# Most have to be fine tuned for the transaction fees.
# You have to use absolute paths to your coin's datadir if stored in a non-default way
# Using the cron entry below you can set the script to run once an hour
# 0 * * * * ~/unomp/multipool/exchange >~/unomp/multipool/alerts/cronexchange.log 2>&1

echo
echo
DGBbalance=`digibyted getbalance`
DGBBalance=$(echo "$DGBbalance - 1.0" | bc -l)
echo "Digibyte BALANCE: $DGBbalance"
DGBaddress="YOUR EXCHANGE DIGIBYTE ADDRESS"
digibyted sendtoaddress $DGBaddress $DGBBalance
echo
echo
