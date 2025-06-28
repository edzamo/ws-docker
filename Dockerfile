FROM ubuntu:20.04
RUN apt update
RUN apt install nginx -y
RUN echo 'hello world' > /var/www/html/index.html

CMD nginx -g 'daemon off;'