FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci && \
    if [ -f node_modules/rollup/package.json ]; then \
      case "$(uname -m)" in x86_64) rollup_arch=x64 ;; aarch64) rollup_arch=arm64 ;; *) exit 1 ;; esac; \
      rollup_version=$(node -p "require('./node_modules/rollup/package.json').version"); \
      npm install --no-save "@rollup/rollup-linux-${rollup_arch}-musl@${rollup_version}"; \
    fi
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY deploy-nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
