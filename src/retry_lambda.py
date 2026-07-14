
import json
import time
import urllib.request
import urllib.error

def lambda_handler(event, context):
    
    # ip address of the ec2 instance
    target_url = "http://18.134.210.167"
    
    http_method = event.get("httpMethod", "GET")
    headers = event.get("headers", {})
    body = event.get("body", "")
    
    # Filter out host headers to avoid routing confusion on the target
    headers = {k: v for k, v in headers.items() if k.lower() not in ["host", "connection"]}
    
    # Encode the body to bytes if a payload exists (POST/PUT requests)
    req_data = body.encode('utf-8') if body else None
    
    no_attempts = 2
    
    for attempt_index in range(no_attempts):
        attempt_number = attempt_index + 1

        if attempt_number > 1:
            print("Waiting 0.5 second before retrying...")
            time.sleep(0.5)
        
        try:
            
            req = urllib.request.Request(
                target_url, 
                data=req_data, 
                headers=headers, 
                method=http_method
            )
            
            with urllib.request.urlopen(req, timeout=5) as response:
                response_body = response.read().decode('utf-8')
                print(f"Success on attempt {attempt_number}. Status code: {response.status}")
                
                return {
                  "statusCode": response.status,
                  "statusDescription": f"{response.status} OK",
                  "isBase64Encoded": False,
                  "headers": dict(response.headers),
                  "body": response_body
                  }
                
        except urllib.error.HTTPError as e:
            print(f"HTTP Error received: {e.code}")
            
            if e.code == 500 and attempt_number < no_attempts:
                  print("Received a 500 Internal Server Error. Retrying request...")
                  continue  # Loop back up and try one more time
                
            # if its any other error (like 400, 404, 403), return it immediately
            try:
                err_body = e.read().decode('utf-8')
            except Exception:
                err_body = json.dumps({"error": f"Target returned HTTP status {e.code}"})
            
            if e.code == 500:
                 print("Received a 500 on the second attempt. Giving up.")

                #return 500 error
            return {
                "statusCode": e.code,
                "statusDescription": f"{e.code} Error",
                "isBase64Encoded": False,
                "headers": dict(e.headers),
                "body": err_body
                }  
                
        except Exception as e:
            
            # If it's a connection/network issue and we have an attempt left, retry
            if attempt_number < no_attempts:
                print("Retrying due to network failure...")
                continue
        
            # network level drops, DNS errors, or connection timeouts?
            print(f"Network error on attempt {attempt_number}: {str(e)}")
  
            return {
                "statusCode": 502,
                "statusDescription": "502 Bad Gateway",
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"Failed to connect to target system: {str(e)}"})
            }
  # Fallback response just in case the execution breaks out of the loop cleanly
    return {
        "statusCode": 500,
        "body": json.dumps({"error": "Unexpected retry loop termination"})
    }
   

