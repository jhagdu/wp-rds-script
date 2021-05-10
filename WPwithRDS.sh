#!/bin/bash

# Variable for AMI ID and Instance Type
ami_id='ami-045e6fa7127ab1ac4'
inst_type='t2.micro'
echo -e "\nAMI ID is set to $ami_id and Instance Type as $inst_type\n"

read -p "Database Name: " db_name
read -p "Database User: " db_user
read -p "Database Pass: " db_pass

# Getting VPC ID and Subnet ID
echo -e '\nWorking on Default VPC and Subnets'
vpc_id=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query Vpcs[0].VpcId --output text)
subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id --query  Subnets[1].SubnetId --output text)
echo -e 'To change VPC, Subnet, AMI or Instance Type, Change the Variables in the Script\n'

# Create Key Pair and Describe it
echo -e '\n\nCreating Key Pair...!!'
aws ec2 create-key-pair --key-name wpkey --query "KeyMaterial" --output text > wpkey.pem

# Create Security Group for Wordpress
echo -e '\nCreating Security Groups and Rules for WordPress Instance...!!'
aws ec2 create-security-group --group-name wpSG --description "Wordpress Security Group" --vpc-id $vpc_id > /dev/null
wp_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=wpSG --query SecurityGroups[0].GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $wp_sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $wp_sg_id --protocol tcp --port 80 --cidr 0.0.0.0/0

# Run Instance
echo -e '\nStarting and Configuring WordPress in EC2 Instance...!!'
inst_id=$(aws ec2 run-instances --security-group-ids $wp_sg_id --instance-type $inst_type --image-id $ami_id --key-name wpkey --subnet-id $subnet_id --count 1 --tag-specifications 'ResourceType=instance,Tags=[{Key=Env,Value=Wordpress}]' --user-data file://user-data.sh --query Instances[0].InstanceId --output text)

echo 'Waiting For Instance Running State...'
while true
do
	inst_state=$(aws ec2 describe-instances --instance-ids $inst_id --query Reservations[*].Instances[*].State.Name --output text) 
	if [ $inst_state == 'running' ]
	then
		break
	else
		continue
	fi
done

# Create Security Group for RDS
echo -e '\n\nCreating Security Groups and Rules for RDS...!!'
aws ec2 create-security-group --group-name dbSG --description "RDS Database Security Group" --vpc-id $vpc_id > /dev/null
rds_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=dbSG --query SecurityGroups[0].GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $rds_sg_id --protocol tcp --port 3306 --source-group $wp_sg_id

# Create RDS Instance
echo -e "Launching RDS Instance for WordPress...!!"
aws rds create-db-instance --engine "mysql" --engine-version "8.0.21" --db-instance-identifier "wpdbinstance" --db-name $db_name --master-username $db_user --master-user-password $db_pass --db-instance-class "db.t2.micro" --no-publicly-accessible --vpc-security-group-ids $rds_sg_id --port 3306 --allocated-storage 20 > /dev/null

echo -e 'Waiting For RDS Database Running State...'
while true
do
        rds_state=$(aws rds describe-db-instances --db-instance-identifier wpdbinstance --query DBInstances[0].DBInstanceStatus --output text)
        if [ $rds_state == 'backing-up' ]
        then
                break
        else
                continue
        fi
done

wp_pub_ip=$(aws ec2 describe-instances --instance-ids $inst_id --query Reservations[*].Instances[*].PublicIpAddress --output text)
rds_endpoint=$(aws rds describe-db-instances --db-instance-identifier wpdbinstance --query DBInstances[0].Endpoint.Address --output text)

#Open the Website
echo -e "\n\nPublic IP of WordPress Instane - $wp_pub_ip"
echo -e "\nDB Endpoint - $rds_endpoint"
start chrome $wp_pub_ip
