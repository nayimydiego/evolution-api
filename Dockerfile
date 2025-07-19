# ETAPA 1: Construcción
FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

COPY ./package.json ./tsconfig.json ./

RUN npm install --legacy-peer-deps

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./tsup.config.ts ./
COPY ./Docker ./Docker

# =================================================================
# === INICIO DEL BLOQUE DE CONFIGURACIÓN ===
# =================================================================
RUN echo "DATABASE_ENABLED=true" > ./.env && \
    echo "DATABASE_CONNECTION_PROVIDER=prisma-sqlite" >> ./.env && \
    echo "DATABASE_CONNECTION_URI=file:./dev.db" >> ./.env && \
    echo "SERVER_URL=https://api-whatsapp-nayim.onrender.com" >> ./.env && \
    echo "AUTHENTICATION_API_KEY=ApiNayim_Exito2025" >> ./.env
# ===============================================================
# === FIN DEL BLOQUE DE CONFIGURACIÓN ===
# ===============================================================

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

# ETAPA 2: Ejecución
FROM node:20-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=Europe/Madrid

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

ENV DOCKER_ENV=true

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
