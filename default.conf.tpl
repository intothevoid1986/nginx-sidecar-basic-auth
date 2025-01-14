# Upstream
upstream backend {
    server {{ .Env.FORWARD_HOST }}:{{ .Env.FORWARD_PORT }} max_fails=0;
}

{{ if .Env.ENABLE_CACHE }}
proxy_cache_path /tmp/cache keys_zone=cache:10m levels=1:2 inactive=600s max_size=100m;
{{ end }}


# WS Handling
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}


# Server Definition
server {
    listen {{ .Env.PORT }};
    proxy_busy_buffers_size   512k;
    proxy_buffers   4 512k;
    proxy_buffer_size   256k;
{{ if .Env.WEBSOCKET_PATH }}
    location {{ .Env.WEBSOCKET_PATH }} {
        proxy_pass http://backend{{ .Env.FORWARD_WEBSOCKET_PATH | default "" }};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        proxy_read_timeout {{ .Env.PROXY_READ_TIMEOUT }};
        proxy_send_timeout {{ .Env.PROXY_SEND_TIMEOUT }};
    }
{{ end }}

    location / {

        # Basic Auth
        limit_except OPTIONS {
            auth_basic "Restricted";
            auth_basic_user_file "auth.htpasswd";
        }

        # Proxy
        proxy_redirect      off;
        proxy_set_header    Host $host;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Host $server_name;
        proxy_set_header    X-Forwarded-Proto https;
        proxy_set_header    X-Forwarded-Port 443;

        proxy_pass http://backend;
        proxy_read_timeout {{ .Env.PROXY_READ_TIMEOUT }};
        proxy_send_timeout {{ .Env.PROXY_SEND_TIMEOUT }};
        client_max_body_size {{ .Env.CLIENT_MAX_BODY_SIZE }};
        proxy_request_buffering {{ .Env.PROXY_REQUEST_BUFFERING }};
        proxy_buffering {{ .Env.PROXY_BUFFERING }};

{{ if .Env.ENABLE_CACHE }}
        proxy_cache cache;
        # proxy_cache_purge $purge_method;
        proxy_cache_valid 200 30s;
        proxy_cache_lock on;
        proxy_cache_use_stale updating;
{{ end }}
    }
    
    location /health {
        access_log off;
        add_header 'Content-Type' 'text/plain';
        return 200 "healthy\n";
    }
}
