#!/bin/bash
counter=0
now="`date +%s`"
tenminsago=`echo "$now - 700" | bc`
thisShift=`redis-cli hget Pool_Stats This_Shift`
ShiftStart=`redis-cli hget Pool_Stats:$thisShift starttime`
 
counter=0
total_sha=0
total_scrypt=0
total_scryptn=0
total_x11=0
total_keccak=0
 
 
 
# loop through algos
while read StatKey
do
        this_sha=`echo $StatKey | jq .algos.sha256.hashrate`
        this_scrypt=`echo $StatKey | jq .algos.scrypt.hashrate`
        this_x11=`echo $StatKey | jq .algos.x11.hashrate`
        this_keccak=`echo $StatKey | jq .algos.keccak.hashrate`
        counter=$(($counter + 1))
 
        #adjust so scrypt/scryptN/x11 = MH, SHA = GH Keccak = MH
        this_sha=`echo "$this_sha / (1024 * 1024 * 1024)" | bc -l`
        this_scrypt=`echo "$this_scrypt / (1024 * 1024)" | bc -l`
        this_x11=`echo "$this_x11 / (1024 * 1024)" | bc -l`
        this_keccak=`echo "$this_keccak / (1024 * 1024)" | bc -l`
 
        #add to totals
        total_sha=`echo "$this_sha + $total_sha" | bc -l`
        total_scrypt=`echo "$total_scrypt + $this_scrypt" | bc -l`
        total_x11=`echo "$total_x11  + $this_x11" | bc -l`
        total_keccak=`echo "$total_keccak  + $this_keccak" | bc -l`
 
        tmpcount=0
#       echo "Before loop"
#       echo "`echo $StatKey | jq ".algos[] | .hashrate"`"
        while read tmpline
        do
                tmpcount=$(($tmpcount + 1))
#               echo "$tmpcount - $tmpline"
                if [[ $tmpcount -eq 5 ]]
                then
                this_scryptn=$tmpline
#               this_scryptn=`echo "$this_scryptn / (1024 * 1024)" | bc -l`
                total_scryptn=`echo "$total_scryptn  + $this_scryptn" | bc -l`
                fi
#       echo "inside loop"
        done< <(echo $StatKey | jq  ".algos[] | .hashrate")
 
 
 
 
done< <(redis-cli zrangebyscore statHistory $tenminsago $now)
echo "total $counter stats"
echo "now: $now then: $tenminsago"
 
        total_sha=`echo "scale=2;$total_sha / $counter" | bc -l`
          total_scrypt=`echo "scale=2;$total_scrypt / $counter" | bc -l`
  total_x11=`echo "scale=2;$total_x11 / $counter" | bc -l`
  total_scryptn=`echo "scale=2;$total_scryptn / $counter / (1024 * 1024)" | bc -l`
  total_keccak=`echo "scale=2;$total_keccak / $counter" | bc -l`
 
echo "SHA: $total_sha Scrypt: $total_scrypt X11: $total_x11 Scrypt-N: $total_scryptn Keccak: $total_keccak" >>~/unomp/multipool/alerts/cronhashrate.log
 
redis-cli zadd Pool_Stats:AvgHRs:sha $now $total_sha":"$now
redis-cli zadd Pool_Stats:AvgHRs:scrypt $now $total_scrypt":"$now
redis-cli zadd Pool_Stats:AvgHRs:x11 $now $total_x11":"$now
redis-cli zadd Pool_Stats:AvgHRs:scryptn $now $total_scryptn":"$now
redis-cli zadd Pool_Stats:AvgHRs:keccak $now $total_keccak":"$now
