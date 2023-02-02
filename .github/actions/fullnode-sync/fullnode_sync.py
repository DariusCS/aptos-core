#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import time
import yaml

# This script runs the fullnode-sync from the root of aptos-core.

# Useful file constants
FULLNODE_CONFIG_NAME = "public_full_node.yaml" # Relative to the aptos-core repo
FULLNODE_CONFIG_TEMPLATE_PATH = "config/src/config/test_data/public_full_node.yaml" # Relative to the aptos-core repo
GENESIS_BLOB_PATH = "https://raw.githubusercontent.com/aptos-labs/aptos-networks/main/{network}/genesis.blob" # Location inside the aptos-networks repo
LOCAL_REST_ENDPOINT = "http://127.0.0.1:8080/v1" # The rest endpoint running on the local host
LEDGER_VERSION_API_STRING = "ledger_version" # The string to fetch the ledger version from the REST API
MAX_TIME_BETWEEN_VERSION_INCREASES_SECS = 1800 # The number of seconds after which to fail if the node isn't syncing
REMOTE_REST_ENDPOINTS = "https://fullnode.{network}.aptoslabs.com/v1" # The remote rest endpoint
SYNCING_DELTA_VERSIONS = 20000 # The number of versions to sync beyond the highest known at the job start
WAYPOINT_FILE_PATH = "https://raw.githubusercontent.com/aptos-labs/aptos-networks/main/{network}/waypoint.txt" # Location inside the aptos-networks repo

def print_error_and_exit(error):
  """Prints the given error and exits the process"""
  print(error)
  sys.exit(error)


