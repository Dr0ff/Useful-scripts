#!/bin/bash
galacticad stop
#sudo systemctl stop galactica.service
#https://galactica.rpc.t.stavr.tech:443
#https://rpc-reticulum.galactica.com:443
SNAP_RPC="https://galactica.rpc.t.stavr.tech:443"
BACK_TO_BLOCKS=2000
echo -e "\e[33mRPC NODE:\e[32m $SNAP_RPC\e[0m"
echo -e "\e[33mBack to blocks:\e[32m $BACK_TO_BLOCKS\e[0m"

cp $HOME/.galactica/data/priv_validator_state.json $HOME/.galactica/priv_validator_state.json.backup
galacticad tendermint unsafe-reset-all --home $HOME/.galactica --keep-addr-book
#peers="0d67bedc7f929200d52c8724dfc50f848661f9ba@lava-mainnet-peer.itrocket.net:28656,8d28c38d956384510558664f5897a383b7529699@136.243.95.31:29156,859a5b9a8c3d9ef51abbf8c0ef29bdf3eaf142af@35.224.202.186:26656,408ddeb68bd2cc5e6ff1b3ed17ac1e79b70cb356@65.108.111.236:55676,ab7a906235396f2a5ddfce73375430c7ac5e0097@23.227.223.1:26656,f0731f48574c0e8d3dd6716a9ae45f878dd7dc9e@[2a01:4f9:3080:419e::9]:26656,e726816f42831689eab9378d5d577f1d06d25716@169.155.171.209:26656,f6a239ae943247ec5f879866b44648b64a85a654@168.119.89.91:41004,e94feefdb4f9b2fac84cf3fc0b1795ce03bb82c2@84.17.42.200:56456,35699d219003077eb6112e971ae2a20c0cb80060@162.55.29.50:26656,e29416e0884674d946f095f9a4ddeee7a332d0ac@65.109.118.161:26656"  

#sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.galactica/config/config.toml 
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height);
BLOCK_HEIGHT=$((LATEST_HEIGHT - $BACK_TO_BLOCKS));
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash) 
echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH && sleep 2
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ;
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ;
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ;
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ;
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.galactica/config/config.toml
mv $HOME/.galactica/priv_validator_state.json.backup $HOME/.galactica/data/priv_validator_state.json
#galacticad start --home=$HOME/.galactica --chain-id=galactica_9302-1 --keyring-backend=file --pruning=nothing --metrics --rpc.unsafe --log_level=info --json-rpc.enable=true --json-rpc.enable-indexer=true --json-rpc.api=eth,txpool,personal,net,debug,web3 --api.enable
galacticad start --chain-id=galactica_9302-1
#sudo systemctl start galactica.service
#sudo journalctl -u lava -f --output cat
