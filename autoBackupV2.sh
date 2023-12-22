#!/bin/bash

### ===================================================================
### 脚本参数说明。
###   如果需要备份多个数据，可创建本脚本的副本进行配置。
###   如果在配置文件中设置多个子项(目前最多5个)，以下命令仅修改第一个子配置。
###   定时任务使用第一个子配置，其它无效。
###   ！！数据库备份时会锁表，建议凌晨备份！！
### Usage:
###   ./autoBackupV2.sh [options]
###
### Options:
###   -h|--help                查看帮助信息.
###   -r|--run 1,2,3           运行脚本(对应3种备份类型).
###   -g|--cleargit            清理Git提交记录(可选:y/n)(类型3时可分别设置: '目录类型｜数据库类型').
###   -c|--config              配置脚本.
###   -s|--show                查看配置文件.
###   -D|--update              更新脚本
###   -U|--uninstall           卸载脚本
###   -S|--stop                停止备份(删除定时任务)
###
###   -t|--type 1或2           备份类型(默认1), 1: 目录, 2: 数据库, 3: 同时配置.
###   -m|--remark 'remark'     备注信息
###   -i|--input '/xxx/xxx'    需要备份的目录绝对路径(类型1时必选).
###   -x|--prefix 'xxx'        备份文件前缀(可选)(类型3时可分别设置: '目录类型｜数据库类型').
###   -n|--name 'xxx'          GitHub用户名.
###   -e|--email 'xxx@xx.xx'   GitHub对应的邮箱.
###   -l|--url 'url'           GitHub项目clone地址(类型3时可分别设置: '目录类型｜数据库类型').
###   -u|--user 'root'         数据库用户名(类型2、3时必选).
###   -p|--passwd 'xxx'        数据库密码.
###   -P|--port '3306'         数据库端口(默认3306).
###   -N|--dbName 'name'       数据库名称(多个用｜分割)(类型2、3时必选).
###   -H|--host 'address'      数据库主机(默认127.0.0.1).
###   -d|--expired 'name'      过期时间(单位分钟).(类型3时可分别设置: '目录类型｜数据库类型').
###   -A|--tarPasswd ''        压缩文件密码.(类型3时可分别设置: '目录类型｜数据库类型').
###   -C|--cron '0 */2 * * *'  cron表达式(可选)(默认为0 */2 * * *)(类型3时可分别设置: '目录类型｜数据库类型').
### ===================================================================

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# 使用 ./autoBackupV2.sh -c 配置 #
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Help() {
    sed -rn 's/^### ?//;T;p;' "$0"
}
if [[ $# == 0 ||  "$1" == "-h" || "$1" == "--help" ]]; then Help; exit; fi

NewConf(){
echo '
#配置1
declare -A conf'"$1"'
conf'"$1"'=(
#（可选）脚本备注
[remark]='"'${remark:=GitHub自动备份}'"'
#（可选）备份完清理Git提交记录, y:清理; n:不清理.(类型3时可分别设置: ''目录类型｜数据库类型'')
[clear_git]='"'${clear_git:=n}'"'

#（必选）备份类型(1: 目录, 2: 数据库, 3: 同时配置)
[backup_type]='"'${backup_type:=1}'"'
#（类型1时必须）需要备份的目录绝对路径)
[need_backup_path]='"'${need_backup_path:=}'"'
#（类型2、3时必须）数据库用户名
[db_user]='"'${db_user:=root}'"'
#（类型2、3时必须）数据库密码
[db_passwd]='"'${db_passwd:=}'"'
#（类型2、3时必须）数据名称(多个用｜分割)
[db_name]='"'${db_name:=}'"'
#（类型2、3时必须）数据库端口
[db_port]='"'${db_port:=3306}'"'
#（类型2、3时必须）数据库主机
[db_host]='"'${db_host:=127.0.0.1}'"'
#（可选）备份文件前缀(类型3时可分别设置: ''目录类型｜数据库类型'')
[back_file_prefix]='"'${back_file_prefix:=Auto}'"'
#（必须）GitHub用户名
[git_user_name]='"'${git_user_name:=}'"'
#（必须）GitHub对应的邮箱
[git_user_email]='"'${git_user_email:=}'"'
#（必须）GitHub项目地址(类型3时可分别设置: ''目录类型｜数据库类型'')
[git_url]='"'${git_url:=}'"'
#压缩文件密码.(类型3时可分别设置: ''目录类型｜数据库类型'').
[tarPasswd]='"'${tarPasswd:=}'"'
#（可选）删除过期备份压缩文件（单位分钟，默认180）(类型3时可分别设置: ''目录类型｜数据库类型'')
[exp_time]='"'${exp_time:=180}'"'
#（可选）定时任务cron（默认目录类型每2小时备份一次。数据库备份时会锁表，建议凌晨进行）
#(类型3时可分别设置: ''目录类型｜数据库类型'')
[cron]='"'${cron:=0 */2 * * *|30 4 * * *}'"'
)' >> "${config_file}"
}

shellURL='https://raw.githubusercontent.com/kshipeng/autoBackup/main/autoBackupV2.sh'
version='2.0.3'
paramFromConf=true
fullfile="$(pwd)/$(basename "$0")"
fullname="${fullfile##*/}"
fileDir="${fullfile%/*}"
fileExtension="${fullname##*.}"
filename="${fullname%.*}"
config_file="${fileDir}/.${filename}.conf"
notifyMsg=''

ColorStr(){
    BLACK_COLOR='\033[30m';  RED_COLOR='\033[31m'; GREEN_COLOR='\033[32m'; YELLOW_COLOR='\033[33m'
     BLUE_COLOR='\033[34m'; PINK_COLOR='\033[35m';   SKY_COLOR='\033[36m';  WHITE_COLOR='\033[37m'
    RES='\033[0m'
    #这里判断传入的参数是否不等于2个，如果不等于2个就提示并退出
    if [ $# -ne 2 ];then echo "Usage $0 content {black|red|yellow|blue|green|pink|sky|white}"; exit; fi
    case "$2" in black|BLACK)     echo -e "${BLACK_COLOR}$1${RES}" ;;
        red|RED)                 echo -e "${RED_COLOR}$1${RES}" ;;
        yellow|YELLOW)             echo -e "${YELLOW_COLOR}$1${RES}" ;;
        green|GREEN)             echo -e "${GREEN_COLOR}$1${RES}" ;;
        blue|BLUE)                 echo -e "${BLUE_COLOR}$1${RES}" ;;
        pink|PINK)                 echo -e "${PINK_COLOR}$1${RES}" ;;
        sky|SKY)                 echo -e "${SKY_COLOR}$1${RES}" ;;
        white|WHITE)             echo -e "${WHITE_COLOR}$1${RES}" ;;
        *) echo -e "请输入指定的颜色代码：{black|red|yellow|blue|green|pink|sky|white}"
    esac
}

