from fastapi import FastAPI

app = FastAPI(
    title="智能家居控制系统",
    description="一个用于控制智能家居和工业设备的 API",
    version="0.1.0",
)


@app.get("/")
async def root():
    return {"message": "欢迎使用智能家居控制系统"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
