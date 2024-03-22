# autoBackupV2
**文件、数据库定时备份。TG消息通知**
## 注意事项
1、数据库备份时会锁表，建议在凌晨用户少时进行。

2、**删除过期文件**时会删除仓库中以```F.tar.gz```或```F.des3```或```D.sql.tar.gz```或```D.sql.des3```结尾的文件

4、备份类型为3时，可分别设置的参数，某项可为空例如：```|passwd```或```|passwd```。如果没有分隔符```|```则共用

## 2023年12月30日更新
修复多个配置类型不同时可能会报错“错误的命令或备份类型”的问题

## 2023年12月23日更新
添加清理Git提交记录方法，防止git目录越来越大。
修复一些问题。

## 2024年3月22日更新
修复在debian中遇到的删除刚备份的文件的问题

**注意：这会清除当前分支的提交记录！**

使用方法：
```
#更新脚本
./autoBackupV2.sh -D
#查看当前配置
./autoBackupV2.sh -s
#编辑配置文件(第1步中有路径)
vim /root/.autoBackupV2.conf  
#添加一行配置
#（可选）备份完清理Git提交记录,y:清理; n:不清理(类型3时可分别设置: ''目录类型｜数据库类型'')
[clear_git]='n'
```
## 使用
1、下载脚本
```
curl -L https://raw.githubusercontent.com/kshipeng/autoBackup/main/autoBackupV2.sh -o autoBackupV2.sh && chmod +x autoBackupV2.sh
```
2、配置
```
./autoBackupV2.sh -c
```
3、帮助信息
```
./autoBackupV2.sh -h
```
**配置完成后手动运行一次脚本看有没有报错**

备份类型1:```./autoBackupV2.sh -r 1```

备份类型2:```./autoBackupV2.sh -r 2```

备份类型3:```./autoBackupV2.sh -r 3```

# autoBackup（不再更新）
文件定时备份

1、下载脚本：
```
curl -L https://raw.githubusercontent.com/kshipeng/autoBackup/main/autoBackup.sh -o autoBackup.sh && chmod +x autoBackup.sh && vim ./autoBackup.sh
```
2、按i进入编辑模式，填入必须变量的值

3、完成后按esc输入(冒号):wq

4、手动执行一次看有没有错误
```
./autoBackup.sh
```
5、定时任务仅在第一次设置时有效。以后要更改，直接编辑crontab，命令：crontab -e

6、重新下载脚本后需重新配置
