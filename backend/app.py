from flask import Flask, jsonify
import redis
import os

app = Flask(__name__)

redis_client = redis.Redis(
    host=os.environ.get('REDIS_HOST', 'localhost'),
    port=6379,
    decode_responses=True
)

@app.route('/api/visit', methods=['POST'])
def visit():
    count = redis_client.incr('visitor_count')
    return jsonify({'count': count})

@app.route('/api/count', methods=['GET'])
def get_count():
    count = redis_client.get('visitor_count') or 0
    return jsonify({'count': int(count)})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
