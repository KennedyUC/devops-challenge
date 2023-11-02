from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os
from dotenv import load_dotenv
from prometheus_client import Counter, start_http_server

# Load environment variables from .env file during development
load_dotenv()

app = Flask(__name__)
CORS(app)

# Define the metrics
request_counter = Counter('http_requests_total', 'Total HTTP Requests', ['method', 'status'])

ZONE_ID = os.getenv('ZONE_ID')
CF_API_KEY = os.getenv('CF_API_KEY')
CF_API_EMAIL = os.getenv('CF_API_EMAIL')
API_URL = f'https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records'

@app.route('/', methods=['GET'])
def proxy():
    headers = {
        'X-Auth-Email': CF_API_EMAIL,
        'X-Auth-Key': CF_API_KEY,
        'Content-Type': 'application/json'
    }

    try:
        response = requests.request(
            method='GET',
            url=API_URL,
            headers=headers
        )
        # Increment the request counter for successful requests
        request_counter.labels(method='GET', status=response.status_code).inc()
    except Exception as e:
        # Increment the request counter for failed requests
        request_counter.labels(method='GET', status='error').inc()
        return jsonify({'error': str(e)}), 500

    return response.json()

if __name__ == '__main__':
    # Start the servers
    start_http_server(8000)
    app.run(host='0.0.0.0', port=5000)