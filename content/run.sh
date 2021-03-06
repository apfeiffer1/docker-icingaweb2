#!/bin/bash

# Hosts
ICINGA2_HOST="${ICINGA2_HOST:-icinga2}"
MYSQL_HOST="${MYSQL_HOST:-mysql}"

# In order to work with legacy environment variables linking and docker-compose env_file, we remap the usual variables:
ICINGA2_API_ENDPOINT=${ICINGA2_API_ENDPOINT:-${ICINGA2_HOST}}
ICINGA2_API_USER=${ICINGA2_API_USER:-${ICINGA2_ENV_API_USER:-${API_USER:-notset}}}
ICINGA2_API_PASSWORD=${ICINGA2_API_PASSWORD:-${ICINGA2_ENV_API_PASSWORD:-${API_PASSWORD:-notset}}}
ICINGA2_ROOT_PASSWORD=${ICINGA2_ENV_ROOT_PASSWORD:-notset}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-notset}}
MYSQL_ICINGA_DB=${MYSQL_ICINGA_DB:-${ICINGA2_ENV_MYSQL_ICINGA_DB:-notset}}
MYSQL_ICINGA_USER=${MYSQL_ICINGA_USER:-${ICINGA2_ENV_MYSQL_ICINGA_USER:-notset}}
MYSQL_ICINGA_PASSWORD=${MYSQL_ICINGA_PASSWORD:-${ICINGA2_ENV_MYSQL_ICINGA_PASSWORD:-notset}}


# Other variables
MYSQL_CREATE_WEB_DB_CMD="CREATE DATABASE ${MYSQL_ICINGAWEB_DB}; \
        GRANT ALL ON ${MYSQL_ICINGAWEB_DB}.* TO '${MYSQL_ICINGAWEB_USER}'@'%' IDENTIFIED BY '${MYSQL_ICINGAWEB_PASSWORD}';"
MYSQL_CREATE_DIRECTOR_DB_CMD="CREATE DATABASE ${MYSQL_DIRECTOR_DB} CHARACTER SET 'utf8'; \
		GRANT ALL ON ${MYSQL_DIRECTOR_DB}.* TO '${MYSQL_DIRECTOR_USER}'@'%' IDENTIFIED BY '${MYSQL_DIRECTOR_PASSWORD}';"

# functions
function wait_for_container() {
    declare container="$1"

    while ! ping -c1 -w3 $container &>/dev/null; do
        echo "ping to ${container} failed - waiting for ${container} container"
        sleep 1
    done

}

# check linked mysql container
if [[ -z "${MYSQL_HOST}" ]]; then
  >&2 echo "no mysql database container found - please link a mysql (or mariadb) container using --link some-mariadb:mysql"
  exit 1
fi

# check if containers are running
wait_for_container "$MYSQL_HOST"
wait_for_container "$ICINGA2_HOST"
while ! mysqlshow -h ${MYSQL_HOST} --u root -p${MYSQL_ROOT_PASSWORD} ; do
  echo "Mysql is not ready yet"
  sleep 1
done

# create icingaweb2 admin user
ADMIN_PASSWORD_CRYPT=$(openssl passwd -1 $ADMIN_PASSWORD)
MYSQL_CREATE_ADMIN_CMD="USE ${MYSQL_ICINGAWEB_DB}; INSERT INTO icingaweb_user (name, active, password_hash) VALUES ('${ADMIN_USER}', 1, '${ADMIN_PASSWORD_CRYPT}');"

# check if icingaweb database exists
if mysqlshow -h ${MYSQL_HOST} --u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_ICINGAWEB_DB}; then
  echo "found icingaweb2 mysql database in linked mysql container"
  else
    echo "mysql database ${MYSQL_ICINGAWEB_DB} not found"
    # create database
    if mysql -h ${MYSQL_HOST} -u root -p${MYSQL_ROOT_PASSWORD} -e "${MYSQL_CREATE_WEB_DB_CMD}"; then
      echo "created database ${MYSQL_ICINGAWEB_DB}"
	  if mysql -h ${MYSQL_HOST} -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_ICINGAWEB_DB} < /usr/share/icingaweb2/etc/schema/mysql.schema.sql; then
	    echo "created icingaweb2 mysql database schema"
		else
		  >&2 echo "error creating icinga2 database schema"
		  exit 1
	  fi
	  if mysql -h ${MYSQL_HOST} -u root -p${MYSQL_ROOT_PASSWORD} -e "${MYSQL_CREATE_ADMIN_CMD}"; then
	    echo "imported icingaweb2 admin user in database"
	    else
		  >&2 echo "error creating icingaweb2 admin user"
		  exit 1
	  fi
      else
        >&2 echo "error creating database ${MYSQL_ICINGAWEB_DB}"
		exit 1
    fi
fi

# check if director database exists
if mysqlshow -h ${MYSQL_HOST} --u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DIRECTOR_DB}; then
  echo "found director mysql database in linked mysql container"
  else
    echo "mysql database ${MYSQL_DIRECTOR_DB} not found"
    # create database
    if mysql -h ${MYSQL_HOST} -u root -p${MYSQL_ROOT_PASSWORD} -e "${MYSQL_CREATE_DIRECTOR_DB_CMD}"; then
      echo "created database ${MYSQL_DIRECTOR_DB}"
      else
        >&2 echo "error creating database ${MYSQL_DIRECTOR_DB}"
		exit 1
    fi
fi