GetConfig(){
    if [ ! -f "${config_file}" ]; then
        ColorStr "还未配置任何信息" white
        ColorStr "使用：$(ColorStr "./${fullname} -c" green)命令进行配置" red
        exit
    fi
    if [[ $1 == 'show' ]]; then
        ColorStr "$(GetConfig 'read' 'conf1' 'remark') 的配置信息" pink
        cat "${config_file}"
    elif [[ $1 == 'read' ]]; then
        source "${config_file}"
        case "$2" in
            'conf1') echo "${conf1[$3]}" ;;
            'conf2') echo "${conf2[$3]}" ;;
            'conf3') echo "${conf3[$3]}" ;;
            'conf4') echo "${conf4[$3]}" ;;
            'conf5') echo "${conf5[$3]}" ;;
            *) echo -e "未能读取$2"
        esac
        #sed "/^$2=/"'!d; s/.*=//' "${config_file}"
    fi
}

GetCronInfo(){
    backup_type=$(GetConfig 'read' 'conf1' 'backup_type')
    cron="$(GetConfig 'read' 'conf1' 'cron')"
    cron1=''; cron2=''; cron3=''; cronCom1=''; cronCom2=''; cronCom3=''
    if [[ $backup_type == 1 ]]; then
        cron1="$(GetParam "${cron}" '1')"
        cronCom1="${fullfile} -r 1"
    elif [[ $backup_type == 2 ]]; then
        cron2="$(GetParam "${cron}" '2')"
        cronCom2="${fullfile} -r 2"
    elif [[ $backup_type == 3 ]]; then
        cron1="$(GetParam "${cron}" '1')"
        cron2="$(GetParam "${cron}" '2')"
        if [[ "${cron1}" == "${cron2}" ]]; then
            cron3="${cron1}"
            cronCom3="${fullfile} -r 3"
        else
            if [ -z "${cron2}" -a -n "${cron1}" ]; then
                cronCom1="${fullfile} -r 1"
            fi
            if [ -n "${cron2}" -a -z "${cron1}" ]; then
                cronCom2="${fullfile} -r 2"
            fi
            if [ -n "${cron2}" -a -n "${cron1}" ]; then
                cronCom1="${fullfile} -r 1"
                cronCom2="${fullfile} -r 2"
            fi
        fi
        
    else ColorStr '错误的备份类型' red; exit 1;
    fi
}

