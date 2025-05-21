import jwt
import time
import requests
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Service account details from environment variables
service_account_info = {
    "type": "service_account",
    "project_id": os.getenv('FIREBASE_PROJECT_ID'),
    "private_key_id": os.getenv('FIREBASE_PRIVATE_KEY_ID'),
    "private_key": os.getenv('FIREBASE_PRIVATE_KEY'),
    "client_email": os.getenv('FIREBASE_CLIENT_EMAIL'),
    "client_id": os.getenv('FIREBASE_CLIENT_ID'),
    "auth_uri": os.getenv('FIREBASE_AUTH_URI'),
    "token_uri": os.getenv('FIREBASE_TOKEN_URI'),
    "auth_provider_x509_cert_url": os.getenv('FIREBASE_AUTH_PROVIDER_CERT_URL'),
    "client_x509_cert_url": os.getenv('FIREBASE_CLIENT_CERT_URL'),
    "universe_domain": "googleapis.com"
}

def generate_jwt():
       now = int(time.time())
       expiry = now + 3600  # Token expires in 1 hour
       
       payload = {
           'iss': service_account_info['client_email'],
           'scope': 'https://www.googleapis.com/auth/cloud-language',
           'aud': service_account_info['token_uri'],
           'exp': expiry,
           'iat': now
       }
       
       signed_jwt = jwt.encode(
           payload,
           service_account_info['private_key'],
           algorithm='RS256'
       )
       
       return signed_jwt

def get_access_token():
       signed_jwt = generate_jwt()
       
       response = requests.post(
           service_account_info['token_uri'],
           data={
               'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
               'assertion': signed_jwt
           }
       )
       
       return response.json()['access_token']

if __name__ == '__main__':
       token = get_access_token()
       print(f"Access Token: {token}")


       