# create /etc/icingaweb2/resources.ini
if [ ! -f /etc/icingaweb2/resources.ini ]; then
  echo "creating /etc/icingaweb2/resources.ini"
  cat <<EOF > /etc/icingaweb2/resources.ini
[icingaweb2]
type                = "db"
db                  = "mysql"
host                = "${MYSQL_HOST}"
port                = "3306"
dbname              = "${MYSQL_ICINGAWEB_DB}"
username            = "${MYSQL_ICINGAWEB_USER}"
password            = "${MYSQL_ICINGAWEB_PASSWORD}"


[icinga2]
type                = "db"
db                  = "mysql"
host                = "${MYSQL_HOST}"
port                = "3306"
dbname              = "${MYSQL_ICINGA_DB}"
username            = "${MYSQL_ICINGA_USER}"
password            = "${MYSQL_ICINGA_PASSWORD}"


[director]
type                = "db"
db                  = "mysql"
host                = "${MYSQL_HOST}"
port                = "3306"
dbname              = "${MYSQL_DIRECTOR_DB}"
username            = "${MYSQL_DIRECTOR_USER}"
password            = "${MYSQL_DIRECTOR_PASSWORD}"
charset            = "utf8"
EOF
fi

# create /etc/icingaweb2/config.ini
if [[ ! -f /etc/icingaweb2/config.ini ]]; then
  echo "creating /etc/icingaweb2/config.ini"
  cat <<EOF > /etc/icingaweb2/config.ini
[logging]
log                 = "syslog"
level               = "ERROR"
application         = "icingaweb2"


[preferences]
type                = "db"
resource            = "icingaweb2"
EOF
fi

# create /etc/icingaweb2/authentication.ini
if [[ ! -f /etc/icingaweb2/authentication.ini ]]; then
  echo "creating /etc/icingaweb2/authentication.ini"
  cat <<EOF > /etc/icingaweb2/authentication.ini
[icingaweb2]
backend             = "db"
resource            = "icingaweb2"
EOF
fi

# create /etc/icingaweb2/roles.ini
if [[ ! -f /etc/icingaweb2/roles.ini ]]; then
  echo "creating /etc/icingaweb2/roles.ini"
  cat <<EOF > /etc/icingaweb2/roles.ini
[admins]
users               = "${ADMIN_USER}"
permissions         = "*"
EOF
fi

# create /etc/icingaweb2/modules/director/config.ini
if [[ ! -f /etc/icingaweb2/modules/director/config.ini ]]; then
  echo "creating /etc/icingaweb2/modules/director/config.ini"
  cat <<EOF > /etc/icingaweb2/modules/director/config.ini
[db]
resource = "${MYSQL_DIRECTOR_DB}"
EOF

  echo "creating /etc/icingaweb2/modules/director/kickstart.ini"
    cat <<EOF > /etc/icingaweb2/modules/director/kickstart.ini
[config]
endpoint               = "${ICINGA2_API_ENDPOINT}"
host                   = "${ICINGA2_HOST}"
port                   = 5665
username               = "${ICINGA2_API_USER}"
password               = "${ICINGA2_API_PASSWORD}"
EOF

  if /usr/share/icingaweb2/bin/icingacli module enable director; then
    echo "enabled director module"
    	else
	  >&2 echo "error enabling director module"
	  exit 1
  fi
  if /usr/share/icingaweb2/bin/icingacli director migration run; then
  echo "ran director migration"
  else
    >&2 echo "error running director migration"
    exit 1
  fi
  if /usr/share/icingaweb2/bin/icingacli director kickstart run; then
	echo "ran director kickstart"
	else
	  >&2 echo "error running director kickstart"
	  exit 1
  fi
fi

# create /etc/icingaweb2/modules/monitoring/config.ini
if [[ ! -f /etc/icingaweb2/modules/monitoring/config.ini ]]; then
  echo "creating /etc/icingaweb2/modules/monitoring/config.ini"
  cat <<EOF > /etc/icingaweb2/modules/monitoring/config.ini
[security]
protected_customvars = "*pw*,*pass*,community"
EOF
fi

# create /etc/icingaweb2/modules/monitoring/backends.ini
if [[ ! -f /etc/icingaweb2/modules/monitoring/backends.ini ]]; then
  echo "creating /etc/icingaweb2/modules/monitoring/backends.ini"
  cat <<EOF > /etc/icingaweb2/modules/monitoring/backends.ini
[icinga2]
type                = "ido"
resource            = "icinga2"
EOF
  /usr/share/icingaweb2/bin/icingacli module enable monitoring
  echo "enabled monitoring module"
fi

# create /etc/icingaweb2/modules/monitoring/commandtransports.ini
if [[ ! -f /etc/icingaweb2/modules/monitoring/commandtransports.ini ]]; then
  echo "copy ssh id to icinga2 container"
  sudo -u www-data sshpass -p "${ICINGA2_ROOT_PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no root@icinga2
  echo "creating /etc/icingaweb2/modules/monitoring/commandtransports.ini"
  cat <<EOF > /etc/icingaweb2/modules/monitoring/commandtransports.ini
[icinga2]
transport            = remote
path                 = /var/run/icinga2/cmd/icinga2.cmd
host                 = "${ICINGA2_HOST}"
;port                = 22 ; Optional. The default is 22
user                 = root
EOF
fi

# fix permission (othwerwise config can't be changed using the web interface)
chown -R www-data:icingaweb2 /etc/icingaweb2

# start apache2 in foreground
apache2-foreground
