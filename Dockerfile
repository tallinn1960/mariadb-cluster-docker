FROM mariadb:latest
RUN apt install mariadb-client galera-4
COPY 60-galera.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf
CMD /usr/sbin/mariadb