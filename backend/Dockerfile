FROM node:22-alpine

WORKDIR /app

# Instala somente as dependências de produção, conforme o package-lock.json
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Executa a API sem privilégios de root
USER node

EXPOSE 5000

CMD ["node", "index.js"]
