import os
import json
import logging
import requests

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

from azure import functions as func
from datetime import datetime
from datetime import timedelta

## Getting host pool registration token
def main(event: func.EventGridEvent):
    logging.info('Event received. Parsing it.')
    try:
        now = datetime.now()
        logging.info('Starting at %s', now)

        # Gathering data from event and defining some
        vault_name = event.get_json().get('vaultName')
        vault_url = f'https://{vault_name}.vault.azure.net'
        resource_group_name = event.topic.split('/')[4]
        subscription_id = event.topic.split('/')[2]
        host_pool_name = event.subject
        expiration_time = now + timedelta(days=7)
        url = f'https://management.azure.com/subscriptions/{subscription_id}/resourceGroups/{resource_group_name}/providers/Microsoft.DesktopVirtualization/hostPools/{host_pool_name}?api-version=2019-12-10-preview'
        head = ''
        payload = {
            'properties': {
                "registrationInfo": {
                "expirationTime": expiration_time.isoformat(),
                "registrationTokenOperation": "Update"
                }
            }
        }

        logging.info('Generating registration token for host pool: %s ', host_pool_name)

        # Generating a new registration token
        response = requests.patch(url, json=payload, headers=head)
        print(response.text)
        registration_token = ''

        # logging.info('Storing registration token in secret named: %s ', host_pool_name)

        # # Acquiring credential and client object and set secret value
        # credential = DefaultAzureCredential()
        # secret_client = SecretClient(vault_url=vault_url, credential=credential)
        # secret_client.set_secret(host_pool_name, registration_token, expires_on=expiration_time)

        # logging.info('A registration token for %s has been created successfully.', host_pool_name)
    except Exception as err:
        logging.error("Error occured: {0}".format(err))

    logging.info('End of execution.')

## End of getting host pool registration token