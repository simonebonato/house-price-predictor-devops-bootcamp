FROM python:3.11-slim

WORKDIR /app

COPY src/api .
COPY models/trained/*.pkl ./models/trained/


RUN <<EOF
pip install uv
uv pip install --system -r requirements.txt
EOF

EXPOSE 8000

# The line below sets the default command to launch the FastAPI application
# using 'uvicorn', an ASGI server designed for fast performance with async Python web apps.
# 'uvicorn' is responsible for serving the FastAPI app (main:app) and handling incoming HTTP requests.
# The '--host 0.0.0.0' makes the server accessible externally (not just from localhost),
# and '--port 8000' tells uvicorn to listen on port 8000.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]