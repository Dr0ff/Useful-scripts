#!/bin/bash
#sudo systemctl stop galactica.service
#https://galactica.rpc.t.stavr.tech:443
#https://rpc-reticulum.galactica.com:443
SNAP_RPC="https://galactica-testnet-rpc.polkachu.com:443"
BACK_TO_BLOCKS=2000
echo -e "\e[33mRPC NODE:\e[32m $SNAP_RPC\e[0m"
echo -e "\e[33mBack to blocks:\e[32m $BACK_TO_BLOCKS\e[0m"

cp $HOME/.galactica/data/priv_validator_state.json $HOME/.galactica/priv_validator_state.json.backup
galacticad tendermint unsafe-reset-all --home $HOME/.galactica --keep-addr-book
peers="f3cd6b6ebf8376e17e630266348672517aca006a@46.4.5.45:27456"  

sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.galactica/config/config.toml 
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
#galacticad start --chain-id=galactica_9302-1
sudo systemctl start galactica.service
sudo journalctl -u galactica -f --output cat
