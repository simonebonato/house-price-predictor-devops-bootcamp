FROM python:3.9-slim

WORKDIR /app

COPY . .

RUN <<EOF
pip install uv
uv pip install --system -r requirements.txt
EOF

EXPOSE 8501

CMD [ "streamlit", "run", "app.py", "--server.address=0.0.0.0" ]