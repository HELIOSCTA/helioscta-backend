import base64
import os
import requests
import time
from typing import List

import msal

from backend import (
    credentials,
)
# init logging
import logging
logging.basicConfig(level=logging.INFO)
logging.getLogger().handlers[0].setLevel(logging.INFO)

"""
"""

def _get_access_token():
    authority_url = f'https://login.microsoftonline.com/{credentials.AZURE_OUTLOOK_TENANT_ID}'
    app = msal.ConfidentialClientApplication(
        authority=authority_url,
        client_id=credentials.AZURE_OUTLOOK_CLIENT_ID,
        client_credential=credentials.AZURE_OUTLOOK_CLIENT_SECRET,
    )
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    if "access_token" in result:
        # print(f"Retrieved Access Token ...")
        return result['access_token']
    else:
        raise Exception("Failed to acquire token", result.get("error"), result.get("error_description"))


def _draft_attachment(file_path: str):
    if not os.path.exists(file_path):
        print('file is not found')
        return
    
    with open(file_path, 'rb') as upload:
        media_content = base64.b64encode(upload.read())
        
    data_body = {
        '@odata.type': '#microsoft.graph.fileAttachment',
        'contentBytes': media_content.decode('utf-8'),
        'name': os.path.basename(file_path)
    }
    return data_body


def send_outlook_email_with_attachments(
    sender_email_address,
    recipient_email_addresses,
    subject: str, 
    attachments: List = None,
    body: str = None, 
    body_type: str = "HTML",
    ) -> None:
        
    # get access token
    access_token = _get_access_token()
    logging.info(f"Got access token ...")
    
    for recipient_email_address in recipient_email_addresses:
        time.sleep(3)

        if attachments:
            email_payload = {
                "message": {
                    "subject": subject,
                    "body": {
                        "contentType": body_type,  # The email body can also be set to HTML
                        "content": body if body else None,
                    },
                    "toRecipients": [
                        {
                            "emailAddress": {
                                "address": recipient_email_address,
                            }
                        }
                    ],
                    'attachments': [_draft_attachment(attachment) for attachment in attachments] if attachments else None,
                }
            }
        else:
            email_payload = {
                "message": {
                    "subject": subject,
                    "body": {
                        "contentType": "HTML",  # The email body can also be set to HTML
                        "content": body if body else None,
                    },
                    "toRecipients": [
                        {
                            "emailAddress": {
                                "address": recipient_email_address,
                            }
                        }
                    ],
                }
            }

        # send email
        response = requests.post(
            f'https://graph.microsoft.com/v1.0/users/{sender_email_address}/sendMail', 
            json=email_payload,
            headers={'Authorization': f'Bearer {access_token}', 'Content-Type': 'application/json'},
        )
        
        if response.status_code == 202:
            logging.info(f"Email sent to {recipient_email_address} ... ")
        else:
            logging.error(f"Failed to send email. Status code: {response.status_code}")
            logging.error(response.json())
            raise Exception(f"Failed to send email. Status code: {response.status_code}")