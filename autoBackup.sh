#!/bin/bash

#########################################
#1、下载脚本：
#curl -L https://raw.githubusercontent.com/kshipeng/autoBackup/main/autoBackup.sh -o autoBackup.sh && chmod +x autoBackup.sh && vim ./autoBackup.sh
#2、按i
#填入必须变量的值
#按esc后输入(冒号):wq
#3、手动执行一次看有没有错误
#./autoBackup.sh
#4、定时任务仅在第一次设置时有效。以后要更改，直接编辑crontab，命令：crontab -e
#5、重新下载脚本后需重新配置
#########################################

#（必须）需要备份的目录绝对路径
need_backup_path=''
#（可选）备份文件前缀
back_file_prefix=''

#（必须）GitHub用户名
git_user_name=''
#（必须）GitHub对应的邮箱
git_user_email=''
#（必须）GitHub项目clone地址
git_url=''

#（可选）删除过期备份压缩文件（单位分钟，默认180）
exp_time=180
#（可选）定时任务cron（默认每2小时备份一次）
cron='0 */2 * * *'

if [ -z "$need_backup_path" -o -z "$need_backup_path" -o -z "$git_user_name" -o -z "$git_user_email" -o -z "$git_url" ]; then
	echo "！！！【出错啦：】须编辑脚本配置必须的变量。"
	exit 0
fi


tempArr=(${git_url//\// })
lastIndex=$((${#tempArr[@]}-1))
tempArr=(${tempArr[lastIndex]//./ })
resName=${tempArr[0]}
shellDir=$(pwd)
gitPath="${shellDir}/${resName}"

if [ ! -d "${gitPath}" ]; then
	git clone "$git_url"
fi

cd `dirname $need_backup_path`

currentTime=$(TZ=UTC-8 date +%Y-%m-%d_%H:%M:%S)
back_file_name="${back_file_prefix}_${currentTime}.tar.gz"

echo ">>>【正在压缩：】`basename $need_backup_path`，请等待..."
tar --force-local -zcvf "${back_file_name}" `basename $need_backup_path`

mv "${back_file_name}" "${gitPath}"

echo '***【压缩完成】***'
cd "${gitPath}"

#删除过期文件
find "${gitPath}" -name "*.gz" -mmin "+${exp_time}" -exec rm -rf {} \;
ls
#git
git config user.name "${git_user_name}"
git config user.email "${git_user_email}"

has_push=false
change_staged=`git status -s`
if [ -n "$change_staged" ]; then
	git add .
  	git commit -am "自动备份：${currentTime}"
  	has_push=true
fi

if [ "$has_push" = true ]; then
	echo '>>>【开始推送到GitHub】...'
  	git push
  	echo '***【备份完成】***'
fi

shellPath="${shellDir}/$(basename "$0")"
if [[ `crontab -l` =~ "${shellPath}" ]]; then
    echo '***【定时任务已设置】***'
    echo "${cron} ${shellPath}"
    echo '【如需更改，执行命令：】crontab -e'
else
    echo '>>>【设置定时任务】'
    echo "${cron} ${shellPath}"
    tempCronPath="$(pwd)/tempCrontab"
	crontab -l > "${tempCronPath}" && echo "${cron} ${shellPath}" >> "${tempCronPath}" && crontab "${tempCronPath}" && rm -f "${tempCronPath}"
	echo '***【定时任务已设置】***'
	echo '【如需更改，执行命令：】crontab -e'
fi





