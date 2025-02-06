from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.request
import os

class ProducerHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Read the request body
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = json.loads(post_data.decode('utf-8'))
        
        # Prepare data to send to consumer
        payload = json.dumps({
            'message': 'Event from producer',
            'data': data
        }).encode('utf-8')
        
        # Get consumer URL from environment variable
        consumer_url = os.getenv('CONSUMER_URL', 'http://consumer.default.svc.cluster.local')
        
        # Send request to consumer
        req = urllib.request.Request(
            consumer_url,
            data=payload,
            headers={'Content-Type': 'application/json'}
        )
        
        try:
            with urllib.request.urlopen(req) as response:
                consumer_response = response.read().decode('utf-8')
                
            # Send response back
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response_data = {
                'status': 'success',
                'consumer_response': consumer_response
            }
            self.wfile.write(json.dumps(response_data).encode('utf-8'))
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode('utf-8'))

def main(server_class=HTTPServer, handler_class=ProducerHandler, port=50050):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f'Starting producer server on port {port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    main()