SetCron(){
    tempCronPath="${fileDir}/tempCrontab"
    if [[ $1 == 'set' ]]; then
        GetCronInfo
        crontab -l > "${tempCronPath}"
        sed -i '/^.*'"${fullname}"'.*$/d' "${tempCronPath}"
        [ -n "${cronCom1}" ] && echo "${cron1} ${cronCom1}" >> "${tempCronPath}"
        [ -n "${cronCom2}" ] && echo "${cron2} ${cronCom2}" >> "${tempCronPath}"
        [ -n "${cronCom3}" ] && echo "${cron3} ${cronCom3}" >> "${tempCronPath}"
        #if [[ "${cronCom1}" != '' && `crontab -l` != *"${cronCom1}"* ]]; then echo "${cron1} ${cronCom1}" >> "${tempCronPath}"; fi
        #if [[ "${cronCom1}" != '' ]]; then  sed -i 's#^.*'"${cronCom1}"'.*$#'"${cron1} ${cronCom1}"'#' "${tempCronPath}"; fi
        crontab "${tempCronPath}" && rm -f "${tempCronPath}"
        ColorStr '***【定时任务已更新。当前系统定时任务如下】***' yellow
        crontab -l
    elif [[ $1 == 'del' ]]; then
        crontab -l > "${tempCronPath}"
        sed -i '/^.*'"${fullname}"'.*$/d' "${tempCronPath}"
        crontab "${tempCronPath}" && rm -f "${tempCronPath}"
        ColorStr '***【定时任务已取消。当前系统定时任务如下】***' yellow
        crontab -l
    fi
}

WriteConfig(){
    #echo "${config_file}"
    if [ ! -f "${config_file}" ]; then
        echo '#配置文件位置' >> "${config_file}"
        echo "#${config_file}" >> "${config_file}";
        echo ''  >> "${config_file}";
        echo '#Telegram通知设置' >> "${config_file}"
        echo 'TGBotToken=''' >> "${config_file}"
        echo 'TGChatId=''' >> "${config_file}";
        echo ''  >> "${config_file}";
        echo '#数组中的配置会被读取' >> "${config_file}"
        echo "confArr=(conf1)" >> "${config_file}"
        NewConf 1

    fi
    if [[ $1 == 'notify' ]]; then
        sed -i 's/^'"$2"'.*$/'"$2"'='"'$3'"'/' "${config_file}"
    else
        sed -i '0,/^\['"$1"'.*$/s#^\['"$1"'.*$#'"[$1]"'='"'$2'"'#' "${config_file}"
    fi
    
    if [[ $1 == 'cron' ]] || [[ $1 == 'backup_type' && $3 == 'updateCron' ]]; then
        SetCron 'set'
    fi
    #cat "${config_file}"
}

SetConfig(){
    ColorStr ' !!!不要输入不必要的空格!!!' green
    ColorStr ' 选择备份类型:' green
    echo -e " 1: 目录\n 2: 数据库\n 3: 同时配置\n 0: 退出脚本"
    backup_type=''; while [[ $backup_type != '1' && $backup_type != '2' && $backup_type != '3' && $backup_type != '0' && backup_type != '' ]]; do echo -n $(ColorStr ' 输入数字序号（默认1）>' green); read backup_type; [[ -z $backup_type ]] && backup_type='1'; done
    if [[ $backup_type == '0' ]]; then exit; fi
    if [[ $backup_type == '' ]]; then backup_type='1'; fi

    echo -n $(ColorStr ' 输入脚本备注(例如：XX备份)>' green); read remark
    echo -n $(ColorStr ' 备份完清理Git(y/n)(类型3时可分别设置: ''目录类型｜数据库类型'')>' green); read clear_git
    if [[ $clear_git == '' ]]; then clear_git='n'; fi
    while [[ -z $git_user_name ]]; do echo -n $(ColorStr ' 输入GitHub用户名 >' green); read git_user_name; done
    while [[ -z $git_user_email ]]; do echo -n $(ColorStr ' 输入GitHub对应的邮箱 >' green); read git_user_email; done
    while [[ -z $git_url ]]; do echo -n $(ColorStr ' 输入GitHub项目远端地址, 或本地路径(类型3时可分别设置: ''目录类型｜数据库类型'')>' green); read git_url; done

    if [[ $backup_type == '1' || $backup_type == '3' ]]; then
        while [[ -z $need_backup_path ]]; do echo -n $(ColorStr ' 输入待备份目录的绝对路径 >' green); read need_backup_path; done
        echo -n $(ColorStr ' 输入压缩文件过期时间(单位分钟，默认180)(类型3时可分别设置: ''目录类型｜数据库类型'')>' green); read exp_time
    fi

    if [[ $backup_type == '2' || $backup_type == '3' ]]; then
        echo -n $(ColorStr ' 输入数据库用户名(默认root)>' green); read db_user
        echo -n $(ColorStr ' 输入数据库密码 >' green); read db_passwd
        echo -n $(ColorStr ' 输入数据名称(多个用｜分割) >' green); read db_name
        echo -n $(ColorStr ' 输入数据主机（默认127.0.0.1）>' green); read db_host
        while true; do echo -n $(ColorStr ' 输入数据端口(默认3306)>' green); read db_port; if [ "$db_port" -gt 0 ] 2>/dev/null ; then break; elif [ -z $db_port ]; then break; fi done
    fi
    echo -n $(ColorStr ' 输入压缩文件密码(可空)(类型3时可分别设置: ''目录类型｜数据库类型'')>' green); read tarPasswd
    echo -n $(ColorStr ' 输入备份文件前缀(可空)(类型3时可分别设置: ''目录类型｜数据库类型'')>' green); read back_file_prefix
    echo -n $(ColorStr ' 输入定时任务cron表达式（默认每2小时备份一次）>' green); read cron
    
    WriteConfig 'backup_type' "${backup_type}"
    WriteConfig 'remark' "${remark:=GitHub自动备份}"
    WriteConfig 'clear_git' "${clear_git:=n}"
    WriteConfig 'need_backup_path' "${need_backup_path}"
    WriteConfig 'back_file_prefix' "${back_file_prefix:=auto}"
    WriteConfig 'git_user_name' "${git_user_name}"
    WriteConfig 'git_user_email' "${git_user_email}"
    WriteConfig 'git_url' "${git_url}"
    WriteConfig 'db_user' "${db_user:=root}"
    WriteConfig 'db_passwd' "${db_passwd}"
    WriteConfig 'db_port' "${db_port:=3306}"
    WriteConfig 'db_name' "${db_name}"
    WriteConfig 'db_host' "${db_host:=127.0.0.1}"
    WriteConfig 'tarPasswd' "${tarPasswd}"
    WriteConfig 'exp_time' "${exp_time:=180}"
    WriteConfig 'cron' "${cron:=0 */2 * * *}"
}

