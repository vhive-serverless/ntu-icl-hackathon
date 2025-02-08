from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class ConsumerHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Read the request body
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = json.loads(post_data.decode('utf-8'))
        
        # Process the received data
        print(f'Received data: {data}')
        
        # Send response
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {
            'status': 'processed',
            'received_data': data
        }
        self.wfile.write(json.dumps(response).encode('utf-8'))

def main(server_class=HTTPServer, handler_class=ConsumerHandler, port=50051):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f'Starting consumer server on port {port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    main()
