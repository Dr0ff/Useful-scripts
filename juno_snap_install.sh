#!/bin/bash
sudo -v
read -p "" SNAP_LINK
echo "$SNAP_LINK"
break
wget -O juno_latest.tar.lz4 $SNAP_LINK --inet4-only
sudo systemctl stop juno.service
cp $HOME/.juno/data/priv_validator_state.json $HOME/.juno/priv_validator_state.json.backup
junod tendermint unsafe-reset-all --home $HOME/.juno --keep-addr-book
lz4 -c -d juno_latest.tar.lz4  | tar -x -C $HOME/.juno
mv $HOME/.juno/priv_validator_state.json.backup $HOME/.juno/data/priv_validator_state.json
sudo systemctl start juno.service
sudo journalctl -u juno -f --output cat
rm -v juno_latest.tar.lz4
