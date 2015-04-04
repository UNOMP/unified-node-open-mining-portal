#!/bin/sh

coin=$1

if [ "$#" != 1 ];
then
  echo "$0 <coin>";
  exit;
else
  redis-cli -h 172.16.1.17 hset Coin_Names $coin 1
  redis-cli -h 172.1.16.17 hset Coin_Names_x11 $coin 1
fi
