from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

# API Endpoints
@app.get("/")
async def root():
    return JSONResponse(content={"message": "Hello from FastAPI Backend!"})