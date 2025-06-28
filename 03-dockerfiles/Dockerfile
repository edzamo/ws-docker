FROM ubuntu:20.04

RUN apt update && apt install -y nginx
RUN echo 'hello world' > /var/www/html/index.html

CMD ["nginx", "-g", "daemon off;"]