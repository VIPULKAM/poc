 sudo yum update -y 
 sudo yum install postgresql-server postgresql-contrib -y
 sudo postgresql-setup --initdb
 systemctl start postgresql.service
 sudo systemctl enable postgresql.service
 systemctl status postgresql.service
  