SetNotify(){
    echo -n $(ColorStr ' 输入TG机器人Token>' green); read TGBotToken
    echo -n $(ColorStr ' 输入TG用户id>' green); read TGChatId
    WriteConfig 'notify' 'TGBotToken' "${TGBotToken}"
    WriteConfig 'notify' 'TGChatId' "${TGChatId}"
    sure=''; echo -n $(ColorStr '是否测试消息通知(y/n)' green); read sure;
    if [[ $sure == 'y' ]];then SendNotify '测试消息'; else exit; fi
    sure=''; echo -n $(ColorStr '继续设置备份参数吗?(y/n)' green); read sure;
    if [[ $sure == 'y' ]];then SetConfig; else exit; fi
}

DownShell(){
    curl -L "${shellURL}" -o "${fullfile}" && chmod +x "${fullname}" && ColorStr '更新完成' green && exit
}

Uninstall(){
    SetCron 'del' && rm -rf "${fullfile}" &&rm -rf "${config_file}" && ColorStr '卸载完成，有幸再会。' green && exit
}

SetMainConf(){
    ColorStr ' !!!不要输入不必要的空格!!!' green
    echo -e " 1: 备份参数设置\n 2: TG通知设置\n 3: 更新脚本\n 4: 卸载脚本\n 0: 退出脚本"
    accressArr=(1 2 3 4 0)
    conf_type=''; while [[ ${accressArr[@]/${conf_type}/} == ${accressArr[@]} ]] && [[ conf_type != '' ]]; do echo -n $(ColorStr ' 输入数字序号（默认1）>' green); read conf_type; [[ -z $conf_type ]] && conf_type='1'; done
    [[ $conf_type == '0' ]] && exit
    [[ $conf_type == '' ]] && conf_type='1'
    [[ $conf_type == '1' ]] && SetConfig
    [[ $conf_type == '2' ]] && SetNotify
    [[ $conf_type == '3' ]] && DownShell
    [[ $conf_type == '4' ]] && Uninstall
}

GetParam(){
    IFS_OLD=$IFS; IFS=$'|'; array=($1); IFS=${IFS_OLD};
    if [[ $1 =~ ^\|.* ]]; then res0=''; res1="${array[1]}";
    elif [[ $1 =~ *.\|$ ]]; then res1=''; res0="${array[0]}";
    elif [[ $1 =~ \| ]]; then res0="${array[0]}"; res1="${array[1]}";
    else res0=$1; res1=$1; fi
    if [[ $2 == '1' ]]; then echo "${res0}";
    elif [[ $2 == '2' ]]; then echo "${res1}";
    else echo ''; fi
}

SendNotify(){
    if [ -n "${TGBotToken}" -a -n "${TGChatId}" ]; then
        ColorStr '>>>TG通知' green
        source "${config_file}"
        params='{"chat_id":"'${TGChatId}'", "text":"'$1'", "parse_mode": "Markdown"}'
        curl -d "${params}" -H 'Content-Type: application/json' -X POST "https://api.telegram.org/bot${TGBotToken}/sendMessage"
    fi
}

