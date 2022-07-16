#!/bin/bash

# install all the tools needed to setup the cluster
yum update -y
yum install awscli -y
yum install docker -y
yum install jq -y
yum install screen -y
yum install unzip -y
service docker start

# restrict docker containers from accessing to the EC2 metadata
iptables --insert DOCKER-USER --destination 169.254.169.254 --jump REJECT

