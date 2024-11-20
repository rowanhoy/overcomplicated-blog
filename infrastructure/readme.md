terraform -chdir=infrastructure/200-platform init -backend-config='backend-dev.config'
terraform -chdir=infrastructure/200-platform plan -var="environment=dev" -var="cloudflare_api_token=$CLOUDFLARE_TOKEN"
terraform -chdir=infrastructure/200-platform apply -var="environment=dev" -var="cloudflare_api_token=$CLOUDFLARE_TOKEN"