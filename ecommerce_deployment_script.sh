#!/bin/bash
#
# Automate E-Commerce Application Deployment
# AUthor: Mohsinkamaal Mulla

############################################
# Print a message in a given color
# Arguments:
# Color e.g: green, red
############################################
function print_color() {
    NC='\033[0m' # No Color

    case $1 in
        "green") COLOR='\033[0;32m' ;;
        "red") COLOR='\033[0;31m' ;;
        "*")COLOR='\033[0m' ;;
    esac

    echo -e "${COLOR}" $2 "${NC}"
}


############################################
# Check if the service is active, If not active exit the script
# Arguments:
# Service e.g: firewalld, mariadb
############################################
function check_service_status() {
    is_service_active=$(sudo systemctl is-active $1)
    if [ $is_service_active = "active" ]
    then
        print_color "green" "$1 service is active"
    else
        print_color "red" "$1 service is not active"
        exit 1
    fi
}


############################################
# Check if the firewall rules are configured, if not exit the scriot
# Arguments:
# Port number e.g: 3306, 80
############################################
function is_firewalld_rule_configured() {
    firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports) 
    if [[ $firewalld_ports == *$1* ]]
    then
        print_color "green" "Port $1 is configured"
    else
        print_color "red" "Port $1 not configured"
        exit 1
    fi
}


############################################
# Check if the items exits on the web page
# Arguments:
# 1 - Web page
# 2 - Item
############################################
function check_item() {
    if [[ $1 = *$2* ]]
    then
        print_color "green" "Item $2 is present on the web page"
    else
        print_color "red" "Item $2 is not present on the web page"
    fi
}


print_color "green" "---------------- Setup Database Server ------------------"

# Install and configure firewalld
print_color "green" "Installing Firewall..."
sudo yum install -y firewalld

print_color "green" "Starting Firewall service..."
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Check FirewallD service is running
check_service_status firewalld

# -------------- Database Configuration ----------------
# Install and configure database
print_color "green" "Installing MariaDB..."
sudo yum install -y mariadb-server

print_color "green" "Starting MariaDB service..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Check MariaDB service is running
check_service_status mariadb

# Addd Firewalld rules for database
print_color "green" "Adding firewall rules for DB..."
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

# Check if firewalld rules configured for DB server
is_firewalld_rule_configured 3306

# Configure database server
print_color "green"ho "Configuring DB..."
cat > configure-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mysql < configure-db.sql

# Load inventory data into database
print_color "green" "Loading data into DB..."
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF

sudo mysql < db-load-script.sql

mysql_db_results=$(sudo mysql -e "use ecomdb; select * from products;")
if [[ $mysql_db_results == *Laptop* ]]
then
    print_color "green" "Inventory data loaded"
else
    print_color "red" "Inventory data not loaded"
    exit 1
fi

export DB_HOST=localhost
export DB_USER=ecomuser
export DB_PASSWORD=ecompassword
export DB_NAME=ecomdb

print_color "green" "---------------- Setup Database Server - Finished ------------------"

print_color "green" "---------------- Setup Web Server ------------------"

# -------------- Web Server Configuration ----------------
# Install Apache web server and PHP
print_color "green" "Installing Web server and PHP..."
sudo yum install -y httpd php php-mysqlnd

# Add firewalld rules for web server
print_color "green" "Adding firewall rules for web server..."
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

# Check if firewalld rules configured for Web server
is_firewalld_rule_configured 80

# # Update index.php
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Start and enable httpd service
print_color "green" "Starting httpd service..."
sudo systemctl start httpd
sudo systemctl enable httpd

# Check web service is running
check_service_status httpd

print_color "green" "---------------- Setup Web Server - Finished ------------------"

# Install Git and download the source code repository
print_color "green" "Cloning GIT repo..."
sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# Replace database IP with localhost
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

print_color "green" "All set..."

# Test Script
web_page=$(curl http://localhost)

for item in Laptop Drone VR Watch Phone
do
    check_item "$web_page" $item
done


