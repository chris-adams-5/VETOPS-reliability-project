import os
import json
import time
import urllib.request
import urllib.error
import redis 


redis_endpoint = os.environ.get('REDIS_ENDPOINT')
cache = redis.Redis(host=redis_endpoint, port=6379, decode_responses=True)

def lambda_handler(event, context):
    
    http_method = event.get("httpMethod")

    if http_method == "GET":
        return get_cache(event)
    
    if http_method == "POST":
        post_print_body(event)
        return post_try_again(event)


def get_cache(event):

    path = event.get('path', '/')
    
    vendor_backend = os.environ.get('VENDOR_BACKEND_URL')
        
    try:
        cached_data = cache.get(path)
    
        if cached_data:
            return format_alb_response(200, cached_data, "HIT")
            
        vendor_url = f"{vendor_backend}{path}"
        auth_header = os.environ.get('VENDOR_AUTH_HEADER')
        
        req_headers = {
            "Authorization": auth_header,
            "User-Agent": "VetOp-Cache-Middleware/1.0",
            "Accept": "application/json"
        }
        
        req = urllib.request.Request(vendor_url, headers=req_headers, method="GET")
        
        with urllib.request.urlopen(req) as response:
            live_data = response.read().decode('utf-8')
            status_code = response.getcode()
            
            if status_code == 200:
                cache.setex(path, 300, live_data)
                
            return format_alb_response(status_code, live_data, "MISS")
        


    except urllib.error.HTTPError as err:
        # Handles 400, 404, 503, etc., and forwards the real backend response
        error_body = err.read().decode('utf-8')
        return format_alb_response(err.code, error_body, "MISS")
        
    except Exception as e:
        # Handles everything else
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


def post_try_again(event):
    
    # ip address of the ec2 instance
    target_url = os.environ.get('VENDOR_BACKEND_URL')
    auth_header = os.environ.get('VENDOR_AUTH_HEADER')
    
    http_method = event.get("httpMethod")
    body = event.get("body", "")
    path = event.get("path", "/")

    
    req_headers = {
            "Authorization": auth_header,
            "User-Agent": "post-retry/1.0",
            "Accept": "application/json",
            "Content-Type": "application/json"
        }

    
    # the alb send a text string to lambdas but the server expects bits
    req_body = body.encode('utf-8') if body else None
    
    no_attempts = 2
    
    for attempt_index in range(no_attempts):
        attempt_number = attempt_index + 1
        
        if attempt_number > 1:
            print("Waiting 0.25 second before retrying...")
            time.sleep(0.25)
        
        try:
            req = urllib.request.Request(
                f"{target_url}{path}", 
                data=req_body, 
                headers=req_headers, 
                method=http_method
            )
            
            with urllib.request.urlopen(req) as response:
                response_body = response.read().decode('utf-8')
                print(f"Success on attempt {attempt_number}. Status code: {response.getcode()}")
                
                return {
                  "statusCode": response.getcode(),
                  "statusDescription": f"{response.getcode()} OK",
                  "isBase64Encoded": False,
                  "headers": dict(response.headers),
                  "body": response_body
                  }
                
        except urllib.error.HTTPError as e:
            
            # try again if it's not the last try
            if e.code == 500 and attempt_number < no_attempts:
                  print("Received a 500 Internal Server Error. Retrying request...")
                  continue  # Loop back up and try one more time
                
            # return other status codes
            try:
                err_body = e.read().decode('utf-8')
            except Exception:
                err_body = json.dumps({"error": f"Target returned HTTP status {e.code}"})
            
            #return 500s after one try
            if e.code == 500:
                
                print("Received a 500 on the second attempt. Giving up.")
                
                return {
                    "statusCode": e.code,
                    "statusDescription": f"{e.code} {err_body[23:-2]}",
                    "isBase64Encoded": False,
                    "headers": dict(e.headers),
                    "body": err_body
                    }
            if e.code >= 400 and e.code < 500:
             
                return {
                    "statusCode": e.code,
                    "statusDescription": f"{e.code} {err_body[23:-2]}",
                    "isBase64Encoded": False,
                    "headers": dict(e.headers),
                    "body": err_body
                    }
                
        except Exception as e:
            
            # if it's one error try again
            if attempt_number < no_attempts:
                print("Retrying due to network failure...")
                continue
        
            print(f"Network error on attempt {attempt_number}: {str(e)}")
  
            return {
                    "statusCode": 502,
                    "statusDescription": "502 Bad Gateway",
                    "isBase64Encoded": False,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": f"Failed to connect to target system: {str(e)}"})
                }
        
  # catch everything else
    return {
        "statusCode": 500,
        "body": json.dumps({"error": "Unexpected retry loop termination"})
    }
   

def post_print_body(event):
    body = event.get("body", "")
    print(body)

    headers = event.get("headers", {})
    print(headers)
