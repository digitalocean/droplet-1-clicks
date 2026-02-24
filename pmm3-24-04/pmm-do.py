#!/usr/bin/env python

"""
This script adds DigitalOcean DBaaS instances to a Percona Monitoring and Management 
(PMM) host running on the local server. Supports MySQL, PostgreSQL, and MongoDB DBaaS instances.

Updated for PMM v3 API:
- Updated list services endpoint to use /v1/management/services (GET)
- Service creation uses /v1/management/services with correct payload format
- Updated payload format to match PMM v3 management API structure
- Added Python 2/3 compatibility
- Enhanced error handling for PMM v3 response format
- Added support for PostgreSQL and MongoDB in addition to MySQL
"""

from __future__ import print_function
import os
import sys
import argparse
import pprint
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from random import choice
from string import ascii_letters, digits

# Python 2/3 compatibility
try:
    input = raw_input
except NameError:
    pass


class PmmServer:
    def __init__(self, baseURL="https://127.0.0.1:443", serverAdminPassword=None):
        self.baseURL = baseURL
        self.password = serverAdminPassword
    
    def listServices(self):
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

        # Updated endpoint for PMM v3 management API
        endpoint = self.baseURL + "/v1/management/services"
        try:
            r = requests.get(endpoint, verify=False, auth=('admin', self.password))
            r.raise_for_status()
        except requests.exceptions.HTTPError as e:
            if r.status_code == 401:
                print("Invalid PMM admin password.")
            else:
                jsonResponse = r.json()
                print(jsonResponse.get('message', 'HTTP Error occurred'))
            sys.exit(1) 
        except requests.exceptions.RequestException as e:
            print('Could not connect to PMM instance at {}'.format(self.baseURL))
            sys.exit(1)
    
        return r.json()
    
    def addMySQL(self, mysqlInstance, digitalocean_api_token=None):
        """
        Given a dict representing a DBaaS MySQL instance, add it to PMM using PMM v3 management API
        """
        print("Adding MySQL instance {} to PMM...".format(mysqlInstance.name))
    
        if not mysqlInstance.createMonitoringUser(digitalocean_api_token):
            print("Failed to create monitoring user for MySQL instance {}. Skipping...".format(mysqlInstance.name))
            return
        
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

        # Use PMM v3 management API format for services
        body = {
            "mysql": {
                "metricsParameters": "manually",
                "schema": "https",
                "pmm_agent_id": "pmm-server",
                "port": str(mysqlInstance.port),
                "qan_mysql_perfschema": True,
                "disable_comments_parsing": True,
                "tablestatOptions": "disabled",
                "tablestats_group_table_limit": -1,
                "address": mysqlInstance.address,
                "username": mysqlInstance.monitoring_username,
                "password": mysqlInstance.monitoring_password,
                "environment": mysqlInstance.region,
                "cluster": mysqlInstance.region,
                "service_name": mysqlInstance.name,
                "add_node": {
                    "node_name": mysqlInstance.name + "-node",
                    "node_type": "NODE_TYPE_REMOTE_NODE"
                },
                "metrics_mode": 1,
                "custom_labels": {
                    "source": "digitalocean",
                    "region": mysqlInstance.region
                }
            }
        }
        
        # Use the management services endpoint in PMM v3
        addURL = self.baseURL + "/v1/management/services"
        try:
            r = requests.post(addURL, json=body, verify=False, auth=('admin', self.password))
            r.raise_for_status()
            print("Successfully added {} to PMM".format(mysqlInstance.name))
        except requests.exceptions.HTTPError:
            jsonResponse = r.json()
            if r.status_code == 409:
                # Service already exists
                print("Service '{}' already exists: {}".format(mysqlInstance.name, jsonResponse.get('message', 'Conflict')))
            else:
                print("Error adding service '{}': {}".format(mysqlInstance.name, jsonResponse.get('message', 'Unknown error')))
        except Exception as err:
            print("Error adding service '{}': {}".format(mysqlInstance.name, err))
    
        return

    def addPostgreSQL(self, pgInstance, digitalocean_api_token=None):
        """
        Given a dict representing a DBaaS PostgreSQL instance, add it to PMM using PMM v3 management API
        """
        print("Adding PostgreSQL instance {} to PMM...".format(pgInstance.name))
    
        if not pgInstance.createMonitoringUser(digitalocean_api_token):
            print("Failed to create monitoring user for PostgreSQL instance {}. Skipping...".format(pgInstance.name))
            return
        
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

        # Use PMM v3 management API format for PostgreSQL services
        body = {
            "postgresql": {
                "metricsParameters": "manually",
                "schema": "https",
                "pmm_agent_id": "pmm-server",
                "port": str(pgInstance.port),
                "disable_comments_parsing": True,
                "autoDiscoveryOptions": "enabled",
                "autoDiscoveryLimit": 10,
                "maxConnectionLimitOptions": "disabled",
                "maxExporterConnections": None,
                "address": pgInstance.address,
                "database": "defaultdb",
                "username": pgInstance.monitoring_username,
                "password": pgInstance.monitoring_password,
                "tls": True,
                "tls_skip_verify": True,
                "service_name": pgInstance.name,
                "add_node": {
                    "node_name": pgInstance.name + "-node",
                    "node_type": "NODE_TYPE_REMOTE_NODE"
                },
                "metrics_mode": 1
            }
        }
        
        # Use the management services endpoint in PMM v3
        addURL = self.baseURL + "/v1/management/services"
        try:
            r = requests.post(addURL, json=body, verify=False, auth=('admin', self.password))
            r.raise_for_status()
            print("Successfully added {} to PMM".format(pgInstance.name))
        except requests.exceptions.HTTPError:
            jsonResponse = r.json()
            if r.status_code == 409:
                # Service already exists
                print("Service '{}' already exists: {}".format(pgInstance.name, jsonResponse.get('message', 'Conflict')))
            else:
                print("Error adding service '{}': {}".format(pgInstance.name, jsonResponse.get('message', 'Unknown error')))
        except Exception as err:
            print("Error adding service '{}': {}".format(pgInstance.name, err))
    
        return

    def addMongoDB(self, mongoInstance, digitalocean_api_token=None):
        """
        Given a dict representing a DBaaS MongoDB instance, add it to PMM using PMM v3 management API
        """
        print("Adding MongoDB instance {} to PMM...".format(mongoInstance.name))
    
        if not mongoInstance.createMonitoringUser(digitalocean_api_token):
            print("Failed to create monitoring user for MongoDB instance {}. Skipping...".format(mongoInstance.name))
            return
        
        requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

        # Use PMM v3 management API format for MongoDB services
        body = {
            "mongodb": {
                "metricsParameters": "manually",
                "schema": "https",
                "pmm_agent_id": "pmm-server",
                "port": str(mongoInstance.port),
                "address": mongoInstance.address,
                "username": mongoInstance.monitoring_username,
                "password": mongoInstance.monitoring_password,
                "environment": mongoInstance.region,
                "custom_labels": {
                    "source": "digitalocean",
                    "region": mongoInstance.region
                },
                "service_name": mongoInstance.name,
                "add_node": {
                    "node_name": mongoInstance.name + "-node",
                    "node_type": "NODE_TYPE_REMOTE_NODE"
                },
                "metrics_mode": 1
            }
        }
        
        # Use the management services endpoint in PMM v3
        addURL = self.baseURL + "/v1/management/services"
        try:
            r = requests.post(addURL, json=body, verify=False, auth=('admin', self.password))
            r.raise_for_status()
            print("Successfully added {} to PMM".format(mongoInstance.name))
        except requests.exceptions.HTTPError:
            jsonResponse = r.json()
            if r.status_code == 409:
                # Service already exists
                print("Service '{}' already exists: {}".format(mongoInstance.name, jsonResponse.get('message', 'Conflict')))
            else:
                print("Error adding service '{}': {}".format(mongoInstance.name, jsonResponse.get('message', 'Unknown error')))
        except Exception as err:
            print("Error adding service '{}': {}".format(mongoInstance.name, err))
    
        return

