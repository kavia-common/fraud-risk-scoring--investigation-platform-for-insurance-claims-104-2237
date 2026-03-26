from fastapi import FastAPI
from pydantic import BaseModel
app = FastAPI()

class Health(BaseModel):
    status: str

@app.get("/health", response_model=Health)
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "BackendAPI FastAPI scaffold"}