delete_old_files() {
    # 接受两个参数：目录路径和时间差（单位分钟）
    local directory="$1"
    local time_difference="$2"
    # 当前时间戳
    local current_time="$3"
    # 遍历目录中的文件
    for file in "$directory"/*; do
        # 检查文件名是否以指定后缀结尾
        if [[ "$file" =~ \.(F\.tar\.gz|F\.des3|D\.sql\.tar\.gz|D\.sql\.des3)$ ]]; then
            # 提取文件名中的时间部分
            local timestamp=$(echo "$file" | awk 'match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2}/) {print substr($0, RSTART, RLENGTH)}' | tr '_' ' ')
            # 将时间转换为时间戳
            local file_time=$(date -d "$timestamp" +%s)
            # 计算时间差（以秒为单位）
            local time_difference_seconds=$((time_difference * 60))
            local time_difference_result=$((current_time - file_time))
            # 如果时间差大于指定时间差，删除文件
            if [ "$time_difference_result" -gt "$time_difference_seconds" ]; then
                rm "$file"
                echo "已删除文件: $file"
            fi
        fi
    done
}

RunFileBackup(){
    
    if [ -z "$need_backup_path" -o -z "$git_user_name" -o -z "$git_user_email" -o -z "$git_url" ]; then
        ColorStr "请先使用：$(ColorStr "./${fullname} -c" green)命令进行配置" red
        notifyMsg="${notifyMsg}🔴目录文件备份失败:参数未配置\n"
        return 1
    fi

    if [[ ! -d "$need_backup_path" && ! -f "$need_backup_path" ]]; then ColorStr "待备份目录(${need_backup_path})不存在" red; notifyMsg="${notifyMsg}🔴目录文件备份失败:待备份目录(${need_backup_path})不存在\n"; return -1; fi
    ColorStr ">>>开始$1: $(GetConfig 'read' $1 'remark') , 文件备份" pink

    backupGit="$(GetParam "${git_url}" '1')"

    if [[ -d $backupGit ]]; then
        gitPath="${backupGit}"
    else
        tempArr=(${backupGit//\// })
        lastIndex=$((${#tempArr[@]}-1))
        tempArr=(${tempArr[lastIndex]//./ })
        resName=${tempArr[0]}
        gitPath="${fileDir}/${resName}"
    fi
    
    [ ! -d "${gitPath}" ] && cd "${fileDir}" && git clone "$backupGit";
    [ ! -d "${gitPath}" ] && notifyMsg="${notifyMsg}🔴目录文件备份失败:(${gitPath})不存在(git clone失败)\n" && return 1
    cd `dirname $need_backup_path`

    file_prefix="$(GetParam "${back_file_prefix}" '1')"
    tar_passwd="$(GetParam "${tarPasswd}" '1')"
    
    ColorStr ">>>【正在压缩】`basename $need_backup_path` 请等待..." green
    export TZ=Asia/Shanghai
    currentTime=$(date +%Y-%m-%d_%H:%M:%S)
    currentTimestamp=$(date -u +%s)
    back_file_name_p="${file_prefix}_${currentTime}"
    file_extension1='F.tar.gz'; file_extension2='F.des3';
    [[ -f "$need_backup_path" ]] && backFileBasename=`basename $need_backup_path` && file_extension1="${backFileBasename}.F.tar.gz" && file_extension2="${backFileBasename}.F.des3"
    if [[ "${file_prefix}" == '' ]]; then back_file_name_p="${currentTime}"; fi
    if [[ -n $tar_passwd ]]; then
        ColorStr '已设置压缩密码' pink
        back_file_name="${back_file_name_p}.${file_extension2}"
        tar --force-local -czf - `basename $need_backup_path` | openssl des3 -salt -k "${tar_passwd}" 2>/dev/null | dd of="${back_file_name}"
    else
        back_file_name="${back_file_name_p}.${file_extension1}"
        tar --force-local -czf "${back_file_name}" `basename $need_backup_path`
    fi
    
    mv "${back_file_name}" "${gitPath}/${back_file_name}"
    ColorStr "***【压缩完成】***" green
    ColorStr "GitHub仓库路径:${gitPath}" pink
    cd "${gitPath}"

    #删除过期文件
    ColorStr ">>>【清理过期文件】" green
    file_exp_time="$(GetParam "${exp_time}" '1')"
    delete_old_files "${gitPath}" "$file_exp_time" "$currentTimestamp"

#    find "${gitPath}" -name "*.${file_extension1}" -mmin "+${file_exp_time}"
#    find "${gitPath}" -name "*.${file_extension2}" -mmin "+${file_exp_time}"
#    find "${gitPath}" -name "*.${file_extension1}" -mmin "+${file_exp_time}" -exec rm -rf {} \;
#    find "${gitPath}" -name "*.${file_extension2}" -mmin "+${file_exp_time}" -exec rm -rf {} \;
    ColorStr "***【清理完成】***" green
    #git
    git config user.name "${git_user_name}"
    git config user.email "${git_user_email}"

    if [[ -n `git status -s` ]]; then
        git add .
          git commit -am "自动备份：${currentTime}"
          ColorStr ">>>【开始推送到GitHub】..." green
          git push
    else
        notifyMsg="${notifyMsg}🟡目录文件 备份:git没有变更的数据\n" && return 0
    fi

    if [[ -z `git status -s` ]]; then
          notifyMsg="${notifyMsg}🟢目录文件 备份成功\n"
     else
         notifyMsg="${notifyMsg}🔴目录文件 备份失败:git push失败\n"
    fi
}

RunDBBackup(){

    if [ -z "$db_user" -o -z "$db_name" -o -z "$git_user_name" -o -z "$git_user_email" -o -z "$git_url" ]; then
        ColorStr "请先使用：$(ColorStr "./${fullname} -c" green)命令进行配置" red
        notifyMsg="${notifyMsg}🔴数据库 备份失败:参数未配置\n"
        return 1
    fi
    ColorStr ">>>开始$1: $(GetConfig 'read' $1 'remark') , 数据库备份" pink

    dbBackupGit="$(GetParam "${git_url}" '2')"

    if [[ -d $dbBackupGit ]]; then
        gitPath="${dbBackupGit}"
    else
        tempArr=(${dbBackupGit//\// })
        lastIndex=$((${#tempArr[@]}-1))
        tempArr=(${tempArr[lastIndex]//./ })
        resName=${tempArr[0]}
        gitPath="${fileDir}/${resName}"
    fi
    
    [ ! -d "${gitPath}" ] && cd "${fileDir}" && git clone "$dbBackupGit"
    [ ! -d "${gitPath}" ] && notifyMsg="${notifyMsg}🔴数据库 备份失败:(${gitPath})不存在(git clone失败)\n" && return 1
    mysqlStatus=`mysqladmin -u "${db_user}" -p"${db_passwd}" -h "${db_host}" -P "${db_port}" ping`
    [[ "$mysqlStatus" != 'mysqld is alive' ]] && notifyMsg="${notifyMsg}🔴数据库 备份失败:无法连接数据库\n" && return 1
    ColorStr "GitHub仓库路径:${gitPath}" pink
    cd "${gitPath}"
    IFS_OLD=$IFS; IFS=$'|'; dbNameArray=(${db_name}); IFS=${IFS_OLD};
    file_prefix=$(GetParam "${back_file_prefix}" '2')
    tar_passwd=$(GetParam "${tarPasswd}" '2')
    for database in ${dbNameArray[@]}; do
        ColorStr ">>>开始备份数据库:${database}" green
        export TZ=Asia/Shanghai
        currentTime=$(date +%Y-%m-%d_%H:%M:%S)
        currentTimestamp=$(date -u +%s)
        sql_file_name="${file_prefix}_${database}_${currentTime}.D.sql"
        if [[ "${file_prefix}" == '' ]]; then
            sql_file_name="${database}_${currentTime}.D.sql"
        fi
        mysqldump -u "${db_user}" -p"${db_passwd}" -h "${db_host}" -P "${db_port}" "$database" > "${sql_file_name}"
        if [[ -n $tar_passwd ]]; then
            ColorStr '已设置压缩密码' pink
            sql_back_file_name="${sql_file_name}.des3"
            tar --force-local -czf - "${sql_file_name}" | openssl des3 -salt -k "${tar_passwd}" 2>/dev/null | dd of="${sql_back_file_name}"
            rm -rf "${sql_file_name}"
        else
            sql_back_file_name="${sql_file_name}.tar.gz"
            tar --force-local -czf "${sql_file_name}" "${sql_back_file_name}"
        fi
    done
    
    #删除过期文件
    ColorStr ">>>【清理过期文件】" green
    file_exp_time="$(GetParam "${exp_time}" '2')"
    delete_old_files "${gitPath}" "$file_exp_time" "$currentTimestamp"
#    find "${gitPath}" -name "*.D.sql.tar.gz" -mmin "+${file_exp_time}"
#    find "${gitPath}" -name "*.D.sql.des3" -mmin "+${file_exp_time}"
#    find "${gitPath}" -name "*.D.sql.tar.gz" -mmin "+${file_exp_time}" -exec rm -rf {} \;
#    find "${gitPath}" -name "*.D.sql.des3" -mmin "+${file_exp_time}" -exec rm -rf {} \;
    ColorStr "***【清理完成】***" green
    #git
    git config user.name "${git_user_name}"
    git config user.email "${git_user_email}"

    if [[ -n `git status -s` ]]; then
        git add .
          git commit -am "自动备份：${currentTime}"
          ColorStr ">>>【开始推送到GitHub】..." green
          git push
     else
         notifyMsg="${notifyMsg}🟡数据库 备份:git没有变更的数据\n" && return
    fi
    if [[ -z `git status -s` ]]; then
          notifyMsg="${notifyMsg}🟢数据库 备份成功\n"
     else
         notifyMsg="${notifyMsg}🔴数据库 备份失败:git push失败\n"
    fi
}

CheckVer(){
    verInfor=`curl -L -s 'https://raw.githubusercontent.com/kshipeng/autoBackup/main/ver.txt'`
    if [[ "${verInfor}" =~ 'ver=' && "${verInfor}" =~  'infor=' ]]; then
        ver=`echo "${verInfor}" | sed -e 's/^ver=//' -e 's/^infor.*//'`
        verMsg=`echo "${verInfor}"  | sed -e 's/^ver=.*$//' -e 's/^infor=//'`
        [[ "${verMsg}" == '' ]] && verMsg=''
        if dpkg --compare-versions "${ver}" gt "${version}"; then
            verMsg="有新版本可用:${ver}${verMsg}"
            echo "${verMsg}"
        else
            echo ''
        fi
    else
        echo ''
    fi
}

