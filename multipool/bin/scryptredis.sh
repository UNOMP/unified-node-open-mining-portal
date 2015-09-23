#!/bin/sh

coin=$1

if [ "$#" != 1 ];
then
  echo "$0 <coin>";
  exit;
else
  redis-cli hset Coin_Names $coin 1
  redis-cli hset Coin_Names_scrypt $coin 1
fi
