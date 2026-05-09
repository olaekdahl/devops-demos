#!/usr/bin/env bash
ssh prod-vm-7
sudo apt-get install -y nginx
sudo vi /etc/nginx/sites-available/myapp
sudo systemctl restart nginx
# Result: nobody knows what's on prod-vm-7. Disaster on rebuild.
