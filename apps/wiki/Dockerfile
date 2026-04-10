FROM nginx:alpine

# Remove default nginx page
RUN rm -rf /usr/share/nginx/html/*

# Copy MkDocs Material built site
COPY site/ /usr/share/nginx/html/

# nginx config: serve index.html for clean URLs (MkDocs uses directory structure)
RUN printf 'server {\n\
    listen 80;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ $uri/index.html =404;\n\
    }\n\
    # Disable nginx version in headers\n\
    server_tokens off;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
