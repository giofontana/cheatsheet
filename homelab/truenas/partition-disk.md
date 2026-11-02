
# Partition disk and add as slog

```
fdisk /dev/sdX
g – Create a new GPT partition table
n – Add a new partition
(example +100G)
w – Write changes and exit

zpool add -f [pool name] log /dev/da[x]
```


