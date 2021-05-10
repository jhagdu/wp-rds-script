#!/bin/bash

sudo yum install httpd mysql php-mysqlnd wget -y > /dev/null 
sudo amazon-linux-extras install php7.3 -y > /dev/null
sudo systemctl start httpd
wget http://wordpress.org/latest.tar.gz  > /dev/null
tar -xzf latest.tar.gz  > /dev/null
sudo cp -rf wordpress/* /var/www/html/
sudo chown -R apache:apache /var/www/html/*
