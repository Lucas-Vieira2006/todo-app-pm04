# Etapa 1: construção da aplicação React
FROM node:22-alpine AS build

WORKDIR /app

# Instala as dependências exatamente como estão no package-lock.json
COPY package*.json ./
RUN npm ci

COPY . .

# URL base da API; vazia = mesmo endereço da página
ARG REACT_APP_API_URL=""
ENV REACT_APP_API_URL=$REACT_APP_API_URL

RUN npm run build

# Etapa 2: Nginx servindo o build e encaminhando /todos para a API
FROM nginx:1.30-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY proxy_headers.inc /etc/nginx/conf.d/proxy_headers.inc
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
