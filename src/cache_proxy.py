import os
import json
import urllib.request
import redis # pyright: ignore[reportMissingImports]

# initialise redis

redis_endpoint = os.environ.get('REDIS_ENDPOINT')
cache = redis.Redis(host=redis_endpoint, port=6379, decode_responses=True)

def lambda_handler(event, context):

    # extract the URL path from  ALB event (eg '/staffs/42')
    path = event.get('path', '/')
    
    vendor_backend = os.environ.get('VENDOR_BACKEND_URL')
    
    try:
        # check Elasticache 
        cached_data = cache.get(path)
        
        if cached_data:
            # if data is there return it straight away
            return format_alb_response(200, cached_data, "HIT")
            
        # if data isnt in cache get it from the backend
        vendor_url = f"{vendor_backend}{path}"
        
        # pull the auth secret from the lambda environment
        auth_header = os.environ.get('VENDOR_AUTH_HEADER')
        
        # inject the required authentication and a standard user-agent
        req_headers = {
            "Authorization": auth_header,
            "User-Agent": "VetOp-Cache-Middleware/1.0"
        }
        
        req = urllib.request.Request(vendor_url, headers=req_headers, method="GET")
        
        with urllib.request.urlopen(req) as response:
            live_data = response.read().decode('utf-8')
            status_code = response.getcode()
            
            # save data to cache with a 300 second limit
            if status_code == 200:
                cache.setex(path, 300, live_data)
                
            # return data to alb
            return format_alb_response(status_code, live_data, "MISS")
            
    except Exception as e:
        # errors
        print(f"Middleware Error: {str(e)}")
        error_body = json.dumps({"error": "Internal Cache Middleware Error"})
        return format_alb_response(500, error_body, "ERROR")

def format_alb_response(status_code, body, cache_status):
    """
    formats response for AWS App load balancer
    """
    return {
        "isBase64Encoded": False,
        "statusCode": status_code,
        "statusDescription": f"{status_code} OK" if status_code == 200 else f"{status_code} Error",
        "headers": {
            "Content-Type": "application/json",
            "X-Cache": cache_status  # custom header so it can be checked in chrome etc
        },
        "body": body
    }
