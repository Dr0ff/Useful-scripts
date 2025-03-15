#!/bin/bash
sudo systemctl stop sommelier.service
cp $HOME/.sommelier/data/priv_validator_state.json $HOME/.sommelier/priv_validator_state.json.backup
sommelier tendermint unsafe-reset-all --home $HOME/.sommelier --keep-addr-book
#peers=""  
SNAP_RPC="https://rpc.lavenderfive.com:443/sommelier"
#sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.sommelier/config/config.toml 
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height);
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000));
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash) 
echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH && sleep 2
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ;
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ;
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ;
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ;
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.sommelier/config/config.toml
mv $HOME/.sommelier/priv_validator_state.json.backup $HOME/.sommelier/data/priv_validator_state.json
sudo systemctl start sommelier.service
sudo journalctl -u sommelier -f --output cat