ResetGit() {
    backupGit=$1
    if [[ -d $backupGit ]]; then
        gitPath="${backupGit}"
    else
        tempArr=(${backupGit//\// })
        lastIndex=$((${#tempArr[@]}-1))
        tempArr=(${tempArr[lastIndex]//./ })
        resName=${tempArr[0]}
        gitPath="${fileDir}/${resName}"
    fi
    if [ ! -d "${gitPath}" ]; then
        ColorStr "🔴$2 ClearGit出错：本地仓库目录不存在，未进行过备份或已运行过该命令" red
        notifyMsg="${notifyMsg}🔴$2 ClearGit出错：本地仓库目录不存在，未进行过备份或已运行过该命令\n"
    else
        ColorStr ">>>【清理Git记录】" green
        cd "$gitPath" || exit 1
        # 获取当前分支名
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        ColorStr ">>>【当前分支: ${current_branch}】" yellow
        # 检查是否存在当前分支
        if [ -n "$current_branch" ]; then
            # 切换到其他分支，以便删除当前分支
            git checkout --orphan AutoBackupClear # 你可以替换成其他分支名
            git commit -m "自动备份并清理"
            # 删除当前分支
            #git branch -d "$current_branch"
            # 强制删除，如果分支有未合并的更改
            git branch -D "$current_branch"
            #重命名为原分支
            git branch -m "$current_branch"
            git push -f origin "$current_branch"
            rm -rf "${gitPath}"
            [ ! -d "${gitPath}" ] && cd "${fileDir}" && git clone "$backupGit";
            [ ! -d "${gitPath}" ] && notifyMsg="${notifyMsg}🔴$2 ClearGit出错：clone出错\n" && return 1
            notifyMsg="${notifyMsg}🟢$2 清理完成。\n"
        else
            ColorStr "🔴$2 ClearGit出错：无法确定当前分支。" red
            notifyMsg="${notifyMsg}🔴$2 ClearGit出错：无法确定当前分支。\n"
        fi
    fi
}

ClearGit() {
    if [ ! -f "${config_file}" ]; then
        ColorStr "请先使用：$(ColorStr "./${fullname} -c" green)命令进行配置" red
        exit 1
    fi
    if [[ $2 != 'y' ]]; then
        echo -n $(ColorStr '清理Git会删除当前分支的提交记录，确定继续吗?(y/n)' yellow); yellow answer;
        if [[ $answer != 'y' ]];then
            exit 0
        fi
    fi
    
    backup_type=$(GetConfig 'read' $1 'backup_type')
    git_url=$(GetConfig 'read' $1 'git_url')
    backupGit="$(GetParam "${git_url}" 1)"
    if [[ $backup_type = 3 ]]; then
        backupGit1="$(GetParam "${git_url}" 1)"
        backupGit2="$(GetParam "${git_url}" 2)"
        if [[ "$backupGit1" == "$backupGit2" ]]; then
            ResetGit $backupGit1 '目录文件和数据库'
        else
            ResetGit $backupGit1 '目录文件'
            ResetGit $backupGit2 '数据库'
        fi
    else
        backupGit="$(GetParam "${git_url}" $backup_type)"
        ResetGit $backupGit '目录文件'
    fi
}

Run(){
    updateMsg=`CheckVer`
    if [ ! -f "${config_file}" ]; then
        ColorStr "请先使用：$(ColorStr "./${fullname} -c" green)命令进行配置" red
        exit 1
    fi
    source "${config_file}"
    for sub_conf in ${confArr[*]}; do
        
        backup_type=$(GetConfig 'read' "${sub_conf}" 'backup_type')
        git_user_name=$(GetConfig 'read' "${sub_conf}" 'git_user_name')
        git_user_email=$(GetConfig 'read' "${sub_conf}" 'git_user_email')
        git_url=$(GetConfig 'read' "${sub_conf}" 'git_url')
        back_file_prefix=$(GetConfig 'read' "${sub_conf}" 'back_file_prefix')
        remark=$(GetConfig 'read' "${sub_conf}" 'remark')
        clear_git=$(GetConfig 'read' "${sub_conf}" 'clear_git')
        tarPasswd=$(GetConfig 'read' "${sub_conf}" 'tarPasswd')
        exp_time=$(GetConfig 'read' "${sub_conf}" 'exp_time')
        cron=$(GetConfig 'read' "${sub_conf}" 'cron')

        need_backup_path=$(GetConfig 'read' "${sub_conf}" 'need_backup_path')

        db_user=$(GetConfig 'read' "${sub_conf}" 'db_user')
        db_passwd=$(GetConfig 'read' "${sub_conf}" 'db_passwd')
        db_name=$(GetConfig 'read' "${sub_conf}" 'db_name')
        db_port=$(GetConfig 'read' "${sub_conf}" 'db_port')
        db_host=$(GetConfig 'read' "${sub_conf}" 'db_host')

        notifyMsg="${notifyMsg}\n 🔔【${sub_conf}: ${remark}】\n"
        
        if [[ $backup_type = 1 || $backup_type = 3 ]] && [[ $1 = 1 ]]; then
            RunFileBackup "${sub_conf}"
        elif [[ $backup_type = 2 || $backup_type = 3 ]] && [[ $1 = 2 ]] ; then
            RunDBBackup "${sub_conf}"
        elif [[ $backup_type = 3 && $1 = 3 ]]; then
            RunFileBackup "${sub_conf}"
            RunDBBackup "${sub_conf}"
        else
            ColorStr '错误的命令或备份类型' red
            notifyMsg="${notifyMsg}错误的命令或备份类型\n"
        fi
        if [[ $clear_git = 'y' ]]; then
            ClearGit "${sub_conf}" 'y'
        fi
    done
    if [[ "${notifyMsg}" != '' ]]; then
        echo -e "${notifyMsg}\n${updateMsg}"
        SendNotify "${notifyMsg}\n${updateMsg}"
    fi
}

ARGS=$(getopt -o 'hr:g:csDUSt:i:x:u:p:P:N:H:A:C:d:n:e:l:m:' -l 'help,run:,cleargit:,config,show,update,uninstall,stop,type:,input:,prefix:,user:,passwd:,port:,dbbName:,host:,tarPasswd:,cron:,expired:,name:,email:,url:,remark:' -n "$0" -- "$@")
if [ $? != 0 ] ; then ColorStr "参数错误! Terminating..." red >&2 ; exit 1 ; fi
#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"
while true ; do
    case "$1" in
        # 不接参数 shift 清理已获取的参数
        -h|--help) Help ; shift ;;
        -r|--run) Run $2 ; shift 2 ;;
        -c|--config) SetMainConf ; shift ;;
        -s|--show) GetConfig 'show' ; shift ;;
        -D|--update)
            DownShell;
            shift ;;
        -U|--uninstall) echo -n $(ColorStr '确定卸载吗?(y/n)' green); read sure;
            if [[ $sure == 'y' ]];then
                SetCron 'del' && rm -rf "${fullfile}" &&rm -rf "${config_file}" && ColorStr '卸载完成，有幸再会。' green
            fi
            shift ;;
        -S|--stop) echo -n $(ColorStr '确定停止吗?(y/n)' green); read sure;
            if [[ $sure == 'y' ]];then
                SetCron 'del';
            fi
            shift ;;
        #需要带参数值，所以通过 $2 取得参数值，获取后通过 shift 清理已获取的参数
        -t|--type) backup_type="$2" ; WriteConfig 'backup_type' "${backup_type}" 'updateCron' ; shift 2 ;;
        -m|--remark) remark="$2" ; WriteConfig 'remark' "${remark}" ; shift 2 ;;
        -g|--cleargit)clear_git="$2" ; WriteConfig 'clear_git' "${clear_git}" ; shift 2 ;;
        -i|--input) need_backup_path="$2" ; WriteConfig 'need_backup_path' "${need_backup_path}" ; shift 2 ;;
        -x|--prefix) back_file_prefix="$2" ; WriteConfig 'back_file_prefix' "${back_file_prefix}" ; shift 2 ;;
        -n|--name) git_user_name="$2" ; WriteConfig 'git_user_name' "${git_user_name}" ; shift 2 ;;
        -e|--email) git_user_email="$2" ; WriteConfig 'git_user_email' "${git_user_email}" ; shift 2 ;;
        -l|--url) git_url="$2" ; WriteConfig 'git_url' "${git_url}" ; shift 2 ;;
        -u|--user) db_user="$2" ; WriteConfig 'db_user' "${db_user}" ; shift 2 ;;
        -p|--passwd) db_passwd="$2" ; WriteConfig 'db_passwd' "${db_passwd}" ; shift 2 ;;
        -P|--port) db_port="$2" ; WriteConfig 'db_port' "${db_port}" ; shift 2 ;;
        -N|--dbName) db_name="$2" ; WriteConfig '  db_name' "${db_name}" ; shift 2 ;;
        -H|--host) db_host="$2" ; WriteConfig 'db_host' "${db_host}" ; shift 2 ;;
        -d|--expired) exp_time="$2" ; WriteConfig 'exp_time' "${exp_time}" ; shift 2 ;;
        -A|--tarPasswd) tarPasswd="$2" ; WriteConfig 'tarPasswd' "${tarPasswd}" ; shift 2 ;;
        -C|--cron) cron="$2" ; WriteConfig 'cron' "${cron}" ; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

#处理剩余的参数
#for arg in $@
#do
#    echo "processing $arg"
#done
    
