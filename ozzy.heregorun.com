#
#jefflee 2020.02.04
# add upstream for supporting websocket
#
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
upstream nodews {
  # Directs to the process with least number of connections
  #least_conn;
  server 127.0.0.1:8002 fail_timeout=20s;
}
upstream videostream {
  # Directs to the process with least number of connections
  #least_conn;
  server 127.0.0.1:8034 fail_timeout=20s;
}
upstream blacksquarevideo {
  server 192.168.25.185:1042 fail_timeout=20s;
}
upstream tinyvideo {
  server 192.168.25.190:1034 fail_timeout=20s;
}
upstream zmq0video {
  server 192.168.25.200:1034 fail_timeout=20s;
}
upstream zmq3video {
  server 192.168.25.136:1034 fail_timeout=20s;
}
upstream wdsite {
  server 192.168.25.175:80 fail_timeout=20s;
}
upstream pidesktop {
  server 192.168.25.160:80 fail_timeout=20s;
}
server {
 	listen 80 default_server ;
 	listen [::]:80 default_server ;
#disable 80 if needed
#  return 301 https://$host$request_uri;
  auth_basic           	"Ziggy Motion Area!";
  auth_basic_user_file /etc/nginx/.htpasswd;
  root /var/www/html;
  index index.html index.htm index.nginx-debian.html;
  server_name ozzy.heregorun.com; # managed by Certbot
  location / {
  #First attempt to serve request as file, then
  #as directory, then fall back to displaying a 404.
    try_files $uri $uri/ =404;
  }
  location /motion {
    root /mnt/pi/wrk/motion;
  }
  location /mp4files {
     root /mnt/pi/wrk/motion;
     autoindex on;
     autoindex_format xml;
     autoindex_localtime on;
     xslt_stylesheet /mnt/pi/wrk/SysEtc/superbindex.xslt;
  }
#redirect to microserver apache2 which serves php
#192.168.25.102 is host microserver
  location /ziggyp {
    proxy_pass http://192.168.25.102:8000;
  }
  #location ~ \.php$ {
  #  proxy_pass http://192.168.25.102:8000;
  #}
  location /blacksquarev {
    proxy_pass http://blacksquarevideo;
  }
  location /tinyv {
    proxy_pass http://tinyvideo;
  }
  location /zmq0v {
    proxy_pass http://zmq0video;
  }
  location /zmq3v {
    proxy_pass http://zmq3video;
  }
  location /nagios {
    auth_basic off;
    proxy_pass http://pidesktop;
  }
  location /wdhost {
    rewrite ^/wdhost(.*) $1 break;
    auth_basic off;
    proxy_pass http://wdsite;
  }

#for retriving mp4 files
  location /ziggy {
    proxy_pass http://192.168.25.102:80;
  }
# pass PHP scripts to FastCGI server
#  location ~ \.php$ {
#    include snippets/fastcgi-php.conf;
#    # With php-fpm (or other unix sockets):
#    fastcgi_pass unix:/run/php/php7.3-fpm.sock;
#    # With php-cgi (or other tcp sockets):
#    #fastcgi_pass 127.0.0.1:9000;
#  }
# deny access to .htaccess files, if Apache's document root
  location ~ /\.ht {
    deny all;
  }
  listen 443 ssl default_server ; # managed by Certbot
  ssl_certificate /etc/letsencrypt/live/ozzy.heregorun.com/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/ozzy.heregorun.com/privkey.pem; # managed by Certbot
  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}