class DbaasInstance:

    def __init__(self, instanceAttributes, pmmServer):
        self.name = instanceAttributes['name']
        self.id = instanceAttributes['id']  # Store the database ID for API calls
        self.region = instanceAttributes['region']
        self.address = instanceAttributes['connection']['host']
        self.port = instanceAttributes['private_connection']['port']
        self.admin_username = instanceAttributes['private_connection']['user']
        # Handle cases where password might not be in private_connection (e.g., MongoDB)
        self.admin_password = instanceAttributes['private_connection'].get('password') or instanceAttributes['connection'].get('password', '')
        self.engine = instanceAttributes['engine']
        self.monitored = self.instanceMonitored(pmmServer)

    
    def generatePassword(self):
        password = ''.join([choice(ascii_letters + digits)
                    for n in range(32)])
        return password
    
    def createMonitoringUser(self, digitalocean_api_token=None):
        if digitalocean_api_token:
            if self.engine == 'mongodb':
                return self.createMongoDBUser(digitalocean_api_token)
            elif self.engine == 'mysql':
                return self.createMySQLUser(digitalocean_api_token)
            elif self.engine == 'pg':
                return self.createPostgreSQLUser(digitalocean_api_token)
        
        # Fallback to local credentials if no API token
        self.monitoring_username = 'pmm'
        self.monitoring_password = self.generatePassword()
        return True
    
    def createMongoDBUser(self, digitalocean_api_token):
        """
        Create a MongoDB monitoring user via DigitalOcean API
        """
        try:
            user_input = input('Do you want to create a monitoring user for MongoDB instance "{}"? [y/N]: '.format(self.name))
        except (KeyboardInterrupt, EOFError):
            print('')
            return False
        
        if user_input.lower() not in ['y', 'yes']:
            print('Skipping MongoDB user creation. You will need to create a monitoring user manually.')
            return False
        
        auth_header = {"Authorization": "Bearer {}".format(digitalocean_api_token)}
        
        # Create monitoring user payload
        user_payload = {
            "name": "pmm_monitor",
            "settings": {
                "mongo_user_settings": {
                    "role": "read"  # Read-only access for monitoring
                }
            }
        }
        
        try:
            print('Creating MongoDB monitoring user for "{}"...'.format(self.name))
            r = requests.post(
                'https://api.digitalocean.com/v2/databases/{}/users'.format(self.id),
                headers=auth_header,
                json=user_payload
            )
            r.raise_for_status()
            
            user_response = r.json()
            created_user = user_response['user']
            
            self.monitoring_username = created_user['name']
            self.monitoring_password = created_user['password']
            
            print('Successfully created MongoDB monitoring user "{}" for instance "{}"'.format(
                self.monitoring_username, self.name))
            return True
            
        except requests.exceptions.HTTPError as e:
            print('Error creating MongoDB user for "{}": HTTP {}'.format(self.name, r.status_code))
            if r.status_code == 409:
                print('User may already exist. You can use existing monitoring credentials.')
            else:
                try:
                    error_response = r.json()
                    print('Error details: {}'.format(error_response.get('message', 'Unknown error')))
                except:
                    print('Error details: {}'.format(r.text))
            return False
        except Exception as err:
            print('Error creating MongoDB user for "{}": {}'.format(self.name, err))
            return False
    
    def createMySQLUser(self, digitalocean_api_token):
        """
        Create a MySQL monitoring user via DigitalOcean API
        """
        try:
            user_input = input('Do you want to create a monitoring user for MySQL instance "{}"? [y/N]: '.format(self.name))
        except (KeyboardInterrupt, EOFError):
            print('')
            return False
        
        if user_input.lower() not in ['y', 'yes']:
            print('Skipping MySQL user creation. You will need to create a monitoring user manually.')
            return False
        
        auth_header = {"Authorization": "Bearer {}".format(digitalocean_api_token)}
        
        # Create monitoring user payload for MySQL
        user_payload = {
            "name": "pmm_monitor",
            "mysql_settings": {
                "auth_plugin": "mysql_native_password"
            }
        }
        
        try:
            print('Creating MySQL monitoring user for "{}"...'.format(self.name))
            r = requests.post(
                'https://api.digitalocean.com/v2/databases/{}/users'.format(self.id),
                headers=auth_header,
                json=user_payload
            )
            r.raise_for_status()
            
            user_response = r.json()
            created_user = user_response['user']
            
            self.monitoring_username = created_user['name']
            self.monitoring_password = created_user['password']
            
            print('Successfully created MySQL monitoring user "{}" for instance "{}"'.format(
                self.monitoring_username, self.name))
            print('Note: You may need to grant additional monitoring privileges to this user manually.')
            return True
            
        except requests.exceptions.HTTPError as e:
            print('Error creating MySQL user for "{}": HTTP {}'.format(self.name, r.status_code))
            if r.status_code == 409:
                print('User may already exist. You can use existing monitoring credentials.')
            else:
                try:
                    error_response = r.json()
                    print('Error details: {}'.format(error_response.get('message', 'Unknown error')))
                except:
                    print('Error details: {}'.format(r.text))
            return False
        except Exception as err:
            print('Error creating MySQL user for "{}": {}'.format(self.name, err))
            return False
    
    def createPostgreSQLUser(self, digitalocean_api_token):
        """
        Create a PostgreSQL monitoring user via DigitalOcean API
        """
        try:
            user_input = input('Do you want to create a monitoring user for PostgreSQL instance "{}"? [y/N]: '.format(self.name))
        except (KeyboardInterrupt, EOFError):
            print('')
            return False
        
        if user_input.lower() not in ['y', 'yes']:
            print('Skipping PostgreSQL user creation. You will need to create a monitoring user manually.')
            return False
        
        auth_header = {"Authorization": "Bearer {}".format(digitalocean_api_token)}
        
        # Create monitoring user payload for PostgreSQL
        user_payload = {
            "name": "pmm_monitor"
            # PostgreSQL users don't typically need special settings for basic monitoring
        }
        
        try:
            print('Creating PostgreSQL monitoring user for "{}"...'.format(self.name))
            r = requests.post(
                'https://api.digitalocean.com/v2/databases/{}/users'.format(self.id),
                headers=auth_header,
                json=user_payload
            )
            r.raise_for_status()
            
            user_response = r.json()
            created_user = user_response['user']
            
            self.monitoring_username = created_user['name']
            self.monitoring_password = created_user['password']
            
            print('Successfully created PostgreSQL monitoring user "{}" for instance "{}"'.format(
                self.monitoring_username, self.name))
            print('Note: You may need to grant additional monitoring privileges to this user manually.')
            return True
            
        except requests.exceptions.HTTPError as e:
            print('Error creating PostgreSQL user for "{}": HTTP {}'.format(self.name, r.status_code))
            if r.status_code == 409:
                print('User may already exist. You can use existing monitoring credentials.')
            else:
                try:
                    error_response = r.json()
                    print('Error details: {}'.format(error_response.get('message', 'Unknown error')))
                except:
                    print('Error details: {}'.format(r.text))
            return False
        except Exception as err:
            print('Error creating PostgreSQL user for "{}": {}'.format(self.name, err))
            return False
    
    def instanceMonitored(self, pmmServer):
        """
        Return boolean based on if an instance is monitored according to PMM management API
        """
        services = pmmServer.listServices()
        try:
            # Updated for PMM v3 management API response structure
            # The management API typically returns services in a different format
            # We need to check if our instance exists in the response
            dbServices = []
            
            # Check for different database types
            for db_type in ['mysql', 'postgresql', 'mongodb']:
                if db_type in services:
                    if isinstance(services[db_type], list):
                        dbServices.extend(services[db_type])
                    else:
                        dbServices.append(services[db_type])
            
            # Check if services are nested under a 'services' key
            if 'services' in services:
                dbServices.extend([s for s in services['services'] if s.get('service_type') in ['mysql', 'postgresql', 'mongodb']])
            
            # Fallback: search through all top-level values that might be lists
            if not dbServices:
                for key, value in services.items():
                    if isinstance(value, list):
                        dbServices.extend([s for s in value if isinstance(s, dict) and 
                                         any(db in str(s).lower() for db in ['mysql', 'postgresql', 'mongodb'])])
        except (KeyError, AttributeError, TypeError):
            dbServices = []
        
        if (self.address, self.port) in [ (i.get('address'), i.get('port')) for i in dbServices]:
            return True
        else:
            return False


