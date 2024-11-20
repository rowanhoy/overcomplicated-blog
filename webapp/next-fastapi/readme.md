set ACR_NAME acrovercomplicatedblogdev
set IMAGE_NAME next-fastapi
set TAG latest

az acr login --name $ACR_NAME
docker build -t next-fastapi .
docker tag $IMAGE_NAME:$TAG $ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG
docker push $ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG


docker run -p 8000:8000 next-fastapi