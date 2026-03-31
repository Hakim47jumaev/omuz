# Docker quick start

This setup dockerizes the Django backend (`omuzapi`) and keeps Flutter on host machine.

## 1) Prerequisites

- Docker Desktop installed and running

## 2) Start backend

From project root:

```bash
docker compose up --build
```

API will be available at:

- `http://127.0.0.1:8000`
- `http://127.0.0.1:8000/api/v1`

## 3) Stop backend

```bash
docker compose down
```

## 4) Flutter connection notes

- If you run on a physical Android device, use your PC local IP in `API_BASE_URL` (not `127.0.0.1`).
- If you run on Android emulator, use `10.0.2.2` as host.

Examples:

- Emulator: `http://10.0.2.2:8000/api/v1`
- Physical device: `http://<your-pc-ip>:8000/api/v1`
