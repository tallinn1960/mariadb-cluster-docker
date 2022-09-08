FROM mariadb:latest
RUN apt update && apt-get -y install galera-4 curl
COPY 60-galera.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf
CMD mariadb