def ping_rest_api_index_page(rest_endpoint, exit_if_none):
  """Pings and returns the index page from a REST API endpoint"""
  # Ping the REST API index page
  process = subprocess.Popen(["curl", "-s", rest_endpoint], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  api_index_response, errors = process.communicate()
  if exit_if_none and api_index_response is None:
      print_error_and_exit("Exiting! Unable to get the REST API index page from the endpoint at: {rest_endpoint}. Response is empty.".format(rest_endpoint=rest_endpoint))
  if errors is not None and errors != b'':
    print("Found output on stderr for ping_rest_api_index_page: {errors}".format(errors=errors))

  # Return the index page response
  return api_index_response


def get_synced_version_from_index_response(api_index_response, exit_if_none):
  """Gets and returns the synced version from a REST index page response"""
  # Parse the synced ledger version
  api_index_response = json.loads(api_index_response)
  synced_version = api_index_response[LEDGER_VERSION_API_STRING]
  if exit_if_none and synced_version is None:
    print_error_and_exit("Exiting! Unable to get the synced version from the given API index response: {api_index_response}! Synced version is empty".format(api_index_response=api_index_response))

  # Return the synced version
  return int(synced_version)


def check_fullnode_is_still_running(fullnode_process_handle):
  """Verifies the fullnode is still running and exits if not"""
  return_code = fullnode_process_handle.poll()
  if return_code is not None:
    print_error_and_exit("Exiting! The fullnode process terminated prematurely with return code: {return_code}!".format(return_code=return_code))


def monitor_fullnode_syncing(fullnode_process_handle, bootstrapping_mode, node_log_file_path, public_version, target_version):
  """Monitors the ability of the fullnode to sync"""
  print("Waiting for the node to synchronize!")
  last_synced_version = 0 # The most recent synced version
  last_sync_update_time = time.time() # The latest timestamp of when we were able to sync to a higher version
  start_sync_time = time.time() # The time at which we started syncing the node
  synced_to_public_version = False # If we've synced to the public version

  # Loop while we wait for the fullnode to sync
  while True:
    # Ensure the fullnode is still running
    check_fullnode_is_still_running(fullnode_process_handle)

    # Fetch the latest synced version
    api_index_response = ping_rest_api_index_page(LOCAL_REST_ENDPOINT, True)
    synced_version = get_synced_version_from_index_response(api_index_response, True)

    # Check if we've synced to the public version
    if not synced_to_public_version:
      if synced_version >= public_version:
        time_to_sync_to_public = time.time() - start_sync_time
        syncing_throughput = public_version / time_to_sync_to_public
        print("Synced to version: {public_version}, in: {time_to_sync_to_public} seconds.".format(public_version=public_version, time_to_sync_to_public=time_to_sync_to_public))
        print("Syncing throughput: {syncing_throughput} (versions per seconds).".format(syncing_throughput=syncing_throughput))
        synced_to_public_version = True

    # Check if we've synced to the target version
    if synced_version >= target_version:
      print("Successfully synced to the target! Target version: {target_version}, Synced version: {synced_version}".format(target_version=target_version, synced_version=synced_version))
      sys.exit(0)

    # Ensure we're actually making syncing progress (depending on the sync mode)
    if synced_version <= last_synced_version:
      time_since_last_version_increase = time.time() - last_sync_update_time
      if time_since_last_version_increase > MAX_TIME_BETWEEN_VERSION_INCREASES_SECS:
        if bootstrapping_mode == "DownloadLatestStates":
          if synced_version != 0: # Fast sync will take long to initialize the synced_version
            print_error_and_exit("Exiting! The fullnode is not making any syncing progress, despite using fast sync!")
        else:
          print_error_and_exit("Exiting! The fullnode is not making any syncing progress!")
    else:
      last_synced_version = synced_version
      last_sync_update_time = time.time()

    # We're still syncing. Display the last 10 lines of the node log.
    print("Still syncing. Target version: {target_version}, Synced version: {synced_version}".format(target_version=target_version, synced_version=synced_version))
    process = subprocess.Popen(["tail", "-10", node_log_file_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    recent_log_lines, errors = process.communicate()
    print(recent_log_lines)
    print(errors)

    # Sleep for a few seconds while the fullnode synchronizes
    time.sleep(10)


def wait_for_fullnode_to_start(fullnode_process_handle):
  """Monitors the ability of the fullnode to start up"""
  api_index_response = ping_rest_api_index_page(LOCAL_REST_ENDPOINT, False)
  while api_index_response is None or api_index_response == b'':
    print("Waiting for the fullnode to start.")

    # Check if the fullnode is still running
    check_fullnode_is_still_running(fullnode_process_handle)

    # Sleep for a bit while the fullnode comes up
    time.sleep(5)

    # Ping the endpoint again
    api_index_response = ping_rest_api_index_page(LOCAL_REST_ENDPOINT, False)


def get_public_and_target_version(network):
  """Calculates the syncing target version of the fullnode"""
  # Fetch the latest version from the public fullnode endpoint
  public_fullnode_endpoint = REMOTE_REST_ENDPOINTS.format(network=network)
  api_index_response = ping_rest_api_index_page(public_fullnode_endpoint, True)
  public_version = get_synced_version_from_index_response(api_index_response, True)
  print("Synced version found from the public endpoint: {public_version}".format(public_version=public_version))

  # Calculate the target syncing version
  target_version = public_version + SYNCING_DELTA_VERSIONS
  print("Setting target version to: {target_version}".format(target_version=target_version))

  # Return both versions
  return (public_version, target_version)


def spawn_fullnode(branch, network, bootstrapping_mode, continuous_syncing_mode, node_log_file_path):
  """Spawns the fullnode"""
  # Display the fullnode setup
  print("Starting the fullnode using branch: {branch}, for network: {network}, " \
        "with bootstrapping mode: {bootstrapping_mode} and continuous syncing " \
        "mode: {continuous_syncing_mode}!".format(branch=branch, network=network,
                                                  bootstrapping_mode=bootstrapping_mode,
                                                  continuous_syncing_mode=continuous_syncing_mode))

  # Display the fullnode config
  with open(FULLNODE_CONFIG_NAME) as file:
    fullnode_config = yaml.safe_load(file)
  if fullnode_config is None:
    print_error_and_exit("Exiting! Failed to load the fullnode config template at {template_path}!".format(template_path=FULLNODE_CONFIG_NAME))
  print("Starting the fullnode using the config: {fullnode_config}".format(fullnode_config=fullnode_config))

  # Start the fullnode
  node_log_file = open(node_log_file_path, "w")
  process_handle = subprocess.Popen(["cargo", "run", "-p", "aptos-node", "--release", "--", "-f", FULLNODE_CONFIG_NAME], stdout=node_log_file, stderr=node_log_file)

  # Return the process handle
  return process_handle


def setup_fullnode_config(bootstrapping_mode, continuous_syncing_mode, data_dir_file_path):
  """Initializes and configures the fullnode config file"""
  # Copy the node config template to the working directory
  if not os.path.exists(FULLNODE_CONFIG_TEMPLATE_PATH):
    print_error_and_exit("Exiting! The fullnode config template wasn't found: {template_path}!".format(template_path=FULLNODE_CONFIG_TEMPLATE_PATH))
  subprocess.run(["cp", FULLNODE_CONFIG_TEMPLATE_PATH, FULLNODE_CONFIG_NAME])

  # Update the data_dir in the node config template
  with open(FULLNODE_CONFIG_NAME) as file:
    fullnode_config = yaml.safe_load(file)
  if fullnode_config is None:
    print_error_and_exit("Exiting! Failed to load the fullnode config template at {template_path}!".format(template_path=FULLNODE_CONFIG_TEMPLATE_PATH))
  fullnode_config['base']['data_dir'] = data_dir_file_path

  # Add the state sync configurations to the config template
  state_sync_driver_config = {"bootstrapping_mode": bootstrapping_mode, "continuous_syncing_mode": continuous_syncing_mode}
  data_streaming_service_config = {"max_concurrent_requests": 10}
  fullnode_config['state_sync'] = {"state_sync_driver": state_sync_driver_config, "data_streaming_service":data_streaming_service_config}

  # Write the config file back to disk
  with open(FULLNODE_CONFIG_NAME, "w") as file:
    yaml.dump(fullnode_config, file)


def get_genesis_and_waypoint(network):
  """Clones the genesis blob and waypoint to the current working directory"""
  genesis_blob_path = GENESIS_BLOB_PATH.format(network=network)
  waypoint_file_path = WAYPOINT_FILE_PATH.format(network=network)
  subprocess.run(["curl", "-s", "-O", genesis_blob_path])
  subprocess.run(["curl", "-s", "-O", waypoint_file_path])


def checkout_git_branch(branch):
  """Checkout the specified git branch. This assumes the working directory is aptos-core"""
  subprocess.run(["git", "fetch"])
  subprocess.run(["git", "checkout", branch])
  subprocess.run(["git", "log", "-1"]) # Display the git commit we're running on


def main():
  # Ensure we have all required environment variables
  REQUIRED_ENVS = [
    "BRANCH",
    "NETWORK",
    "BOOTSTRAPPING_MODE",
    "CONTINUOUS_SYNCING_MODE",
    "DATA_DIR_FILE_PATH",
    "NODE_LOG_FILE_PATH",
  ]
  if not all(env in os.environ for env in REQUIRED_ENVS):
    raise Exception("Missing required ENV variables!")

  # Fetch each of the environment variables
  BRANCH = os.environ["BRANCH"]
  NETWORK = os.environ["NETWORK"]
  BOOTSTRAPPING_MODE = os.environ["BOOTSTRAPPING_MODE"]
  CONTINUOUS_SYNCING_MODE = os.environ["CONTINUOUS_SYNCING_MODE"]
  DATA_DIR_FILE_PATH = os.environ["DATA_DIR_FILE_PATH"]
  NODE_LOG_FILE_PATH = os.environ["NODE_LOG_FILE_PATH"]

  # Check out the correct git branch
  checkout_git_branch(BRANCH)

  # Get the genesis blob and waypoint
  get_genesis_and_waypoint(NETWORK)

  # Setup the fullnode config
  setup_fullnode_config(BOOTSTRAPPING_MODE, CONTINUOUS_SYNCING_MODE, DATA_DIR_FILE_PATH)

  # Get the public synced version and calculate the fullnode syncing target version
  (public_version, target_version) = get_public_and_target_version(NETWORK)

  # Spawn the fullnode
  fullnode_process_handle = spawn_fullnode(BRANCH, NETWORK, BOOTSTRAPPING_MODE, CONTINUOUS_SYNCING_MODE, NODE_LOG_FILE_PATH)

  # Wait for the fullnode to come up
  wait_for_fullnode_to_start(fullnode_process_handle)

  # Monitor the ability for the fullnode to sync
  monitor_fullnode_syncing(fullnode_process_handle, BOOTSTRAPPING_MODE, NODE_LOG_FILE_PATH, public_version, target_version)


if __name__ == "__main__":
  main()
