# Useful-scripts
Useful scripts to make validators life easier

# Snapshot installation script
Scpript to help easy clean/setup your nodes's database with snapshot</br>
Скрипт который поможет почистить/установить базу данных из снапшота
Run following comand in your node's server terminal: </br>
Запустите в терминале команду:
```
wget -O snapshot_install.sh https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/Snapshot%20Installation/snapshot_install.sh
bash snapshot_install.sh
```


# StateSync your nodes!
Scpripts to help easy clean/setup your nodes's database using StateSync
## Juno
Run following comand in your node's server terminal
```
curl https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/juno_stat_sync.sh | bash
```
## Sommelier
Run following comand in your node's server terminal
```
curl https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/sommelier_stat_sync_.sh | bash
```
## Lava
Run following comand in your node's server terminal
```
curl https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/lava_st_sync.sh | bash
```




-------------------------
 ```Validator Configuration Script``` !!!Not yet ready!!!
    <p>A simple Bash script helps to setup validator nodes. 
    Helps you with blockchain validator's node configurations: verifies the existence of required directories and configuration files, adjusts pruning and indexer settings for optimized performance, and dynamically updates network ports to support multiple instances of the service. The script also provides user-friendly prompts to guide through enabling pruning, selecting service instances, and updating configurations with detailed validation at every step."
    </p>

Download to your /home/USER/:<br/>
[presetup.sh](https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/presetup.sh) or
```shell
wget -k -c -q -L https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/presetup.sh
```
<br/>
To run it <br/>

```bash presetup.sh```


