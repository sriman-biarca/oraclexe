#!/bin/sh -e

sudo apt-get install alien libaio1 unixodbc
wget https://raw.githubusercontent.com/sriman-biarca/oraclexe/master/packages/oracle-xe-11.2.0-1.0.x86_64.rpm

cat > /sbin/chkconfig <<- "EOF"
#!/bin/bash
# Oracle 11gR2 XE installer chkconfig hack for Ubuntu
file=/etc/init.d/oracle-xe
if [[ ! `tail -n1 $file | grep INIT` ]]; then
echo >> $file
echo '### BEGIN INIT INFO' >> $file
echo '# Provides: OracleXE' >> $file
echo '# Required-Start: $remote_fs $syslog' >> $file
echo '# Required-Stop: $remote_fs $syslog' >> $file
echo '# Default-Start: 2 3 4 5' >> $file
echo '# Default-Stop: 0 1 6' >> $file
echo '# Short-Description: Oracle 11g Express Edition' >> $file
echo '### END INIT INFO' >> $file
fi
update-rc.d oracle-xe defaults 80 01
EOF

sudo chmod 755 /sbin/chkconfig

file2=/etc/sysctl.d/60-oracle.conf
if [[ ! `tail -n1 $file2 | grep shmmax` ]]; then
echo | sudo tee -a $file2
echo '# Oracle 11g XE kernel parameters' |  sudo tee -a $file2
echo 'fs.file-max=6815744' |  sudo tee -a $file2
echo 'net.ipv4.ip_local_port_range=9000 65000' |  sudo tee -a $file2
echo 'kernel.sem=250 32000 100 128' |  sudo tee -a $file2
echo 'kernel.shmmax=536870912' |  sudo tee -a $file2

#Load the kernel parameters
sudo service procps start

sudo ln -s /usr/bin/awk /bin/awk
mkdir /var/lock/subsys
touch /var/lock/subsys/listener

#Install the .deb file
sudo dpkg --install oracle-xe-11.2.0-1.0.x86_64.rpm

sudo rm -rf /dev/shm
sudo mkdir /dev/shm
sudo mount -t tmpfs shmfs -o size=3804m /dev/shm

cat > /etc/rc2.d/S01shm_load <<- "EOF"
#!/bin/sh
case "$1" in
start) mkdir /var/lock/subsys 2>/dev/null
touch /var/lock/subsys/listener
rm /dev/shm 2>/dev/null
mkdir /dev/shm 2>/dev/null
mount -t tmpfs shmfs -o size=3804m /dev/shm ;;
*) echo error
exit 1 ;;
esac
EOF

sudo chmod 755 /etc/rc2.d/S01shm_load

#Configuring Oracle 11g R2 Express Edition
sudo /etc/init.d/oracle-xe configure	


echo '#### for oracle 11g' | sudo tee -a /etc/bash.bashrc
echo 'export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe' | sudo tee -a /etc/bash.bashrc
echo 'export ORACLE_SID=XE' | sudo tee -a /etc/bash.bashrc
echo 'export NLS_LANG=`$ORACLE_HOME/bin/nls_lang.sh`' | sudo tee -a /etc/bash.bashrc
echo 'export ORACLE_BASE=/u01/app/oracle' | sudo tee -a /etc/bash.bashrc
echo 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH' | sudo tee -a /etc/bash.bashrc
echo 'export PATH=$ORACLE_HOME/bin:$PATH' | sudo tee -a /etc/bash.bashrc

source /etc/bash.bashrc
sudo service oracle-xe start

cat > create_user.txt <<- "EOF"
select host_name from v$instance;
create user user1234 identified by user1234;
select USERNAME from SYS.ALL_USERS;
EXIT
EOF

"$ORACLE_HOME/bin/sqlplus" SYSTEM/biarca123@"localhost/XE" @'create_user.txt'

