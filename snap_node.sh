#!/bin/bash

block=$(lavad status | jq -r '.SyncInfo.latest_block_height')

# Останавливаем ноду
sudo systemctl stop lava.service

# Создаём снапшот, сохраняя только `data/`
tar -cf - -C ~/.lava data | lz4 -9 > ~/lava_snapshot_$(date +%Y-%m-%d)_$block.tar.lz4

# Запускаем ноду
sudo systemctl start lava.service
