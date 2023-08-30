# autoBackup
自动备份

1、下载脚本：
```
curl -L https://raw.githubusercontent.com/kshipeng/autoBackup/main/autoBackup.sh -o autoBackup.sh && chmod +x autoBackup.sh && vim ./autoBackup.sh
```
2、按i后填入必须变量的值

3、完成后按esc后输入(冒号):wq

4、手动执行一次看有没有错误
```
./autoBackup.sh
```
5、定时任务仅在第一次设置时有效。以后要更改，直接编辑crontab，命令：crontab -e

6、重新下载脚本后需重新配置