def getAPIToken():
    token = os.environ.get('DIGITALOCEAN_API_TOKEN')
    if not token:
        token = input("Enter your DigitalOcean API token: ")
    return token

def getPMMAdminPassword():
    password = os.environ.get('PMM_ADMIN_PASSWORD')
    if not password:
        password = input("Enter the password for the PMM 'admin' user: ")
    return password

def getDBInstances(token):
    """
    Fetch all DBaaS instances from DigitalOcean API
    """
    auth_header = {"Authorization": "Bearer {}".format(token)}
    try:
        r = requests.get('https://api.digitalocean.com/v2/databases', headers=auth_header)
        r.raise_for_status()
    except requests.exceptions.HTTPError as e:
        if r.status_code == 401:
            print("Invalid DigitalOcean API token.")
        else:
            jsonResponse = r.json()
            print(jsonResponse['error'])
        sys.exit(1) 
    except Exception as err:
        print(err)  
        sys.exit(1) 
    return r.json()['databases']

def promptForDBSelection(instances):
    """
    Display list of eligible DBaaS instances and prompt user to enter selection. 
    Returns list if selected instances.
    """
    selectedInstances = []
    print('Eligible DBaaS instances found:') 
    for instance in instances:
        print('- {}'.format(instance.name), end = '')
        if instance.monitored:
            print(' (monitored)')
        else:
            print('')
    try:
        user_input = input('Enter comma-separated list of database names to monitor [all]: ')
    except (KeyboardInterrupt, EOFError):
        print('')
        sys.exit(0)
    if len(user_input) == 0:
        selectedInstanceNames = ['all']
    else:
        selectedInstanceNames = [ s.strip() for s in user_input.split(',') ]
    if 'all' in selectedInstanceNames:
        validInstances = instances
    else:
        validInstances = [ i for i in instances if i.name in selectedInstanceNames ]
    return validInstances

