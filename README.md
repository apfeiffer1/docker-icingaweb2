# Icinga2
This set of docker containers can be used to run Icinga2 - https://www.icinga.org/products/icinga-2/  
The existing docker setups put several processes (like icinga2, icingaweb2, sometimes mysql) into one single container.
I split these roles into several containers for better (re-)usability. It also makes it possible to run multiple icinga2 nodes + one single icingaweb2 interface.

The Icingaweb2 container also contains the director module - https://github.com/Icinga/icingaweb2-module-director  

Please note that this setup and director are in alpha state, don't use for production.

## Usage
### Basic Usage
docker run --name my-mariadb -e MYSQL_ROOT_PASSWORD=my-secret -d mariadb  
docker run --name my-icinga2 -h icinga2 --link my-mariadb:mysql -d rbicker/icinga2  
docker run --name my-icingaweb2 -h icingaweb2 -v icinga2-config:/etc/icinga2 -v icinga2-lib:/var/lib/icinga2  --link my-mariadb:mysql --link my-icinga2:icinga2 -p 8080:80 -d rbicker/icingaweb2  

Browse to http://localhost:8080  

## Environment variables
### rbicker/icinga2
MYSQL_ICINGA_DB icinga2 - name of the icinga2 database  
MYSQL_ICINGA_USER icinga2 - icinga2 database user  
MYSQL_ICINGA_PASSWORD icinga2 - icinga2 database password  
API_USER api - api user (used by icingaweb2 -> director)  
API_PASSWORD api password

### rbicker/icingaweb2
MYSQL_ICINGAWEB_DB icingaweb2 - name of the icingaweb2 database  
MYSQL_ICINGAWEB_USER icingaweb2 - icingaweb2 database user  
MYSQL_ICINGAWEB_PASSWORD icingaweb2 - icingaweb2 database password  

MYSQL_DIRECTOR_DB director - name of the director database
MYSQL_DIRECTOR_USER director - name of the director database user  
MYSQL_DIRECTOR_PASSWORD director - director database user password 

ADMIN_USER admin - icingaweb2 frontend username  
ADMIN_PASSWORD admin - icingaweb2 frontend password  

## roadmap
The goal is to create a production ready set of docker containers for icinga2, icingaweb2, director plugin.