# qone-api-gateway: NGINX with the declarative configuration; the templates are rendered by
# the image's envsubst from the environment (GATEWAY_CORS_ORIGINS).
FROM nginx:1.27-alpine
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/templates/ /etc/nginx/templates/
COPY nginx/snippets/ /etc/nginx/snippets/
COPY nginx/routes/ /etc/nginx/routes/
ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/conf.d \
    GATEWAY_CORS_ORIGINS="http://localhost:5173"
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/health || exit 1