def getPublicIPv4():
    """
    Return the public IPv4 address of localhost
    """
    try:
        r = requests.get("http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address")
        r.raise_for_status()
    except requests.exceptions.HTTPError:
        jsonResponse = r.json()
        print(jsonResponse['error'])
    except Exception as err:
        print(err)
    return r.content

def printBanner():
    print(
"""
# This script adds DigitalOcean DBaaS instances to a Percona Monitoring and Management 
# (PMM) host running on the local server. Supports MySQL, PostgreSQL, and MongoDB DBaaS instances.
# 
# Before attempting to add DBaaS instances, make sure you have logged in to the Percona 
# Monitoring and Management GUI and set an admin password using this URL:
# 
# http://{}/
#
# Ensure that PMM is able to connect to your DBaaS instances by adding the PMM server
# to each database's Trusted Sources list here: https://cloud.digitalocean.com/databases.
# 
# This script will prompt for your PMM password and DigitalOcean API token which can 
# be generated at https://cloud.digitalocean.com/account/api/tokens (read-only permissions
# are sufficient). You can set these using environment variables:
# 
# export DIGITALOCEAN_API_TOKEN=<_your_API_token_>
# export PMM_ADMIN_PASSWORD=<_your_PMM_password_>
""".format(getPublicIPv4())
)


def main(arguments):

    printBanner()
    
    digitalocean_api_token = getAPIToken()
    pmm_admin_password = getPMMAdminPassword()
    pmm = PmmServer(serverAdminPassword=pmm_admin_password)
    
    instanceProperties = getDBInstances(digitalocean_api_token)
    eligibleInstances = [ DbaasInstance(i, pmm) for i in instanceProperties if i['engine'] in ['mysql', 'pg']]
    selectedInstances = promptForDBSelection(eligibleInstances)
    for instance in selectedInstances:
        if instance.monitored:
            print('Instance "{}" is already monitored by PMM.'.format(instance.name))
            continue
        # Add instance based on engine type
        if instance.engine == 'mysql':
            pmm.addMySQL(instance, digitalocean_api_token)
        elif instance.engine == 'pg':
            pmm.addPostgreSQL(instance, digitalocean_api_token)

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))