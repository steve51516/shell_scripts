#!/bin/bash
# Create mysqldump backups with given arguements
# Steven Fairchild 2021-04-20 updated 2021-06-01

# Set database and file variables
set_vars() {
    export SECONDS=0
    export DATABASE=$1
    export BPATH="/data/raid1/backups/mariadb/"
    export USER="root"
    export PASS="password"
    export KEEP_DAYS="30"

    export red="\e[1;31m"
    export creset="\e[0m"
    if [[ -z "$1" ]]; then
        echo -e "database name must be passed as first aurguement\nExiting..."
    exit 0
    fi
    if [[ ! -z "$2" ]]; then
        echo "Using $2 as database user"
        export USER="$2"
    fi
    if [[ ! -z "$3" ]]; then
        echo "Using $3 as user password"
        export PASS="$3"
    fi
}

root_check() {
    if [[ "$(whoami)" != "root" ]]; then
        echo -e "\n${red}This script must be ran as root!\nExiting...${creset}\n"
        exit 0
    fi
}

usage() {
    echo -e "Script usage\n\n\
    \t--help or -h: print this message\n\n\
    \tFirst arguement must be database list inside quotes even if only one database is specified\n\
    \tOptional - second aurguement is the database username\n\
    \tOptional - third aurguement is database password(will not be saved to bash history)\n\n\
    \tExample 1: ./mysql_backup.sh \"database1 database2 database3\" database_username database_password\n\
    \tExample 2: ./mysql_backup.sh \"database1\" database_username database_password\n\
    \tNOTE:\n\
    \t\tIf optional aurguments are not given the variables inside this script will be used\n\
    \t\tEdit this script to change default settings\n"
}

elapsed_time() {
    MINUTES=$(echo "scale=2;$SECONDS/60" | bc -l)
    if [[ "$MINUTES" == 0 ]]; then
        logger -t "mysql_backup.sh" "Completed in ${SECONDS} seconds"
        echo "Completed in ${SECONDS} seconds"
    else
        logger -t "mysql_backup.sh" "Completed in ${MINUTES} minutes"
        echo "Completed in ${MINUTES} minutes"
    fi
}

main() {
    cd /tmp # /tmp is a tmpfs filesystem on modern distrobutions, by default it is half the size of the total memory.
        # if the backup is larger than half the memory size, it will fail before completing (or start swapping).
    if [[ ! -d "$BPATH" ]]; then
        mkdir -p "$BPATH"
    fi
    # create dump file
    for db in $DATABASE; do
        FILE="${db}-$(date +%F).dump"
        mysqldump --opt --user=${USER} --password=${PASS} ${db} > "${FILE}"
        echo "gzipping ${FILE}... this may take some time"
        pigz -q ${FILE}
        if [[ ${?} -eq 0 ]] && [[ -f "${FILE}.gz" ]]; then
            echo "Successfully compressed ${FILE}.gz"
            sha1sum "${FILE}.gz" > "${FILE}.gz.sha1"
            # Move to permanent backup directory
            mv ${FILE}.gz ${BPATH}
            mv ${FILE}.gz.sha1 ${BPATH}
            echo "Successfully created backup of ${db} located at ${BPATH}${FILE}.gz"
            logger -t "mysql_backup.sh" "Successfully created backup of ${db} located at ${BPATH}${FILE}.gz"
        else
            echo "Failed to create ${FILE}.gz"
        fi
    done

    echo -e "${red}Deleting files older than ${KEEP_DAYS} days in ${BPATH}${creset}"
    find "${BPATH}" -mtime +"${KEEP_DAYS}" -print
    echo -e "${red}Files shown will be deleted${creset}"
    find "${BPATH}" -mtime +"${KEEP_DAYS}" -delete
    logger -t "mysql_backup.sh" "Deleted files older than ${KEEP_DAYS} days in ${BPATH}"
    cd - # Return to original directory
    history -c # stop history from saving password if provided
    elapsed_time
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
else
    root_check
    set_vars "$1"
    main
fi

exit 0
