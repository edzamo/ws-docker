FROM ubuntu:latest

RUN apt update && apt install -y nginx
RUN echo 'hello world 2.0' > /var/www/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]