#!/bin/bash
wget -O juno_latest.tar.lz4 https://snapshots.polkachu.com/snapshots/juno/juno_25110227.tar.lz4 --inet4-only
sudo systemctl stop juno.service
#peers=""
#SNAP_RPC="https://juno-rpc.polkachu.com:443"
#sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.juno/config/config.toml 
#LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height);
#BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000));
#TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash) 
#echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH && sleep 2
#sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ;
#s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ;
#s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ;
#s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ;
#s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.juno/config/config.toml
cp $HOME/.juno/data/priv_validator_state.json $HOME/.juno/priv_validator_state.json.backup
junod tendermint unsafe-reset-all --home $HOME/.juno --keep-addr-book
lz4 -c -d juno_latest.tar.lz4  | tar -x -C $HOME/.juno
# Remove the empty wasm folder if you have an empty one, just in case
# rm -r ~/.juno/data/wasm
# Get our wasm folder
# wget -O juno_wasmonly.tar.lz4 https://snapshots.polkachu.com/wasm/juno/juno_wasmonly.tar.lz4 --inet4-only
# Extract the wasm folder into the right place
# lz4 -c -d juno_wasmonly.tar.lz4  | tar -x -C $HOME/.juno/data
# Clean up
# rm juno_wasmonly.tar.lz4

mv $HOME/.juno/priv_validator_state.json.backup $HOME/.juno/data/priv_validator_state.json
sudo systemctl start juno.service
sudo journalctl -u juno -f --output cat
#rm -v juno_latest.tar.lz4
