FROM mongo:8.0

# Script de criação do usuário da aplicação e dados iniciais
COPY ./init-mongo.js ./seed.json /docker-entrypoint-initdb.d/

EXPOSE 27017
