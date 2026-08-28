FROM python:3.12-slim

WORKDIR /app

COPY requirements requirements
RUN pip install --no-cache-dir -r requirements

COPY . .

RUN mkdir -p /app/instance /app/data

EXPOSE 8001

CMD ["python", "app/server.py"]
